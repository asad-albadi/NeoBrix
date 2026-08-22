pragma Singleton

// Displays: what is connected, and changing it.
//
// Reading is free and needs no polling. Quickshell's Hyprland IPC keeps a live
// model of monitors, and each one carries `lastIpcObject` -- the same blob
// `hyprctl monitors` prints -- which is where the mode list, refresh rate,
// transform, VRR and physical size come from. One caveat learnt the hard way
// elsewhere in this shell: an object that arrived over the event socket can have
// an empty lastIpcObject, so a monitor event asks for a refresh rather than
// trusting what it was handed.
//
// Writing goes through neobrix-monitors, never through hyprctl directly. That
// keeps one owner for the layout, gives the same behaviour from a terminal, and
// means the revert timer that saves you from a black screen lives in a detached
// process rather than in the shell that might be the thing that just died.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // ── reading ─────────────────────────────────────────────────────────────

    readonly property var devices: Hyprland.monitors ? Hyprland.monitors.values : []

    // Normalised, sorted left to right, with the ipc blob folded in.
    readonly property var list: {
        const out = [];
        for (const m of root.devices) {
            const ipc = m.lastIpcObject || {};
            const scale = m.scale || ipc.scale || 1;
            const transform = ipc.transform || 0;
            const modeW = m.width || ipc.width || 0;
            const modeH = m.height || ipc.height || 0;
            // A rotated screen occupies its mode turned on its side, but Hyprland
            // reports the mode unrotated -- a 2560x1440 panel at transform 1 is
            // 1440 wide and 2560 tall in the layout. Transforms 1, 3, 5 and 7 are
            // the quarter turns; 4 and 6 are flips, which do not swap anything.
            // Getting this wrong drew the tile in landscape and, worse, made
            // every snap and span 1120px out, so screens that looked adjacent had
            // dead space between them and the pointer could not cross.
            const turned = transform % 2 === 1;
            out.push({
                name: m.name,
                description: m.description || ipc.description || m.name,
                focused: m.focused === true,
                x: m.x, y: m.y,
                width: m.width || ipc.width || 0,
                height: m.height || ipc.height || 0,
                scale: scale,
                // What the layout actually occupies, which is the mode divided
                // by the scale -- a 3840-wide panel at 2x is 1920 wide as far as
                // positions are concerned.
                logicalWidth: Math.round((turned ? modeH : modeW) / scale),
                logicalHeight: Math.round((turned ? modeW : modeH) / scale),
                refreshRate: ipc.refreshRate || 0,
                modes: ipc.availableModes || [],
                transform: ipc.transform || 0,
                vrr: ipc.vrr === true,
                disabled: ipc.disabled === true,
                mirrorOf: ipc.mirrorOf && ipc.mirrorOf !== "none" ? ipc.mirrorOf : "",
                physicalWidth: ipc.physicalWidth || 0,
                physicalHeight: ipc.physicalHeight || 0,
                make: ipc.make || "",
                model: ipc.model || "",
            });
        }
        for (const off of root.offlineList) {
            let known = false;
            for (const m of out) if (m.name === off.name) { known = true; break; }
            if (!known) out.push(off);
        }
        out.sort((a, b) => a.x - b.x || a.y - b.y);
        return out;
    }

    // Quickshell's model only carries *enabled* outputs, so a screen switched off
    // disappears from it -- and a screen you cannot see is a screen you cannot
    // switch back on. `hyprctl monitors all` lists the disabled ones too, and
    // still reports their mode, scale and position, which is everything needed
    // to show a row and offer it back. This is a read; writes still go through
    // neobrix-monitors so there is one owner of the layout.
    property var offlineList: []
    property string offlineJson: "[]"

    // Set while a drag is in progress. Even a no-op refresh is worth skipping
    // then: it is the one moment when replacing the model would be felt.
    property bool interacting: false

    Process {
        id: allProc
        command: ["hyprctl", "-j", "monitors", "all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const off = [];
                try {
                    for (const m of JSON.parse(text)) {
                        if (!m.disabled) continue;
                        const scale = m.scale || 1;
                        const turned = (m.transform || 0) % 2 === 1;
                        off.push({
                            name: m.name,
                            description: m.description || m.name,
                            focused: false,
                            x: m.x, y: m.y,
                            width: m.width || 0, height: m.height || 0,
                            scale: scale,
                            logicalWidth: Math.round((turned ? (m.height || 0) : (m.width || 0)) / scale),
                            logicalHeight: Math.round((turned ? (m.width || 0) : (m.height || 0)) / scale),
                            refreshRate: m.refreshRate || 0,
                            modes: m.availableModes || [],
                            transform: m.transform || 0,
                            vrr: m.vrr === true,
                            disabled: true,
                            mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "",
                            physicalWidth: m.physicalWidth || 0,
                            physicalHeight: m.physicalHeight || 0,
                            make: m.make || "", model: m.model || "",
                        });
                    }
                } catch (e) {}
                // Only assign when it actually changed. A fresh array every two
                // seconds re-evaluates `list`, which resets the Repeater and
                // destroys the delegate -- and the MouseArea holding the drag
                // state -- out from under anyone mid-drag, so the drop never
                // landed and the screen sprang back. Three of four test drags
                // failed this way and were written off as flaky input.
                const next = JSON.stringify(off);
                if (next !== root.offlineJson) {
                    root.offlineJson = next;
                    root.offlineList = off;
                }
            }
        }
        stderr: StdioCollector {}
    }

    function refreshAll() {
        Hyprland.refreshMonitors();
        allProc.running = true;
    }

    // The layout can be changed from outside this shell -- from a terminal, by
    // another tool, or by Hyprland itself reacting to something -- and a
    // reconfigure does not reliably reach us as an event. A panel showing a stale
    // layout is worse than one showing none: it drew a gap that was not there and
    // warned about a pointer that could cross perfectly well. So while something
    // is looking at the tab, the truth is re-read; when nothing is, this costs
    // nothing at all.
    property int viewers: 0
    function subscribe() { viewers++; refreshAll(); }
    function unsubscribe() { viewers = Math.max(0, viewers - 1); }

    Timer {
        interval: 2000
        repeat: true
        running: root.viewers > 0 && !root.interacting
        onTriggered: root.refreshAll()
    }

    readonly property int count: root.list.length

    function byName(name) {
        for (const m of root.list) if (m.name === name) return m;
        return null;
    }

    // Hotplug. Hyprland names these monitoradded/monitorremoved (and a v2
    // variant); matching on the substring covers all of them without caring
    // which spelling this version emits.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name && event.name.indexOf("monitor") !== -1) {
                Hyprland.refreshMonitors();
                root.refreshAll();
                root.reloadProfiles();
            }
        }
    }

    // ── derived facts the panel shows ───────────────────────────────────────

    // Hyprland refuses a scale that does not divide the mode into whole pixels
    // ("failed to find a clean divisor"), so offering a free slider would mostly
    // offer errors. These are the usual steps, filtered down to the ones this
    // particular panel can actually take.
    readonly property var scaleSteps: [1, 1.2, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3]

    function validScales(width, height) {
        const out = [];
        for (const s of root.scaleSteps) {
            const w = width / s, h = height / s;
            if (Math.abs(w - Math.round(w)) < 0.001 && Math.abs(h - Math.round(h)) < 0.001)
                out.push({ label: root.scaleLabel(s) + "  (" + Math.round(w) + "×" + Math.round(h) + ")",
                           value: s });
        }
        if (out.length === 0) out.push({ label: "1  (" + width + "×" + height + ")", value: 1 });
        return out;
    }

    function scaleLabel(s) {
        const r = Math.round(s * 100) / 100;
        return (r === Math.round(r) ? String(Math.round(r)) : String(r)) + "×";
    }

    // Physical size is in millimetres, so this is a real figure rather than a
    // guess, and it is what makes a scale suggestion worth showing.
    function dpiOf(m) {
        if (!m || !m.physicalWidth) return 0;
        return Math.round(m.width / (m.physicalWidth / 25.4));
    }

    function suggestedScale(m) {
        const dpi = root.dpiOf(m);
        if (!dpi) return 1;
        // The thresholds are the conventional ones: a 96dpi-ish panel wants 1×,
        // and every doubling of density wants another step.
        if (dpi >= 250) return 2;
        if (dpi >= 190) return 1.5;
        if (dpi >= 150) return 1.25;
        return 1;
    }

    // Hyprland reports the real rate (143.981, 59.951) while the mode list
    // advertises 144 and 59.95, so comparing the two with === never matched and
    // the mode picker showed a raw string with no row highlighted. Snap to the
    // advertised mode, the same way neobrix-monitors does when it saves one.
    function modeStringFor(m) {
        if (!m) return "";
        let best = "", bestD = 1.5;
        for (const am of m.modes) {
            const res = am.split("@")[0];
            const hz = parseFloat((am.split("@")[1] || "").replace("Hz", ""));
            if (res !== m.width + "x" + m.height || isNaN(hz)) continue;
            const d = Math.abs(hz - m.refreshRate);
            if (d < bestD) { best = res + "@" + (Math.round(hz * 100) / 100); bestD = d; }
        }
        return best !== "" ? best
             : m.width + "x" + m.height + "@" + (Math.round(m.refreshRate * 100) / 100);
    }

    function rotationLabel(t) {
        switch (t) {
        case 1: return "90°";
        case 2: return "180°";
        case 3: return "270°";
        case 4: return "flipped";
        case 5: return "flip 90°";
        case 6: return "flip 180°";
        case 7: return "flip 270°";
        default: return "";
        }
    }

    // Screens that do not touch leave dead space, and the pointer cannot cross
    // dead space -- the layout looks right and the cursor refuses to move
    // between two monitors sitting side by side. Rotating a screen is the usual
    // way to end up here, because its footprint changes underneath a layout
    // built for the old one.
    readonly property bool hasGap: root.gapIn(root.list)

    function gapIn(list) {
        const on = [];
        for (const m of list) if (!m.disabled) on.push(m);
        if (on.length < 2) return false;
        for (const a of on) {
            let touches = false;
            for (const b of on) {
                if (a.name === b.name) continue;
                const hTouch = (a.x + a.logicalWidth === b.x || b.x + b.logicalWidth === a.x)
                    && a.y < b.y + b.logicalHeight && b.y < a.y + a.logicalHeight;
                const vTouch = (a.y + a.logicalHeight === b.y || b.y + b.logicalHeight === a.y)
                    && a.x < b.x + b.logicalWidth && b.x < a.x + a.logicalWidth;
                if (hTouch || vTouch) { touches = true; break; }
            }
            if (!touches) return true;
        }
        return false;
    }

    // A staged layout, applied in one go. The Displays tab collects edits and
    // sends them together so the screens move once, instead of jerking after
    // every adjustment on the way to the arrangement somebody wanted.
    function applyLayout(draft) {
        root.runChange(["neobrix-monitors", "--revert-after", String(root.revertWindow),
                        "layout", JSON.stringify(draft)]);
    }

    // What a monitor would look like with a staged edit applied, including the
    // footprint it would then occupy -- changing the mode, the scale or the
    // rotation all change how much room a screen takes, and the map has to draw
    // the staged arrangement rather than the live one.
    function derive(base, over) {
        const o = {};
        for (const k in base) o[k] = base[k];
        if (!over) return o;

        let w = base.width, h = base.height;
        if (over.mode !== undefined) {
            const res = String(over.mode).split("@")[0].split("x");
            if (res.length === 2) {
                w = parseInt(res[0]);
                h = parseInt(res[1]);
            }
        }
        const scale = over.scale !== undefined ? Number(over.scale) : base.scale;
        const t = over.transform !== undefined ? Number(over.transform) : base.transform;
        const turned = t % 2 === 1;

        o.width = w;
        o.height = h;
        o.scale = scale;
        o.transform = t;
        o.logicalWidth = Math.round((turned ? h : w) / scale);
        o.logicalHeight = Math.round((turned ? w : h) / scale);

        if (over.position !== undefined) {
            const p = String(over.position).split("x");
            o.x = parseInt(p[0]);
            o.y = parseInt(p[1]);
        }
        if (over.disabled !== undefined)
            o.disabled = over.disabled === true || String(over.disabled) === "true";
        if (over.vrr !== undefined)
            o.vrr = Number(over.vrr) === 1;
        if (over.mirror !== undefined)
            o.mirrorOf = over.mirror === "none" ? "" : over.mirror;
        if (over.mode !== undefined) {
            const hz = parseFloat((String(over.mode).split("@")[1] || ""));
            if (!isNaN(hz)) o.refreshRate = hz;
        }
        return o;
    }

    function arrange() {
        root.runChange(["neobrix-monitors", "--revert-after", String(root.revertWindow),
                        "arrange"]);
    }

    readonly property var transformOptions: [
        { label: "No rotation", value: 0 },
        { label: "90° right",   value: 1 },
        { label: "180°",        value: 2 },
        { label: "90° left",    value: 3 },
        { label: "Flipped",     value: 4 },
        { label: "Flipped 90°", value: 5 },
        { label: "Flipped 180°", value: 6 },
        { label: "Flipped 270°", value: 7 },
    ]

    // ── profiles ────────────────────────────────────────────────────────────

    property var profiles: []
    property string fingerprint: ""

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/neobrix/monitors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseProfiles(text())
        onLoadFailed: root.profiles = []
    }

    function parseProfiles(raw) {
        try {
            const st = JSON.parse(raw);
            const out = [];
            for (const fp in st.profiles || {}) {
                const p = st.profiles[fp];
                out.push({ fingerprint: fp, name: p.name || fp,
                           outputsSeen: p.outputs_seen || "", outputs: p.outputs || {} });
            }
            out.sort((a, b) => a.name.localeCompare(b.name));
            root.profiles = out;
        } catch (e) {
            root.profiles = [];
        }
    }

    function reloadProfiles() { stateFile.reload(); fingerprintProc.running = true; }

    Process {
        id: fingerprintProc
        command: ["neobrix-monitors", "fingerprint"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.fingerprint = text.trim().split(/\s+/)[0] || ""
        }
        stderr: StdioCollector {}
    }

    // True when the current set of screens already has something saved, which is
    // the difference between "Save" and "Update".
    readonly property bool currentSetSaved: {
        for (const p of root.profiles) if (p.fingerprint === root.fingerprint) return true;
        return false;
    }

    // ── changing things ─────────────────────────────────────────────────────

    // Seconds the panel counts down while a change is unconfirmed. The script
    // runs its own timer of the same length and is the one that actually reverts;
    // this is only what the countdown shows.
    readonly property int revertWindow: 12

    property bool pending: false
    property int pendingSeconds: 0
    property string lastError: ""

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        running: root.pending
        onTriggered: {
            root.pendingSeconds--;
            // The script reverts on its own; when its window closes, stop
            // claiming a change is still waiting.
            if (root.pendingSeconds <= 0) root.pending = false;
        }
    }

    function set(output, changes) {
        const args = ["neobrix-monitors", "--revert-after", String(root.revertWindow), "set", output];
        for (const k in changes) args.push(k + "=" + changes[k]);
        root.runChange(args);
    }

    function applyProfile(name) {
        root.runChange(["neobrix-monitors", "--revert-after", String(root.revertWindow),
                        "apply", name]);
    }

    function runChange(args) {
        root.lastError = "";
        changeProc.command = args;
        changeProc.running = true;
        root.pending = true;
        root.pendingSeconds = root.revertWindow;
    }

    Process {
        id: changeProc
        running: false
        onExited: root.refreshAll()
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    root.lastError = text.trim().split("\n")[0];
                    // The countdown deliberately stays. apply_json reports per
                    // output, and it does so *after* the snapshot was taken and
                    // the detached revert scheduled -- so one output rejecting
                    // its mode does not mean nothing happened. Clearing the
                    // countdown here hid Keep and Revert while the watcher went
                    // on to undo a change the person had no way to keep.
                }
            }
        }
    }

    function confirm() {
        root.pending = false;
        confirmProc.running = true;
    }

    Process {
        id: confirmProc
        command: ["neobrix-monitors", "confirm"]
        running: false
        stderr: StdioCollector {}
        onExited: {
            root.refreshAll();
            // Keeping a change is a statement about how these screens should be,
            // so if this set of screens already has a profile, the profile
            // becomes what was just kept. Without this "Keep" lasts until the
            // next reboot and then the old profile puts it back, which is not
            // what keeping something means. A set with nothing saved is left
            // alone -- saving the first profile stays a deliberate act.
            if (root.currentSetSaved) {
                for (const p of root.profiles)
                    if (p.fingerprint === root.fingerprint) { root.save(p.name); return; }
            }
            root.regenerate();
        }
    }

    function revert() {
        root.pending = false;
        plainProc.command = ["neobrix-monitors", "revert"];
        plainProc.running = true;
    }

    function save(name) {
        saveProc.command = name && name !== "" ? ["neobrix-monitors", "save", name]
                                               : ["neobrix-monitors", "save"];
        saveProc.running = true;
    }

    function forget(name) {
        forgetProc.command = ["neobrix-monitors", "forget", name];
        forgetProc.running = true;
    }

    function regenerate() {
        plainGenProc.running = true;
    }

    Process { id: plainProc; running: false; stderr: StdioCollector {} }
    Process {
        id: plainGenProc
        command: ["neobrix-monitors", "generate"]
        running: false
        stderr: StdioCollector {}
    }
    Process {
        id: saveProc
        running: false
        onExited: { root.reloadProfiles(); root.regenerate(); }
        stderr: StdioCollector {}
    }
    Process {
        id: forgetProc
        running: false
        onExited: { root.reloadProfiles(); root.regenerate(); }
        stderr: StdioCollector {}
    }
}
