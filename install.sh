#!/usr/bin/env bash
# Install the Omarchy VPN widget as a shell plugin and bind a toggle key.
#
#   ./install.sh                      # plugin + SUPER+SHIFT+V keybinding
#   ./install.sh --no-keybinding      # plugin only
#   ./install.sh --key "SUPER + ALT + V"
#
# The plugin itself is installed with `omarchy plugin add`, which clones this
# repository into ~/.config/omarchy/plugins/juancasa.vpn and enables it.
set -euo pipefail

repo_url="https://github.com/juancasa/omarchy_vpn_widget.git"
plugin_id="juancasa.vpn"
plugin_dir=~/.config/omarchy/plugins/$plugin_id
bindings=~/.config/hypr/bindings.lua
keybinding=1
key="SUPER + SHIFT + V"

while [ $# -gt 0 ]; do
  case "$1" in
    --no-keybinding) keybinding=0 ;;
    --key) key=$2; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

for dep in nmcli omarchy git; do
  command -v "$dep" >/dev/null || { echo "Missing dependency: $dep" >&2; exit 1; }
done

if [ -d "$plugin_dir" ]; then
  echo "Plugin already installed at $plugin_dir; updating instead"
  omarchy plugin update "$plugin_id" --yes
  omarchy plugin enable "$plugin_id" >/dev/null 2>&1 || true
else
  omarchy plugin add "$repo_url" --enable --yes
fi

if [ "$keybinding" = 1 ]; then
  if [ -f "$bindings" ] && grep -q 'scripts/vpn-toggle' "$bindings"; then
    echo "Keybinding for vpn-toggle already present in $bindings; leaving it unchanged"
  else
    mkdir -p "$(dirname "$bindings")"
    [ -f "$bindings" ] && cp "$bindings" "$bindings.bak.$(date +%s)"
    printf '\n-- VPN toggle (installed by omarchy_vpn_widget)\no.bind("%s", "Toggle VPN", "~/.config/omarchy/plugins/%s/scripts/vpn-toggle")\n' "$key" "$plugin_id" >> "$bindings"
    echo "Bound $key to vpn-toggle in $bindings"
    if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
      errors=$(hyprctl configerrors 2>/dev/null || true)
      [ -n "$errors" ] && [ "$errors" != "no errors" ] && echo "Hyprland config errors:" && echo "$errors"
    fi
  fi
fi

echo "Done. The VPN icon sits in the right section of the bar; move it with: omarchy bar move $plugin_id --section <left|center|right>"
