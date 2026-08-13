pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  System metrics.
//
//  Deliberately cheap: /proc is read with FileView.reload() (no process spawn)
//  on a slow tick, and the sampler only runs while something is actually looking
//  at it (`subscribers > 0`), so a closed control center costs nothing.
//
//  Static facts (kernel, distro, hostname, package count) are read exactly once.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    // Reference counting — panels call subscribe()/unsubscribe() as they open and
    // close. The bar keeps one permanent subscription only if it shows metrics.
    property int subscribers: 0
    function subscribe() { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    readonly property bool sampling: subscribers > 0

    // ── live metrics ────────────────────────────────────────────────────────
    property real cpuUsage: 0            // 0..1
    property real memUsage: 0            // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsage: 0
    property real diskUsage: 0           // 0..1 of /
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0
    property int uptimeSeconds: 0
    property real temperature: 0         // °C, only when Hw.hasTemperature

    // ── static facts ────────────────────────────────────────────────────────
    property string hostname: ""
    property string kernel: ""
    property string distro: ""
    property string username: Quickshell.env("USER") || "user"
    property string shellName: ""
    property int packageCount: 0

    readonly property string uptimeText: {
        const s = uptimeSeconds;
        if (s <= 0) return "—";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return d + "D " + h + "H";
        if (h > 0) return h + "H " + m + "M";
        return m + "M";
    }

    function fmtGiB(v) { return v.toFixed(1) + "G"; }

    // ── sampling ────────────────────────────────────────────────────────────
    property var _prevCpu: null

    Timer {
        interval: 3000
        running: root.sampling
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            uptimeFile.reload();
            if (Hw.hasTemperature) tempFile.reload();
        }
    }

    Timer {
        interval: 60000
        running: root.sampling
        repeat: true
        triggeredOnStart: true
        onTriggered: dfProc.running = true
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const line = text().split("\n")[0];
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            if (f.length < 5) return;
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._prevCpu) {
                const dTotal = total - root._prevCpu.total;
                const dIdle = idle - root._prevCpu.idle;
                if (dTotal > 0)
                    root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
            }
            root._prevCpu = { total: total, idle: idle };
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const kv = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m) kv[m[1]] = parseInt(m[2]);   // kB
            }
            const total = kv.MemTotal || 0;
            const avail = kv.MemAvailable !== undefined ? kv.MemAvailable : (kv.MemFree || 0);
            if (total > 0) {
                root.memTotalGiB = total / 1048576;
                root.memUsedGiB = (total - avail) / 1048576;
                root.memUsage = (total - avail) / total;
            }
            const swTotal = kv.SwapTotal || 0;
            const swFree = kv.SwapFree || 0;
            root.swapUsage = swTotal > 0 ? (swTotal - swFree) / swTotal : 0;
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = Math.floor(parseFloat(text().split(" ")[0]) || 0)
    }

    FileView {
        id: tempFile
        path: Hw.temperaturePath
        printErrors: false
        onLoaded: root.temperature = (parseInt(text().trim()) || 0) / 1000
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2) return;
                const f = lines[1].trim().split(/\s+/).map(Number);
                if (f.length < 2 || !f[0]) return;
                root.diskTotalGiB = f[0] / 1073741824;
                root.diskUsedGiB = f[1] / 1073741824;
                root.diskUsage = f[1] / f[0];
            }
        }
    }

    // ── one-shot static probes ──────────────────────────────────────────────
    Process {
        command: ["sh", "-c",
            "printf '%s\\n%s\\n%s\\n%s\\n' " +
            "\"$(uname -n)\" \"$(uname -r)\" " +
            "\"$(. /etc/os-release 2>/dev/null; printf '%s' \"${PRETTY_NAME:-$NAME}\")\" " +
            "\"$(basename \"${SHELL:-sh}\")\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.hostname = (l[0] || "").trim();
                root.kernel = (l[1] || "").trim();
                root.distro = (l[2] || "").trim();
                root.shellName = (l[3] || "").trim();
            }
        }
    }

    Process {
        id: pkgProc
        command: ["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.packageCount = parseInt(text.trim()) || 0
        }
    }

    function refreshPackages() { pkgProc.running = true; }
}
