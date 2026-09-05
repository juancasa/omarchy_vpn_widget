#!/usr/bin/env bash
# Remove the Omarchy VPN widget plugin and the keybinding install.sh added.
set -euo pipefail

plugin_id="juancasa.vpn"
bindings=~/.config/hypr/bindings.lua

if [ -d ~/.config/omarchy/plugins/$plugin_id ]; then
  omarchy plugin remove "$plugin_id" --yes 2>/dev/null || omarchy plugin remove "$plugin_id"
fi

if [ -f "$bindings" ] && grep -q 'installed by omarchy_vpn_widget' "$bindings"; then
  cp "$bindings" "$bindings.bak.$(date +%s)"
  sed -i '/-- VPN toggle (installed by omarchy_vpn_widget)/,+1d' "$bindings"
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
  echo "Removed the VPN keybinding from $bindings"
fi

echo "Removed the $plugin_id plugin. NetworkManager VPN profiles were left untouched."
