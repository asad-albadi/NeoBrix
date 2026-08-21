pragma Singleton

// Session / power actions.
//
// Commands were verified on this machine before being wired to the UI:
//   * the session is managed by uwsm, so logout goes through `uwsm stop`
//     (falls back to `hyprctl dispatch exit` if uwsm is not in charge)
//   * suspend/reboot/poweroff go through systemctl/logind, not raw signals
//   * lock uses hyprlock via loginctl so logind knows the session is locked

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool underUwsm: Quickshell.env("UWSM_FINALIZE_VARNAMES") !== null
                                     && Quickshell.env("UWSM_FINALIZE_VARNAMES") !== ""

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    function lock() { run("loginctl lock-session || hyprlock"); }
    function logout() {
        // Not `hyprctl dispatch exit`: under a Lua config the dispatch argument
        // is Lua, so the bare word is a syntax error and logout does nothing.
        run(root.underUwsm ? "uwsm stop"
                           : "hyprctl eval 'hl.dispatch(hl.dsp.exit())'");
    }
    function suspend() { run("systemctl suspend"); }
    function hibernate() { run("systemctl hibernate"); }
    function reboot() { run("systemctl reboot"); }
    function shutdown() { run("systemctl poweroff"); }

    // Whether hibernate is actually possible — hidden when it is not.
    property bool canHibernate: false
    Process {
        command: ["sh", "-c", "systemctl hibernate --dry-run >/dev/null 2>&1 && echo yes"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.trim() === "yes"
        }
    }
}
