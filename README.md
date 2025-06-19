# osm-reverse-geocode
I wanted a quick way to reverse geocode a csv with lat/longs and provide a full address as well as google maps links and street view links for verification.

This ruby implementation uses open street map api to accomplish this.

## Usage

- Install Ruby 2.7+
- Clone the repo
- cd osm-reverse-geocode
- ```ruby osm_reverse_geocode_csv.rb example-lat-long.csv```

This will create:

- input_file_geocded.csv
- input_file_geocoded_review.html

## Example output

```ruby
ruby osm_reverse_geocode_csv.rb Central-Florida.csv
Processed: 28.5139665, -81.4984466 -> Shell, Florida's Turnpike, Orange County, Florida, 32835, United States
Processed: 28.2347284, -81.6507035 -> Chevron, Hotel Drive, Four Corners, Polk County, Florida, 33896, United States
Processed: 28.5149827, -81.3915636 -> Chevron, 901, Lee Avenue, Orlando, Orange County, Florida, 32805, United States
Processed: 28.4695197, -81.3109497 -> Wawa, 6500, Lee Vista Boulevard, Airport North, Orlando, Orange County, Florida, 32822, United States
Processed: 27.9616238, -81.6238508 -> US 27, Lake Wales, Polk County, Florida, 33977, United States
Processed: 28.551474, -81.7718163 -> 997, 10th Street, Clermont, Lake County, Florida, 34711, United States
Processed: 29.158282, -81.067445 -> RaceTrac, Beville Road, Daytona Beach, Volusia County, Florida, 32119, United States
Processed: 28.6102276, -81.364863 -> 1240, Orlando Avenue, Winter Park, Orange County, Florida, 32789, United States
Processed: 28.5678487, -81.2571116 -> Sunoco, Tower Street, Union Park, Orange County, Florida, 32817, United States
Processed: 28.0334407, -81.7325619 -> Sunoco, Avenue L Northwest, Winter Haven, Polk County, Florida, 33881, United States
Processed: 28.5474213, -81.7405321 -> 998, East Highway 50, Clermont, Lake County, Florida, 32711, United States
Processed: 28.450092, -81.383518 -> RaceTrac, Sand Lake Road, Pine Castle, Sky Lake, Orange County, Florida, 32089, United States
Processed: 28.38831, -81.245169 -> RaceTrac, Tagore Place, Orlando, Orange County, Florida, 32832, United States
```

The script generates a new CSV with the original data, plus these additional columns:

- address
- google_maps_link
- street_view_link
- review_status
- notes
