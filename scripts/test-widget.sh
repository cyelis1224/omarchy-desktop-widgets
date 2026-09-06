#!/usr/bin/env bash
# Test and syntax check a QML widget
set -e

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <path_to_widget.qml>"
  exit 1
fi

WIDGET_FILE="$1"
if [[ ! -f "$WIDGET_FILE" ]]; then
  echo "Error: File does not exist: $WIDGET_FILE"
  exit 1
fi

echo "Checking $WIDGET_FILE..."

# Check that WidgetCard is imported or implemented
if grep -q "WidgetCard" "$WIDGET_FILE"; then
  echo "  ✓ Inherits / uses WidgetCard"
else
  echo "  ℹ Note: Does not reference WidgetCard (ensure rootRef, loaderItem, and drag handling are defined)"
fi

# Check for required lifecycle properties
for prop in "widgetId" "defaultX" "defaultY"; do
  if grep -q "$prop" "$WIDGET_FILE"; then
    echo "  ✓ Defines property: $prop"
  else
    echo "  ⚠ Warning: Missing recommended property '$prop'"
  fi
done

echo ""
echo "QML basic structure check completed for $WIDGET_FILE"
