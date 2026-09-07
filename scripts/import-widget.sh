#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGE_SCRIPT="${OMARCHY_DESKTOP_WIDGETS_DIR:-$HOME/.config/omarchy/plugins/dagyr.desktop-widgets}/manage-positions.sh"
if [[ ! -f "$MANAGE_SCRIPT" ]]; then
  MANAGE_SCRIPT="$SCRIPT_DIR/../manage-positions.sh"
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <path_to_widget.qml> [Display Name]"
  echo "Or run without arguments to open graphical file picker."
  echo ""
  python3 "$MANAGE_SCRIPT" pick_widget_dialog
  exit 0
fi

FILE_PATH="$1"
NAME="$2"

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found: $FILE_PATH"
  exit 1
fi

if [[ -z "$NAME" ]]; then
  NAME="$(basename "$FILE_PATH" .qml)"
fi

echo "Registering widget: $NAME ($FILE_PATH)..."
python3 "$MANAGE_SCRIPT" add_custom_widget "$FILE_PATH" "$NAME"
echo "Successfully registered and enabled widget '$NAME'!"
echo "Reloading desktop shell..."
omarchy-restart-shell
