pragma Singleton

// Keyboard layouts follow compositor events; there is no polling timer.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "KeyboardLayout.js" as Layout

Singleton {
    id: root

    property var keyboards: []
    property string preferredKeyboard: ""
    readonly property var state: Layout.describe(keyboards, preferredKeyboard)
    readonly property string label: state.label
    readonly property string layoutName: state.name
    readonly property var layouts: state.layouts
    readonly property bool available: label !== ""
    readonly property bool canSwitch: state.count > 1 && !switchProc.running
    property bool refreshPending: false

    function refresh() {
        refreshPending = true;
        flushRefresh();
    }

    function flushRefresh() {
        if (!refreshPending || devicesProc.running) return;
        refreshPending = false;
        devicesProc.running = true;
    }

    function selectLayout(index) {
        if (!canSwitch) return;
        const command = Layout.selectionCommand(state, index);
        if (command.length === 0) return;
        // Select an absolute index so keyboards with different current groups
        // return to the same layout rather than cycling out of step.
        switchProc.command = command;
        switchProc.running = true;
    }

    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keyboards = JSON.parse(text).keyboards || [];
                } catch (e) { console.warn("Keyboard: could not read devices:", e); }
            }
        }
        stderr: StdioCollector {}
        onExited: Qt.callLater(root.flushRefresh)
    }

    Process {
        id: switchProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                root.preferredKeyboard = event.parse(2)[0];
                root.refresh();
            } else if (event.name === "configreloaded") {
                root.preferredKeyboard = "";
                root.refresh();
            }
        }
    }

    Component.onCompleted: refresh()
}
