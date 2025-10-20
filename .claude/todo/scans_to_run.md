
# scans to run

## nmap

# Full port scan with scripts

  nmap -sV -sC -p- 192.168.0.1 -oN owlet_scan.txt

# Common web ports (if not covered by above)

  nmap -p 80,443,8080,8443 192.168.0.1

  That's it. Save output to recon/owlet_scan.txt when done.

> then, do the same for the other scans that are not nmap

● API endpoint tests:

# Basic endpoints

  curl <http://192.168.0.1/wifi_status.json>
  curl <http://192.168.0.1/wifi_scan_results.json>
  curl <http://192.168.0.1/wifi_profiles.json>

# Trigger scan

  curl -X POST <http://192.168.0.1/wifi_scan.json>

  Ayla Networks:

  nslookup SS3-Sleep-1a2039d9-device.aylanetworks.com
  curl -v <http://SS3-Sleep-1a2039d9-device.aylanetworks.com>
  curl -v <https://SS3-Sleep-1a2039d9-device.aylanetworks.com>

  Packet capture (if you want to see what it does):

  tcpdump -i wlan0 -w owlet_active.pcap
