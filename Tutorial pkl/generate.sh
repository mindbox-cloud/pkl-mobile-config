#!/bin/bash
set -euo pipefail

# Generate JSON stubs from Pkl files
# Output structure mirrors ios-sdk/MindboxTests/ConfigParsing/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/output/stubs}"

echo "Generating JSON stubs to: $OUTPUT_DIR"

# Create output directories
mkdir -p "$OUTPUT_DIR/Monitoring/MonitoringJsonStubs"
mkdir -p "$OUTPUT_DIR/ABTests/ABTestsJsonStubs"
mkdir -p "$OUTPUT_DIR/Config/ConfigJsonStub"
mkdir -p "$OUTPUT_DIR/Settings"
mkdir -p "$OUTPUT_DIR/Settings/SettingsJsonStubs"
mkdir -p "$OUTPUT_DIR/Settings/SettingsJsonStubs/TtlErrors"
mkdir -p "$OUTPUT_DIR/Settings/SettingsJsonStubs/SlidingExpirationsError"
mkdir -p "$OUTPUT_DIR/Settings/SettingsJsonStubs/OperationsErrors"
mkdir -p "$OUTPUT_DIR/Settings/SettingsJsonStubs/InappError"

STUBS="$SCRIPT_DIR/configs/stubs"
ERRORS=0

generate() {
  local pkl_file="$1"
  local json_file="$2"
  if pkl eval "$pkl_file" -f json -o "$json_file" 2>/dev/null; then
    echo "  OK: $(basename "$json_file")"
  else
    echo "  FAIL: $pkl_file"
    ERRORS=$((ERRORS + 1))
  fi
}

# --- Monitoring (8 files) ---
echo ""
echo "=== Monitoring ==="
for pkl in "$STUBS"/Monitoring/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/Monitoring/MonitoringJsonStubs/${name}.json"
done

# --- ABTests (7 files) ---
echo ""
echo "=== ABTests ==="
for pkl in "$STUBS"/ABTests/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/ABTests/ABTestsJsonStubs/${name}.json"
done

# --- Config (12 files, skip _SharedConfigData.pkl) ---
echo ""
echo "=== Config ==="
for pkl in "$STUBS"/Config/*.pkl; do
  name=$(basename "$pkl" .pkl)
  [[ "$name" == _* ]] && continue
  generate "$pkl" "$OUTPUT_DIR/Config/ConfigJsonStub/${name}.json"
done

# --- Settings root (4 files) ---
echo ""
echo "=== Settings (root) ==="
for name in SettingsInAppSettingsAllValid SettingsInAppSettingsError SettingsInAppSettingsPartialError SettingsInAppSettingsTypeError; do
  generate "$STUBS/Settings/${name}.pkl" "$OUTPUT_DIR/Settings/${name}.json"
done

# --- Settings/SettingsJsonStubs/SettingsConfig.json ---
echo ""
echo "=== Settings (SettingsJsonStubs) ==="
generate "$STUBS/Settings/SettingsConfig.pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs/SettingsConfig.json"

# --- Settings/SettingsJsonStubs/TtlErrors (4 files) ---
echo ""
echo "=== Settings > TtlErrors ==="
for pkl in "$STUBS"/Settings/TtlErrors/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs/TtlErrors/${name}.json"
done

# --- Settings/SettingsJsonStubs/SlidingExpirationsError (6 files) ---
echo ""
echo "=== Settings > SlidingExpirationsError ==="
for pkl in "$STUBS"/Settings/SlidingExpirationsError/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs/SlidingExpirationsError/${name}.json"
done

# --- Settings/SettingsJsonStubs/OperationsErrors (13 files) ---
echo ""
echo "=== Settings > OperationsErrors ==="
for pkl in "$STUBS"/Settings/OperationsErrors/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs/OperationsErrors/${name}.json"
done

# --- Settings/SettingsJsonStubs/InappError (7 files) ---
echo ""
echo "=== Settings > InappError ==="
for pkl in "$STUBS"/Settings/InappError/*.pkl; do
  name=$(basename "$pkl" .pkl)
  generate "$pkl" "$OUTPUT_DIR/Settings/SettingsJsonStubs/InappError/${name}.json"
done

# --- Summary ---
echo ""
TOTAL=$(find "$OUTPUT_DIR" -name "*.json" | wc -l | tr -d ' ')
echo "Done! Generated $TOTAL JSON files."
if [ $ERRORS -gt 0 ]; then
  echo "WARNING: $ERRORS file(s) failed to generate."
  exit 1
else
  echo "All files generated successfully."
fi
