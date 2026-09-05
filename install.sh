#!/usr/bin/env bash
# Install the Omarchy VPN bar widget:
#  1. copies the scripts to ~/.config/omarchy/bar/scripts/
#  2. adds the "vpn" command widget to ~/.config/omarchy/shell.json
set -euo pipefail

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

echo "Done. The Omarchy shell reloads shell.json automatically."
echo "If the icon does not appear, run: omarchy restart shell"
