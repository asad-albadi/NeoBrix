pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Wallpaper selection.
//
//  The shell draws the wallpaper itself (see Wallpaper/Wallpaper.qml) rather than
//  running a wallpaper daemon. hyprpaper 0.8.4 on this machine never registers a
//  wallpaper target — it reports "Monitor <name> has no target" for every config
//  syntax and crashes on some of its IPC verbs — and rendering the image in the
//  shell removes a daemon, an IPC protocol and a process from the session while
//  giving us a crossfade for free.
//
//  The selection lives in a single state file which is *watched*, so
//  `neobrix-wallpaper` only has to write a path — no IPC round trip.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io
// Safe to import: Theme depends only on QtQuick/Quickshell, so there is no cycle.
import qs.Theme

Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME")
                                         || Quickshell.env("HOME") + "/.local/state")
                                        + "/neobrix/wallpaper"
    readonly property string wallpaperDir: (Quickshell.env("NEOBRIX_WALLPAPERS")
                                            || Quickshell.env("HOME")
                                               + "/.local/share/neobrix/wallpapers")

    // Absolute path of the current wallpaper, or "" when none is set.
    property string current: ""
    property var available: []

    function setWallpaper(path) {
        if (!path) return;
        root.current = path;
        selection.setText(path + "\n");
    }

    function next() {
        if (available.length === 0) return;
        const i = available.indexOf(current);
        setWallpaper(available[(i + 1) % available.length]);
    }

    function previous() {
        if (available.length === 0) return;
        const i = available.indexOf(current);
        setWallpaper(available[(i - 1 + available.length) % available.length]);
    }

    // Wallpapers are shipped in dawn/dusk pairs that share a stem:
    //   neobrix-dawn.png        / neobrix-dusk.png
    //   neobrix-blocks-dawn.png / neobrix-blocks-dusk.png
    // Returns the paired file for `mode`, or "" if `path` is not part of a pair.
    function pairedWith(path, mode) {
        const m = /^(.*)-(dawn|dusk)\.(png|jpg|jpeg|webp)$/.exec(path);
        if (!m) return "";
        const want = m[1] + "-" + mode + "." + m[3];
        return available.indexOf(want) !== -1 ? want : "";
    }

    readonly property bool onPairedWallpaper:
        current !== "" && (pairedWith(current, "dawn") !== ""
                        || pairedWith(current, "dusk") !== "" || /-(dawn|dusk)\./.test(current))

    // Follows the theme: dawn/dusk each have a matching wallpaper if present.
    function matchTheme(mode) {
        const paired = pairedWith(current, mode);
        if (paired !== "") { setWallpaper(paired); return true; }
        // No pair for the current image — fall back to the default for the mode.
        const want = "neobrix-" + mode + ".png";
        for (const p of available)
            if (p.endsWith(want)) { setWallpaper(p); return true; }
        return false;
    }

    // Keep the desktop coherent when the palette flips, but never override a
    // wallpaper the user picked deliberately: only images that are part of a
    // dawn/dusk pair are swapped.
    Connections {
        target: Theme
        function onModeChanged() {
            if (root.onPairedWallpaper)
                root.matchTheme(Theme.mode);
        }
    }

    FileView {
        id: selection
        path: root.stateFile
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            const p = text().trim();
            if (p !== "") root.current = p;
        }
        onFileChanged: reload()
    }

    // Directory listing. Cheap and rare — refreshed at startup and whenever the
    // selection changes (a new file is usually why the selection changed).
    Process {
        id: lister
        command: ["sh", "-c",
            "find \"$1\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' " +
            "-o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort",
            "sh", root.wallpaperDir]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l.trim() !== "");
                root.available = list;
                // Fall back to the first wallpaper if nothing valid is selected.
                if (root.current === "" && list.length > 0)
                    root.setWallpaper(list[0]);
            }
        }
    }

    function refresh() { lister.running = true; }

    // hyprlock cannot read the wallpaper directly — it renders a normalised copy
    // in the state dir. `neobrix-wallpaper apply` regenerates that copy, but the
    // shell changes the wallpaper by writing the state file (see matchTheme), so
    // the lock screen would keep showing the previous image. Regenerate it here.
    Process {
        id: lockBackground
        command: ["neobrix-wallpaper", "lock-background"]
    }

    onCurrentChanged: {
        refreshTimer.restart();
        lockBackgroundTimer.restart();
    }

    // Debounced: cycling wallpapers quickly should not spawn a magick per step.
    Timer {
        id: lockBackgroundTimer
        interval: 900
        onTriggered: lockBackground.running = true
    }
    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: lister.running = true
    }

    // Lets scripts and keybinds drive the wallpaper without writing files.
    IpcHandler {
        target: "wallpaper"

        function set(path: string): void { root.setWallpaper(path); }
        function next(): void { root.next(); }
        function previous(): void { root.previous(); }
        function get(): string { return root.current; }
        function list(): string { return root.available.join("\n"); }
        function refresh(): void { root.refresh(); }
    }
}
