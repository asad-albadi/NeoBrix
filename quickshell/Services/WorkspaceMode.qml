pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property bool enabled: false
    property int spaces: 5
    property var monitors: []
    function refresh() { probe.running = true }
    function ids(name) { for (const m of monitors) if (m.name === name) return m.ids; return [] }
    function setEnabled(value) { change.command = ["neobrix-workspaces", "enabled", value ? "1" : "0"]; change.running = true }
    function setSpaces(value) { change.command = ["neobrix-workspaces", "spaces", String(value)]; change.running = true }
    function focus(local) { action.command = ["neobrix-workspaces", "focus", String(local)]; action.running = true }
    function cycle(delta) { action.command = ["neobrix-workspaces", "cycle", String(delta)]; action.running = true }
    function consume(text) { try { const v = JSON.parse(text); enabled = !!v.enabled; spaces = v.spaces || 5; monitors = v.monitors || [] } catch(e) {} }
    Process {
        id: probe
        command: ["neobrix-workspaces", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.consume(text)
        }
        stderr: StdioCollector {}
    }
    // Monitor hotplugging does not necessarily restart the shell.  Reconcile
    // exactly when Hyprland reports a monitor topology event, rather than
    // polling the compositor while the shell is idle.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name && event.name.indexOf("monitor") !== -1)
                root.refresh()
        }
    }
    Process {
        id: change
        running: false
        onExited: root.refresh()
        stderr: StdioCollector {}
    }
    Process {
        id: action
        running: false
        stderr: StdioCollector {}
    }
}
