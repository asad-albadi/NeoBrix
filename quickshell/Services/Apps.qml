pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Application index for the launcher.
//
//  Backed by Quickshell's DesktopEntries (which already parses and watches the
//  XDG application directories), plus a small fuzzy scorer and a persisted usage
//  count so frequently launched apps float to the top of an empty query.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // id -> launch count
    property var usage: ({})

    readonly property var all: {
        const out = [];
        if (!DesktopEntries.applications) return out;
        for (const e of DesktopEntries.applications.values)
            if (!e.noDisplay) out.push(e);
        return out;
    }

    FileView {
        id: usageFile
        path: Quickshell.statePath("app-usage.json")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed && typeof parsed === "object") root.usage = parsed;
            } catch (e) {
                // Corrupt or absent state is not worth complaining about.
            }
        }
    }

    // Whether the session is managed by uwsm, which can put each application in
    // its own systemd scope.
    readonly property bool underUwsm: {
        const v = Quickshell.env("UWSM_FINALIZE_VARNAMES");
        return v !== null && v !== "";
    }

    function launch(entry) {
        if (!entry) return;

        const u = Object.assign({}, root.usage);
        u[entry.id] = (u[entry.id] || 0) + 1;
        root.usage = u;
        usageFile.setText(JSON.stringify(u));

        // DesktopEntry.execute() forks from the shell, so the application ends up
        // inside neobrix-shell.service's cgroup and dies with it — restarting the
        // shell would close the user's windows. Under uwsm, hand the desktop id to
        // `uwsm app` instead so each application gets its own systemd scope, which
        // is also what the Hyprland exec binds do.
        if (root.underUwsm) {
            const id = entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
            Quickshell.execDetached(["uwsm", "app", "--", id]);
        } else {
            entry.execute();
        }
    }

    // Subsequence match with position/word-boundary weighting. Returns a score,
    // or -1 for no match.
    function score(entry, query) {
        if (query === "") return (root.usage[entry.id] || 0) * 10 + 1;

        const q = query.toLowerCase();
        const name = (entry.name || "").toLowerCase();
        const generic = (entry.genericName || "").toLowerCase();
        const comment = (entry.comment || "").toLowerCase();
        const exec = (entry.execString || "").toLowerCase();
        const keywords = (entry.keywords || []).join(" ").toLowerCase();

        let best = -1;

        // Exact / prefix / substring on the visible name dominate.
        if (name === q) best = 1000;
        else if (name.startsWith(q)) best = 800 - name.length;
        else if (name.indexOf(q) !== -1) best = 600 - name.indexOf(q);
        else {
            const sub = subsequenceScore(name, q);
            if (sub >= 0) best = 400 + sub;
        }

        if (best < 0 && generic.indexOf(q) !== -1) best = 300;
        if (best < 0 && keywords.indexOf(q) !== -1) best = 250;
        if (best < 0 && exec.indexOf(q) !== -1) best = 200;
        if (best < 0 && comment.indexOf(q) !== -1) best = 100;

        if (best < 0) return -1;
        return best + Math.min(50, (root.usage[entry.id] || 0) * 5);
    }

    function subsequenceScore(haystack, needle) {
        let hi = 0, score = 0, prevMatch = -2;
        for (let ni = 0; ni < needle.length; ni++) {
            const c = needle[ni];
            let found = -1;
            while (hi < haystack.length) {
                if (haystack[hi] === c) { found = hi; hi++; break; }
                hi++;
            }
            if (found === -1) return -1;
            if (found === prevMatch + 1) score += 8;              // contiguous
            if (found === 0 || haystack[found - 1] === " ") score += 6;  // word start
            prevMatch = found;
        }
        return score;
    }

    function search(query) {
        const q = (query || "").trim();
        const scored = [];
        for (const e of root.all) {
            const s = root.score(e, q.toLowerCase());
            if (s >= 0) scored.push({ entry: e, s: s });
        }
        scored.sort((a, b) => b.s - a.s || a.entry.name.localeCompare(b.entry.name));
        return scored.map(x => x.entry);
    }
}
