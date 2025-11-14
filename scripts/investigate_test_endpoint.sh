#!/bin/bash
# Script to investigate the /test endpoint that returned HTTP 200

TARGET="192.168.0.1"
OUTPUT_DIR="recon/api"

echo "=== Investigating /test endpoint on $TARGET ==="
echo

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# 1. Get the basic /test response
echo "[*] Testing GET /test"
curl -v http://$TARGET/test 2>&1 | tee "$OUTPUT_DIR/test_endpoint_GET.txt"
echo
echo "---"
echo

# 2. Try with trailing slash
echo "[*] Testing GET /test/"
curl -v http://$TARGET/test/ 2>&1 | tee "$OUTPUT_DIR/test_endpoint_slash.txt"
echo
echo "---"
echo

# 3. Try different extensions
echo "[*] Testing /test with extensions"
for ext in .html .json .xml .txt .php .cgi; do
    echo "  - /test$ext"
    curl -v http://$TARGET/test$ext 2>&1 | tee "$OUTPUT_DIR/test_endpoint${ext}.txt"
    echo
done
echo "---"
echo

# 4. Try different HTTP methods
echo "[*] Testing different HTTP methods"
for method in POST PUT DELETE OPTIONS HEAD; do
    echo "  - $method /test"
    curl -X $method -v http://$TARGET/test 2>&1 | tee "$OUTPUT_DIR/test_endpoint_${method}.txt"
    echo
done
echo "---"
echo

# 5. Try with common parameters
echo "[*] Testing /test with parameters"
declare -a params=(
    "?cmd=help"
    "?debug=1"
    "?action=status"
    "?command=help"
    "?test=1"
    "?mode=debug"
    "?info=all"
    "?show=all"
)

for param in "${params[@]}"; do
    echo "  - /test$param"
    curl -v "http://$TARGET/test$param" 2>&1 | tee "$OUTPUT_DIR/test_endpoint_param_${param//[^a-zA-Z0-9]/_}.txt"
    echo
done
echo "---"
echo

# 6. Try sub-paths
echo "[*] Testing /test sub-paths"
declare -a paths=(
    "/test/status"
    "/test/debug"
    "/test/cmd"
    "/test/exec"
    "/test/run"
    "/test/help"
    "/test/info"
)

for path in "${paths[@]}"; do
    echo "  - $path"
    curl -v "http://$TARGET$path" 2>&1 | tee "$OUTPUT_DIR/test_endpoint_subpath_${path//\//_}.txt"
    echo
done
echo "---"
echo

echo "[+] Investigation complete! Check $OUTPUT_DIR/ for results"
echo
echo "Summary of HTTP status codes:"
grep "< HTTP" "$OUTPUT_DIR"/test_endpoint*.txt | sort | uniq -c
