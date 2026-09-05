import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// VPN bar widget for Omarchy.
//
// Polls NetworkManager through scripts/vpn-status and renders a shield icon:
// crossed out while no VPN is up, outlined while one is activating, and a
// locked shield in the bar's accent color once connected. Left click runs
// scripts/vpn-toggle, right click opens the connection editor, middle click
// refreshes immediately.
BarWidget {
  id: root
  moduleName: "juancasa.vpn"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string statusScript: pluginDir + "/scripts/vpn-status"
  readonly property string toggleScript: pluginDir + "/scripts/vpn-toggle"

  readonly property int interval: Math.max(1, Number(setting("interval", 3)))
  readonly property string profile: String(setting("profile", ""))
  readonly property string editor: String(setting("editor", "nm-connection-editor"))
  readonly property bool notify: setting("notify", true) !== false

  property string icon: ""
  property string tooltip: "VPN"
  property string state: "unknown"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggle() {
    if (!root.bar) return
    var cmd = Util.shellQuote(toggleScript)
    if (profile !== "") cmd += " " + Util.shellQuote(profile)
    if (!notify) cmd = "VPN_WIDGET_QUIET=1 " + cmd
    root.bar.run(cmd)
    // The connect handshake takes a moment; poll sooner than the regular tick.
    quickRefresh.restart()
  }

  function openEditor() {
    if (root.bar && editor !== "") root.bar.run(editor)
  }

  function applyStatus(raw) {
    var data = Util.parseModuleJson(raw)
    icon = data.text || ""
    tooltip = data.tooltip || "VPN"
    state = data.class || "unknown"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onIntervalChanged: pollTimer.restart()

  IpcHandler {
    target: "juancasa.vpn"

    function toggle(): void { root.toggle() }
    function refresh(): void { root.broadcast("refresh") }
    function editor(): void { root.openEditor() }
  }

  Process {
    id: statusProc
    command: ["bash", root.statusScript]
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
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openEditor()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }
}
