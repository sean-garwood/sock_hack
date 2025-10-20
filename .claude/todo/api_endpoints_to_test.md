# API endpoints to test

## Trigger a WiFi scan

curl -X POST <http://192.168.0.1/wifi_scan.json>

## Connect to a WiFi network (with SSID and password)

curl -X POST
"<http://192.168.0.1/wifi_connect.json?ssid=YourNetworkName&key=YourPassword>"

### invalid data

see [wifi_connect.json](../../recon/api/wifi_connect.json)

### valid data

todo

## Delete a WiFi profile

curl -X DELETE "<http://192.168.0.1/wifi_profile.json?ssid=NetworkNameToDelete>"
