pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Single source of truth for which panel is on screen.
//
//  Only one panel is ever open at a time, which keeps focus handling simple and
//  matches how the Neobrix dashboard behaves. Hyprland keybinds drive this
//  through either GlobalShortcut (preferred, no process spawn) or `qs ipc`.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Theme
import qs.Services

Singleton {
    id: root

    // "" | launcher | control | calendar | session | clipboard | notifications
    property string current: ""
    // Sub-view inside the control center.
    readonly property var controlTabs: ["system", "connectivity", "notifications"]
    property string controlTab: "system"

    readonly property bool anyOpen: current !== ""

    function open(name) { current = name; }
    function close() { current = ""; }
    function toggle(name) { current = (current === name) ? "" : name; }
    function isOpen(name) { return current === name; }

    // An unknown tab name would leave the control center on screen with every
    // tab body hidden — a blank panel. Fall back to system instead.
    function resolveTab(tab) {
        return controlTabs.indexOf(tab) !== -1 ? tab : "system";
    }

    function openControl(tab) {
        controlTab = resolveTab(tab);
        current = "control";
    }
    function toggleControl(tab) {
        const want = resolveTab(tab);
        if (current === "control" && controlTab === want) {
            current = "";
        } else {
            controlTab = want;
            current = "control";
        }
    }

    // ── external control ────────────────────────────────────────────────────
    // qs -c neobrix ipc call panels toggle launcher
    IpcHandler {
        target: "panels"

        function toggle(panel: string): void { root.toggle(panel); }
        function open(panel: string): void { root.open(panel); }
        function close(): void { root.close(); }
        function control(tab: string): void { root.toggleControl(tab); }
        function state(): string { return root.current; }
    }

    // Theme control, also reachable as `qs -c neobrix ipc call theme toggle`.
    IpcHandler {
        target: "theme"

        function toggle(): void { Theme.toggleMode(); }
        function set(mode: string): void {
            if (mode === "dawn" || mode === "dusk") {
                Theme.mode = mode;
                Theme.persist();
            }
        }
        function get(): string { return Theme.mode; }
    }

    // ── Hyprland global shortcuts ───────────────────────────────────────────
    // Bound in hypr/config/binds.lua via the `global` dispatcher. These carry no
    // process-spawn cost, unlike shelling out to `qs ipc`.
    GlobalShortcut {
        appid: "neobrix"
        name: "launcher"
        description: "Toggle the Neobrix application launcher"
        onPressed: root.toggle("launcher")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "control"
        description: "Toggle the Neobrix control center"
        onPressed: root.toggleControl("system")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "notifications"
        description: "Toggle the Neobrix notification center"
        onPressed: root.toggleControl("notifications")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "calendar"
        description: "Toggle the Neobrix calendar panel"
        onPressed: root.toggle("calendar")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "session"
        description: "Toggle the Neobrix session menu"
        onPressed: root.toggle("session")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "clipboard"
        description: "Toggle the Neobrix clipboard history"
        onPressed: root.toggle("clipboard")
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "theme"
        description: "Toggle the Neobrix light/dark theme"
        onPressed: Theme.toggleMode()
    }

    // ── media keys ──────────────────────────────────────────────────────────
    // Handled here over MPRIS rather than by shelling out to playerctl, so the
    // media keys need no extra package and cost no process spawn.
    GlobalShortcut {
        appid: "neobrix"
        name: "media-toggle"
        description: "Play/pause the active media player"
        onPressed: Media.toggle()
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "media-next"
        description: "Next track"
        onPressed: Media.next()
    }
    GlobalShortcut {
        appid: "neobrix"
        name: "media-previous"
        description: "Previous track"
        onPressed: Media.previous()
    }
}
