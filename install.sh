#!/usr/bin/env bash
# Install the Omarchy VPN bar widget:
#  1. copies the scripts to ~/.config/omarchy/bar/scripts/
#  2. adds the "vpn" command widget to ~/.config/omarchy/shell.json
#  3. binds SUPER+SHIFT+V to the toggle in ~/.config/hypr/bindings.lua
#     (skip with --no-keybinding, or change the key with --key "SUPER + ALT + V")
set -euo pipefail

keybinding=1
key="SUPER + SHIFT + V"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-keybinding) keybinding=0 ;;
    --key) key=$2; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=~/.config/omarchy/bar/scripts
shell_json=~/.config/omarchy/shell.json

for dep in nmcli python3; do
  command -v "$dep" >/dev/null || { echo "Missing dependency: $dep" >&2; exit 1; }
done

mkdir -p "$scripts_dir"
install -m 755 "$here/scripts/vpn-status" "$here/scripts/vpn-toggle" "$scripts_dir/"
echo "Installed scripts to $scripts_dir"

# Omarchy only reads the user's shell.json once it exists; seed it from the
# packaged default so the bar layout is complete.
if [ ! -f "$shell_json" ]; then
  mkdir -p "$(dirname "$shell_json")"
  cp "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" "$shell_json"
  echo "Created $shell_json from Omarchy defaults"
fi

cp "$shell_json" "$shell_json.bak.$(date +%s)"

python3 - "$shell_json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
layout = d.setdefault("bar", {}).setdefault("layout", {})
for section in layout.values():
    if any(e.get("id") == "vpn" for e in section):
        print("Widget 'vpn' already present in shell.json; leaving layout unchanged")
        sys.exit(0)
widget = {
    "id": "vpn",
    "type": "command",
    "exec": "~/.config/omarchy/bar/scripts/vpn-status",
    "interval": 3,
    "tooltip": "VPN",
    "onClick": "~/.config/omarchy/bar/scripts/vpn-toggle",
    "onRightClick": "nm-connection-editor",
}
right = layout.setdefault("right", [])
idx = next((i + 1 for i, e in enumerate(right) if e.get("id") == "omarchy.tray"), 0)
right.insert(idx, widget)
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
print("Added 'vpn' widget to the right section of shell.json")
PY

bindings=~/.config/hypr/bindings.lua
if [ "$keybinding" = 1 ]; then
  if [ -f "$bindings" ] && grep -q 'scripts/vpn-toggle' "$bindings"; then
    echo "Keybinding for vpn-toggle already present in $bindings; leaving it unchanged"
  else
    mkdir -p "$(dirname "$bindings")"
    [ -f "$bindings" ] && cp "$bindings" "$bindings.bak.$(date +%s)"
    printf '\n-- VPN toggle (installed by omarchy_vpn_widget)\no.bind("%s", "Toggle VPN", "~/.config/omarchy/bar/scripts/vpn-toggle")\n' "$key" >> "$bindings"
    echo "Bound $key to vpn-toggle in $bindings"
    if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
      errors=$(hyprctl configerrors 2>/dev/null || true)
      [ -n "$errors" ] && [ "$errors" != "no errors" ] && echo "Hyprland config errors:" && echo "$errors"
    fi
  fi
fi

echo "Done. The Omarchy shell reloads shell.json automatically."
echo "If the icon does not appear, run: omarchy restart shell"
