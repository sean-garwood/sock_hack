# Get WiFi status

curl <http://192.168.0.1/wifi_status.json>

# Get available WiFi networks

curl <http://192.168.0.1/wifi_scan_results.json>

# Trigger a WiFi scan

curl -X POST <http://192.168.0.1/wifi_scan.json>

# Get saved WiFi profiles

curl <http://192.168.0.1/wifi_profiles.json>

# Connect to a WiFi network (with SSID and password)

curl -X POST "<http://192.168.0.1/wifi_connect.json?ssid=YourNetworkName&key=YourPassword>"

# Delete a WiFi profile

curl -X DELETE "<http://192.168.0.1/wifi_profile.json?ssid=NetworkNameToDelete>"
