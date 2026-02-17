#!/bin/bash
set -euo pipefail

# Generate JSON stubs from Pkl files
# Output structure mirrors ios-sdk/MindboxTests/ConfigParsing/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/output/stubs}"
STUBS="$SCRIPT_DIR/configs/stubs"
ERRORS=0
TOTAL=0

echo "Generating JSON stubs to: $OUTPUT_DIR"

# Clean previous output to avoid stale files
if [ -d "$OUTPUT_DIR" ]; then
  echo "Cleaning previous output..."
  rm -rf "$OUTPUT_DIR"
fi

generate() {
  local pkl_file="$1"
  local out_dir="$2"
  local name
  name=$(basename "$pkl_file" .pkl)
  [[ "$name" == _* ]] && return
  mkdir -p "$out_dir"
  if pkl eval "$pkl_file" -f json -o "$out_dir/${name}.json" 2>/dev/null; then
    echo "  OK: ${name}.json"
    TOTAL=$((TOTAL + 1))
  else
    echo "  FAIL: $pkl_file"
    ERRORS=$((ERRORS + 1))
  fi
}

# Generate all .pkl files in a source directory to an output directory
generate_dir() {
  local src_dir="$1"
  local out_dir="$2"
  local label="$3"
  echo ""
  echo "=== $label ==="
  for pkl in "$src_dir"/*.pkl; do
    [ -f "$pkl" ] || continue
    generate "$pkl" "$out_dir"
  done
}

# --- Output directory mapping (mirrors ios-sdk test structure) ---
# Source dir                          → Output dir
# configs/stubs/Monitoring/           → Monitoring/MonitoringJsonStubs/
# configs/stubs/ABTests/              → ABTests/ABTestsJsonStubs/
# configs/stubs/Config/               → Config/ConfigJsonStub/
# configs/stubs/InApp/                → InApp/InAppJsonStubs/
# configs/stubs/Settings/SettingsConfig.pkl → Settings/SettingsJsonStubs/
# configs/stubs/Settings/*.pkl (rest) → Settings/
# configs/stubs/Settings/<subdir>/    → Settings/SettingsJsonStubs/<subdir>/

generate_dir "$STUBS/Monitoring" "$OUTPUT_DIR/Monitoring/MonitoringJsonStubs" "Monitoring"
generate_dir "$STUBS/ABTests"    "$OUTPUT_DIR/ABTests/ABTestsJsonStubs"      "ABTests"
generate_dir "$STUBS/Config"     "$OUTPUT_DIR/Config/ConfigJsonStub"         "Config"
generate_dir "$STUBS/InApp"      "$OUTPUT_DIR/InApp/InAppJsonStubs"          "InApp"

# --- Settings: root-level files ---
echo ""
echo "=== Settings (root) ==="
for pkl in "$STUBS"/Settings/*.pkl; do
  [ -f "$pkl" ] || continue
  name=$(basename "$pkl" .pkl)
  [[ "$name" == _* ]] && continue
  if [ "$name" = "SettingsConfig" ]; then
    generate "$pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs"
  else
    generate "$pkl" "$OUTPUT_DIR/Settings"
  fi
done

# --- Settings: auto-discover subdirectories ---
for subdir in "$STUBS"/Settings/*/; do
  [ -d "$subdir" ] || continue
  subdir_name=$(basename "$subdir")
  generate_dir "$subdir" "$OUTPUT_DIR/Settings/SettingsJsonStubs/$subdir_name" "Settings > $subdir_name"
done

# --- Summary ---
echo ""
echo "Done! Generated $TOTAL JSON files."
if [ $ERRORS -gt 0 ]; then
  echo "WARNING: $ERRORS file(s) failed to generate."
  exit 1
else
  echo "All files generated successfully."
fi
