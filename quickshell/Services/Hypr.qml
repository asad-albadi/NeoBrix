pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Hyprland dispatch, in whichever syntax the running compositor expects.
//
//  Hyprland evaluates the argument of a dispatch request as *Lua* when a Lua
//  config is loaded, and as a legacy dispatcher string otherwise. So
//  `Hyprland.dispatch("workspace 2")` — the form every Hyprland example uses —
//  fails under a Lua config with:
//
//      error: [string "return hl.dispatch(workspace 2)"]:1: ')' expected near '2'
//
//  Quickshell exposes `Hyprland.usingLua` precisely so a config can adapt.
//  Everything in this shell goes through the helpers below rather than calling
//  Hyprland.dispatch directly, so the bar keeps working under either format.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property bool usingLua: Hyprland.usingLua

    // Name of the special workspace configured in hypr/config/workspaces.lua.
    readonly property string scratchpad: "scratch"

    function dispatch(legacy, lua) {
        Hyprland.dispatch(usingLua ? lua : legacy);
    }

    // ── workspaces ──────────────────────────────────────────────────────────
    function focusWorkspace(id) {
        dispatch("workspace " + id,
                 "hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))");
    }

    // `selector` is a Hyprland workspace selector such as "m-1", "e+1".
    function focusWorkspaceRelative(selector) {
        dispatch("workspace " + selector,
                 "hl.dispatch(hl.dsp.focus({ workspace = " + quote(selector) + " }))");
    }

    function toggleSpecialWorkspace(name) {
        const target = name || root.scratchpad;
        dispatch("togglespecialworkspace " + target,
                 "hl.dispatch(hl.dsp.workspace.toggle_special(" + quote(target) + "))");
    }

    // ── windows ─────────────────────────────────────────────────────────────
    function focusWindow(address) {
        dispatch("focuswindow address:" + address,
                 "hl.dispatch(hl.dsp.focus({ window = " + quote("address:" + address) + " }))");
    }

    function closeWindow(address) {
        dispatch("closewindow address:" + address,
                 "hl.dispatch(hl.dsp.window.close({ window = " + quote("address:" + address) + " }))");
    }

    // Lua string literal. Addresses and selectors never contain quotes, but
    // building Lua source without escaping is a bad habit to leave lying around.
    function quote(s) {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }
}
