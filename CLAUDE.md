# Owlet DreamSock 3 Reverse Engineering Session

## Current Investigation Status

**Device**: Owlet DreamSock 3 (Baby monitoring IoT device)

- Base Station FCC ID: 2AIEP-0BL3A
- Sensor FCC ID: 2AIEP-0SS3A
- Base Station IP: 192.168.0.1 (acts as AP)
- MAC: 26:cd:8d:e2:99:3a
- DSN: AC000W025363194
- Cloud Service: Ayla Networks (SS3-Sleep-1a2039d9-device.aylanetworks.com)

## Active Todo List

1. ✅ **COMPLETED**: Analyze existing packet captures for interesting traffic
   - Findings: Mostly UPnP/SSDP discovery traffic (M-SEARCH)
   - No DNS queries to cloud in idle captures
   - Device does local network scanning looking for other devices

2. ⏳ **IN PROGRESS**: Enumerate and test all API endpoints from wifi.js
   - **PAUSED**: Device needs to be powered on to test
   - Identified endpoints from app/wifi.js:
     - `wifi_status.json` (GET)
     - `wifi_scan_results.json` (GET)
     - `wifi_scan.json` (POST)
     - `wifi_connect.json` (POST)
     - `wifi_profiles.json` (GET)
     - `wifi_profile.json` (DELETE)

3. **PENDING**: Check web UI for security vulnerabilities (XSS, CSRF, injection)
   - Areas to test (from wifi.js analysis):
     - Input validation on password/SSID fields (lines 184-187)
     - CSRF tokens (doesn't appear to have any)
     - XSS via escapeHtml function (lines 18-22)
     - Parameter injection in URL building (lines 55, 162, 183, 338)

4. **PENDING**: Investigate Ayla Networks cloud integration
   - API docs: <https://docs.aylanetworks.com/>
   - Test endpoint: `SS3-Sleep-1a2039d9-device.aylanetworks.com`

5. **PENDING**: Port scan the device to find all running services
   - Commands ready:

     ```bash
     nmap -sV -sC -p- 192.168.0.1 -oN owlet_scan.txt
     nmap -p 80,443,8080,8443 -sV 192.168.0.1
     ```

6. **PENDING**: Fuzz API endpoints for hidden functionality
   - Try API endpoints with different parameters
   - Look for hidden parameters, debug endpoints
   - Test authentication bypass

7. **PENDING**: Document all security findings

## Key Findings So Far

### Packet Capture Analysis

- **ap_idle.pcapng**: Device doing UPnP/SSDP M-SEARCH broadcasts (239.255.255.250:1900)
- **tcpdump.240426.pcap**: Shows web UI interaction (192.168.0.101 ↔ 192.168.0.1)
- No outbound internet connections captured in idle state
- Device performs local network discovery

### Web Application (app/wifi.js)

- Simple WiFi configuration interface at 192.168.0.1
- No apparent CSRF protection
- Uses basic HTML escaping (escapeHtml function)
- REST-like JSON API endpoints
- Connection flow: User selects network → enters password → device connects → phones home to Ayla Networks

### Device Architecture

1. Sock (sensor) → Bluetooth → Base Station
2. Base Station → Creates AP → Serves web UI for WiFi config
3. Base Station (once configured) → Home network → Ayla Networks cloud
4. Cloud relay for parent app communication

## Next Steps When Resuming

1. **Power on the Owlet device**
2. **Connect to its AP** (check available WiFi networks)
3. **Run port scan**: `nmap -sV -sC 192.168.0.1`
4. **Test API endpoints**:

   ```bash
   curl http://192.168.0.1/wifi_status.json
   curl http://192.168.0.1/wifi_scan_results.json
   curl -X POST http://192.168.0.1/wifi_scan.json
   curl http://192.168.0.1/wifi_profiles.json
   ```

5. **Look for security issues**:
   - XSS in SSID field
   - CSRF on connect/disconnect actions
   - Authentication bypass
   - Hidden API endpoints
6. **Test Ayla Networks integration**:

   ```bash
   curl -v http://SS3-Sleep-1a2039d9-device.aylanetworks.com
   nslookup SS3-Sleep-1a2039d9-device.aylanetworks.com
   ```

## Available Tools Confirmed

- tshark / wireshark
- tcpdump
- nmap
- curl

feel free to add more if desired. Just aks first.

## Files to Reference

- `/home/ssg/repos/sock_hack/app/wifi.js` - Web interface controller
- `/home/ssg/repos/sock_hack/app/index.html` - Web UI
- `/home/ssg/repos/sock_hack/recon/app/window.wifi_status.json` - Sample API response
- `/home/ssg/repos/sock_hack/recon/pcaps/` - Packet captures

## Resume Command

When user types `/resume`, continue with:

1. Check if device is online (ping 192.168.0.1)
2. If online, run nmap scan
3. Test API endpoints
4. Look for security vulnerabilities
