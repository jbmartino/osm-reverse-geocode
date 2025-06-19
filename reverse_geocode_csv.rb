require 'csv'
require 'net/http'
require 'json'
require 'uri'

class OSMReverseGeocoder
  BASE_URL = 'https://nominatim.openstreetmap.org/reverse'
  
  def initialize(input_file, output_file = nil)
    @input_file = input_file
    @output_file = output_file || input_file.gsub('.csv', '_geocoded.csv')
    @delay = 1 # rate limit (1 second)
  end
  
  def process_csv
    unless File.exist?(@input_file)
      puts "Error: Input file '#{@input_file}' not found."
      return
    end
    
    results = []
    
    CSV.foreach(@input_file, headers: true) do |row|
      lat = row['lat'] || row['latitude'] || row['Lat'] || row['Latitude'] || row['Y']
      lon = row['lon'] || row['longitude'] || row['Long'] || row['Longitude'] || row['lng'] || row['X']
      
      if lat.nil? || lon.nil?
        puts "Warning: Missing coordinates in row #{row.to_h}"
        results << row.to_h.merge(
          'address' => 'Missing coordinates',
          'google_maps_link' => '',
          'street_view_link' => '',
          'review_status' => 'ERROR',
          'notes' => 'Missing lat/long coordinates'
        )
        next
      end
      
      begin
        lat_f, lon_f = lat.to_f, lon.to_f
        address = reverse_geocode(lat_f, lon_f)
        
        google_maps_link = "https://www.google.com/maps?q=#{lat_f},#{lon_f}"
        street_view_link = "https://www.google.com/maps?q=#{lat_f},#{lon_f}&layer=c&cbll=#{lat_f},#{lon_f}"
        
        results << row.to_h.merge(
          'address' => address,
          'google_maps_link' => google_maps_link,
          'street_view_link' => street_view_link,
          'review_status' => 'PENDING',
          'notes' => ''
        )
        puts "Processed: #{lat}, #{lon} -> #{address}"
      rescue => e
        puts "Error processing #{lat}, #{lon}: #{e.message}"
        results << row.to_h.merge(
          'address' => "Error: #{e.message}",
          'google_maps_link' => '',
          'street_view_link' => '',
          'review_status' => 'ERROR',
          'notes' => e.message
        )
      end
      
      # rate limits
      sleep(@delay)
    end
    
    write_results(results)
    generate_review_html(results) if results.any?
    puts "Geocoding complete! Results saved to: #{@output_file}"
    puts "Review HTML generated: #{@output_file.gsub('.csv', '_review.html')}"
  end
  
  private
  
  def reverse_geocode(lat, lon)
    unless valid_coordinates?(lat, lon)
      raise "Invalid coordinates: #{lat}, #{lon}"
    end
    
    params = {
      'format' => 'json',
      'lat' => lat.to_s,
      'lon' => lon.to_s,
      'zoom' => '18',
      'addressdetails' => '1'
    }
    
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Ruby Reverse Geocoder Script'
    
    response = http.request(request)
    
    case response.code
    when '200'
      data = JSON.parse(response.body)
      return parse_address(data)
    when '429'
      raise "Rate limit exceeded. Please try again later."
    else
      raise "HTTP Error: #{response.code} - #{response.message}"
    end
  end
  
  def parse_address(data)
    if data['error']
      return "No address found"
    end
    
    # Try to get the display_name first (most complete address)
    if data['display_name']
      return data['display_name']
    end
    
    # If no display_name, try to construct from address components
    if data['address']
      addr = data['address']
      components = []
      
      components << "#{addr['house_number']} #{addr['road']}".strip if addr['house_number'] || addr['road']
      
      city = addr['city'] || addr['town'] || addr['village'] || addr['hamlet']
      components << city if city
      
      state = addr['state'] || addr['province']
      components << state if state
      
      components << addr['postcode'] if addr['postcode']
      
      components << addr['country'] if addr['country']
      
      return components.join(', ') unless components.empty?
    end
    
    return "Address not found"
  end
  
  def valid_coordinates?(lat, lon)
    lat.between?(-90, 90) && lon.between?(-180, 180)
  end
  
  def write_results(results)
    return if results.empty?
    
    CSV.open(@output_file, 'w', write_headers: true, headers: results.first.keys) do |csv|
      results.each { |row| csv << row }
    end
  end
  
  def generate_review_html(results)
    html_file = @output_file.gsub('.csv', '_review.html')
    
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Address Review</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
          .pending { background-color: #fff3cd; }
          .error { background-color: #f8d7da; }
          .approved { background-color: #d4edda; }
          .rejected { background-color: #f5c6cb; }
          .links a { margin-right: 10px; }
          .coordinates { font-family: monospace; }
        </style>
      </head>
      <body>
        <h1>Address Review - #{results.length} locations</h1>
        <p>Click the links to verify each location, then update the review status.</p>
        
        <table>
          <thead>
            <tr>
              <th>Coordinates</th>
              <th>Address</th>
              <th>Links</th>
              <th>Status</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
    HTML
    
    results.each do |row|
      lat = row['lat'] || row['latitude'] || row['Lat'] || row['Latitude']
      lon = row['lon'] || row['longitude'] || row['Long'] || row['Longitude'] || row['lng']
      
      status_class = case row['review_status']
                    when 'PENDING' then 'pending'
                    when 'ERROR' then 'error'
                    when 'APPROVED' then 'approved'
                    when 'REJECTED' then 'rejected'
                    else 'pending'
                    end
      
      html_content += <<~ROW
            <tr class="#{status_class}">
              <td class="coordinates">#{lat}, #{lon}</td>
              <td>#{row['address']}</td>
              <td class="links">
                #{row['google_maps_link'].empty? ? '' : "<a href='#{row['google_maps_link']}' target='_blank'>Maps</a>"}
                #{row['street_view_link'].empty? ? '' : "<a href='#{row['street_view_link']}' target='_blank'>Street View</a>"}
              </td>
              <td>#{row['review_status']}</td>
              <td>#{row['notes']}</td>
            </tr>
      ROW
    end
    
    html_content += <<~HTML
          </tbody>
        </table>
        
        <h2>Instructions:</h2>
        <ol>
          <li>Click "Maps" to see the location on Google Maps</li>
          <li>Click "Street View" to see the actual location</li>
          <li>Verify the location</li>
          <li>Update your CSV with status: APPROVED, REJECTED, or NEEDS_UPDATE</li>
        </ol>
      </body>
      </html>
    HTML
    
    File.write(html_file, html_content)
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby #{$0} input_file.csv [output_file.csv]"
    puts ""
    puts "The CSV file should contain latitude and longitude columns."
    puts "Supported column names:"
    puts "  - lat, latitude, Lat, Latitude, Y"
    puts "  - lon, longitude, Long, Longitude, lng, X"
    puts ""
    puts "Example:"
    puts "  ruby #{$0} coordinates.csv"
    puts "  ruby #{$0} coordinates.csv geocoded_results.csv"
    exit 1
  end
  
  input_file = ARGV[0]
  output_file = ARGV[1]
  
  geocoder = OSMReverseGeocoder.new(input_file, output_file)
  geocoder.process_csv
end