# Omarchy VPN Widget

A small VPN toggle for the [Omarchy](https://omarchy.org) status bar. It shows
whether a NetworkManager VPN is up and lets you connect or disconnect with one
click. Works with OpenVPN and WireGuard profiles managed by NetworkManager.

![VPN widget in the Omarchy bar](docs/bar-off.png)

| Icon | Meaning |
|------|---------|
| 󰦞 shield, crossed out | No VPN connected |
| 󰦟 shield outline | VPN is connecting |
| 󰦝 shield with lock (accent color) | VPN connected |

Interactions:

| Action | Result |
|--------|--------|
| Left-click | Connect the VPN, or disconnect if one is already up |
| Right-click | Open `nm-connection-editor` to import or edit VPN profiles |
| Hover | Tooltip with the profile name and current state |

A desktop notification confirms every connect and disconnect, including
failures.

## Why

Omarchy's built-in network panel only handles Wi-Fi, and its bar has no VPN
control. NetworkManager already knows how to run OpenVPN and WireGuard, so this
widget is just two shell scripts wired into Omarchy's `command` bar module. No
extra daemons, no tray applet.

## Requirements

- Omarchy 4.x with the Quickshell-based shell (bar configured in `~/.config/omarchy/shell.json`). Tested on 4.0.2.
- NetworkManager with the VPN plugin for your VPN type:
  - OpenVPN: `sudo pacman -S openvpn networkmanager-openvpn`
  - WireGuard: built into NetworkManager, nothing extra to install
- `nm-connection-editor` for the right-click editor (optional but recommended):
  `sudo pacman -S nm-connection-editor`
- `python3` (used by the installer to edit `shell.json`; Omarchy ships it)
- A Nerd Font in the bar for the shield icons. Omarchy's default fonts already
  include them.

## Install

```bash
git clone https://github.com/juancasa/omarchy_vpn_widget.git
cd omarchy_vpn_widget
./install.sh
```

The installer:

1. Copies `vpn-status` and `vpn-toggle` to `~/.config/omarchy/bar/scripts/`.
2. Backs up `~/.config/omarchy/shell.json` (as `shell.json.bak.<timestamp>`).
3. Adds a `vpn` command widget to the right section of the bar, right after
   the system tray. If you have no `shell.json` yet, it is created from
   Omarchy's defaults first.

The Omarchy shell reloads `shell.json` on save, so the icon appears
immediately. If it does not, run `omarchy restart shell`.

### Manual install

If you would rather not run the installer, copy the two scripts from
`scripts/` to `~/.config/omarchy/bar/scripts/`, make them executable, and add
this entry to `bar.layout.right` in `~/.config/omarchy/shell.json`:

```json
{
  "id": "vpn",
  "type": "command",
  "exec": "~/.config/omarchy/bar/scripts/vpn-status",
  "interval": 3,
  "tooltip": "VPN",
  "onClick": "~/.config/omarchy/bar/scripts/vpn-toggle",
  "onRightClick": "nm-connection-editor"
}
```

## Add a VPN profile

The widget toggles whatever VPN profiles NetworkManager has. Import one first.

**OpenVPN, from a terminal:**

```bash
nmcli connection import type openvpn file /path/to/your.ovpn
```

If the `.ovpn` references separate certificate or key files, keep them next to
it when importing. If your VPN needs a username, set it once:

```bash
nmcli connection modify "<connection name>" vpn.user-name "<username>"
```

**WireGuard, from a terminal:**

```bash
nmcli connection import type wireguard file /path/to/wg0.conf
```

**From the GUI:** right-click the widget, press **+**, choose
**Import a saved VPN configuration…** at the bottom of the list, and pick the
file.

Check what NetworkManager knows about with:

```bash
nmcli connection show
```

## Use

- **Connect / disconnect:** left-click the shield.
- **Several profiles:** the toggle connects the first VPN profile in `nmcli`'s
  order. To choose a different one, write its exact connection name on a
  single line in `~/.config/omarchy/bar/vpn-default`:

  ```bash
  echo "Work VPN" > ~/.config/omarchy/bar/vpn-default
  ```

- **Keyboard shortcut:** the toggle is a plain script, so it can be bound in
  `~/.config/hypr/bindings.lua`:

  ```lua
  o.bind("SUPER SHIFT", "V", "exec", "~/.config/omarchy/bar/scripts/vpn-toggle", "Toggle VPN")
  ```

- **Move the widget:** drag it along the bar, or run
  `omarchy bar move vpn --section center`.

## Configure

All settings live on the widget entry in `shell.json`:

| Key | Default | Purpose |
|-----|---------|---------|
| `interval` | `3` | Seconds between status refreshes |
| `onClick` | `vpn-toggle` | Command run on left-click |
| `onRightClick` | `nm-connection-editor` | Command run on right-click |
| `onMiddleClick` | unset | Command run on middle-click |
| `fontSize` | `12` | Icon size |

To change the icons, edit the `ICON_*` variables at the top of `vpn-status`.
The scripts are re-read on every refresh, so edits apply without a restart.

## Uninstall

```bash
./uninstall.sh
```

This removes the scripts and the `vpn` entry from `shell.json` (after backing
it up). Your VPN profiles in NetworkManager are untouched.

## How it works

- `vpn-status` runs every few seconds and prints Waybar-style JSON
  (`text`, `tooltip`, `class`). Omarchy renders `class: "active"` in the bar's
  accent color, which is what lights the icon up when connected.
- `vpn-toggle` uses `nmcli connection up` / `down` on the VPN connection and
  reports the result with `notify-send`.

## Troubleshooting

- **Icon missing:** confirm the scripts are executable and print JSON when run
  by hand: `~/.config/omarchy/bar/scripts/vpn-status`. Then check the shell
  log: `journalctl --user -u omarchy-shell -b | tail`.
- **"No VPN profiles" tooltip:** import a profile (see above). The widget only
  lists connections whose type is `vpn` or `wireguard`.
- **Connect fails:** run `nmcli connection up "<name>"` in a terminal to see
  the real error. Missing certificates and wrong credentials are the usual
  causes.
- **Warning about `moduleName` in the shell log:** Omarchy prints this for
  every `command`-type widget. It is harmless.

## License

MIT, see [LICENSE](LICENSE).
