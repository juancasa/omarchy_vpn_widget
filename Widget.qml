import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// VPN bar widget for Omarchy.
//
// Polls NetworkManager through scripts/vpn-status and renders a shield icon:
// crossed out while no VPN is up, outlined while one is activating, and a
// locked shield in the bar's accent color once connected.
//
//   left click    open the profile picker popup
//   middle click  refresh now
//   The VPN toggle itself is reachable via the picker, the IPC `toggle`
//   call, or a keybinding on scripts/vpn-toggle.
BarWidget {
  id: root
  moduleName: "juancasa.omarchy_vpn"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string statusScript: pluginDir + "/scripts/vpn-status"
  readonly property string toggleScript: pluginDir + "/scripts/vpn-toggle"

  readonly property int interval: Math.max(1, Number(setting("interval", 3)))
  readonly property string profile: String(setting("profile", ""))
  readonly property string editor: String(setting("editor", "nm-connection-editor"))
  readonly property bool notify: setting("notify", true) !== false
  readonly property bool single: setting("single", true) !== false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string icon: ""
  property string tooltip: "VPN"
  property string state: "unknown"
  property var profiles: []
  property bool pickerOpen: false

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: pickerOpen
  function open() { refresh(); pickerOpen = true }
  function close() { pickerOpen = false }
  function togglePicker() { if (pickerOpen) close(); else open() }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runToggle(args) {
    if (!root.bar) return
    var cmd = Util.shellQuote(toggleScript) + (args ? " " + args : "")
    if (!notify) cmd = "VPN_WIDGET_QUIET=1 " + cmd
    root.bar.run(cmd)
    // The connect handshake takes a moment; poll sooner than the regular tick.
    quickRefresh.restart()
  }

  function toggle() {
    runToggle(profile !== "" ? Util.shellQuote(profile) : "")
  }

  function connectProfile(name) {
    runToggle("--connect " + Util.shellQuote(name))
    close()
  }

  function disconnect() {
    runToggle("--disconnect")
    close()
  }

  // Persist the default profile (the one the keybinding / IPC toggle connects)
  // onto this widget's shell.json entry. Applied locally first so the switch
  // flips on the click itself; the shell.json write comes back as the same value.
  function setDefaultProfile(name) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.profile = String(name || "")
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function openEditor() {
    if (root.bar && editor !== "") root.bar.run(editor)
    close()
  }

  function applyStatus(raw) {
    var data = Util.parseModuleJson(raw)
    icon = data.text || ""
    tooltip = data.tooltip || "VPN"
    state = data.class || "unknown"
    profiles = Array.isArray(data.profiles) ? data.profiles : []
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onIntervalChanged: pollTimer.restart()

  IpcHandler {
    target: "juancasa.omarchy_vpn"

    function toggle(): void { root.toggle() }
    function refresh(): void { root.broadcast("refresh") }
    function editor(): void { root.openEditor() }
    function connect(name: string): void { root.connectProfile(name) }
    function disconnect(): void { root.disconnect() }
    function menu(): void { root.togglePicker() }
    function setDefault(name: string): void { root.setDefaultProfile(name) }
    function open(): void { root.open() }
    function close(): void { root.close() }
  }

  Process {
    id: statusProc
    command: ["env", "VPN_WIDGET_SINGLE=" + (root.single ? "1" : "0"), "bash", root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Timer {
    id: pollTimer
    interval: root.interval * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: quickRefresh
    interval: 1200
    repeat: false
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    slotSize: Style.bar.statusSlot
    active: root.state === "active"
    dimmed: root.state === "none"
    tooltipText: root.pickerOpen ? "" : root.tooltip

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else if (b === Qt.LeftButton) root.togglePicker()
    }
  }

  PopupCard {
    id: picker
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.pickerOpen
    contentWidth: picker.fittedContentWidth(Style.space(280))
    contentHeight: picker.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "VPN"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        visible: root.profiles.length > 1
        textFormat: Text.PlainText
        text: "The switch marks the default profile, used by the toggle shortcut."
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Text {
        visible: root.profiles.length === 0
        textFormat: Text.PlainText
        text: "No VPN profiles in NetworkManager yet."
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Repeater {
        model: root.profiles

        BorderSurface {
          id: row
          required property var modelData

          readonly property string name: String(modelData.name || "")
          readonly property string connState: String(modelData.state || "")
          readonly property bool connected: connState === "activated"
          readonly property bool connecting: connState === "activating"
          readonly property bool isDefault: root.profile !== "" && name === root.profile
          readonly property bool hovered: rowMouse.containsMouse

          width: column.width
          height: rowInner.implicitHeight + Style.space(12)
          radius: Style.spacing.labelGap
          color: connected
            ? Style.selectedFillFor(root.foreground, Color.accent)
            : (hovered ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
          borderSpec: connected ? Border.controlSpec("normal", root.foreground, Color.accent) : Border.none()

          // Declared before the row content so the switch's own mouse area
          // stacks above it and keeps its clicks.
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (row.connected) root.disconnect()
              else root.connectProfile(row.name)
            }
          }

          ToggleSwitch {
            id: defaultSwitch
            anchors.right: parent.right
            anchors.rightMargin: row.borderRight + Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            checked: row.isDefault
            foreground: root.foreground
            accent: Color.accent
            trackHeight: 18
            onToggled: root.setDefaultProfile(row.isDefault ? "" : row.name)
          }

          Row {
            id: rowInner
            anchors.left: parent.left
            anchors.right: defaultSwitch.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: row.borderLeft + Style.space(8)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: row.connected ? "󰦝" : (row.connecting ? "󰦟" : "󰦞")
              color: row.connected ? Color.accent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              width: Style.space(18)
              horizontalAlignment: Text.AlignHCenter
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              width: parent.width - Style.space(26)
              spacing: Style.space(1)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                textFormat: Text.PlainText
                text: row.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: row.connected
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: (row.isDefault ? "Default · " : "")
                    + (row.connected ? "Connected. Click to disconnect"
                    : (row.connecting ? "Connecting…" : "Click to connect"))
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      Row {
        spacing: Style.space(6)

        Button {
          iconText: ""
          text: "Edit connections"
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: 8
          verticalPadding: 3
          iconSize: Style.font.bodySmall
          fontSize: Style.font.bodySmall
          onClicked: root.openEditor()
        }

        Button {
          iconText: ""
          text: "Refresh"
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: 8
          verticalPadding: 3
          iconSize: Style.font.bodySmall
          fontSize: Style.font.bodySmall
          onClicked: root.refresh()
        }
      }
    }
  }
}
