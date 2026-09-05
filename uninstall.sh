#!/usr/bin/env bash
# Remove the Omarchy VPN bar widget and its scripts.
set -euo pipefail

scripts_dir=~/.config/omarchy/bar/scripts
shell_json=~/.config/omarchy/shell.json

rm -f "$scripts_dir/vpn-status" "$scripts_dir/vpn-toggle"

if [ -f "$shell_json" ]; then
  cp "$shell_json" "$shell_json.bak.$(date +%s)"
  python3 - "$shell_json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
layout = d.get("bar", {}).get("layout", {})
for name, section in layout.items():
    layout[name] = [e for e in section if e.get("id") != "vpn"]
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
fi
echo "Removed the vpn widget. ~/.config/omarchy/bar/vpn-default was left in place if you created it."
