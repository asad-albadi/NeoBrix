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
    // GECOS, first comma-separated field. Empty on an account where nobody set
    // one, which is why anything showing it falls back to the username.
    property string fullName: ""
    readonly property string displayName: root.fullName !== "" ? root.fullName : root.username
    property string shellName: ""
    property int packageCount: 0
    // -Qqm is "foreign" — installed but in no sync database. That is the AUR in
    // all but the rare case of something built locally by hand, and AUR is the
    // word a user recognises.
    property int packageNative: 0
    property int packageForeign: 0
    property int packageFlatpak: 0

    // ── hardware ────────────────────────────────────────────────────────────
    property string cpuModel: ""
    property int cpuCores: 0
    property int cpuThreads: 0
    property real cpuBaseGHz: 0
    property real cpuMaxGHz: 0
    property string gpuModel: ""
    property int gpuMemoryMiB: 0
    property string machineModel: ""

    // ── network throughput, bytes/s ─────────────────────────────────────────
    property real netRxRate: 0
    property real netTxRate: 0

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

    function fmtRate(bps) {
        if (bps < 1024) return Math.round(bps) + " B/s";
        if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " K/s";
        return (bps / 1048576).toFixed(bps < 10485760 ? 1 : 0) + " M/s";
    }

    // Vendors write their marketing into the model string: registered-mark
    // glyphs, the word CPU, and a clock speed that is nominal anyway and reads
    // as current when it is not. What is left is the part that identifies the
    // chip.
    function tidyCpu(s) {
        return s.replace(/\((R|TM|r|tm)\)/g, "")
                .replace(/\bCPU\b/g, "")
                .replace(/\bProcessor\b/gi, "")
                .replace(/\s+with\s+.*$/i, "")
                .replace(/@.*$/, "")
                .replace(/\s{2,}/g, " ")
                .trim();
    }

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
            netFile.reload();
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

    property var _prevNet: null

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*([\w.-]+):\s*(.*)$/);
                if (!m) continue;
                // Loopback is not traffic. Bridges, veths, container and VPN
                // interfaces carry bytes that also cross a real interface, so
                // counting them reports two to four times the actual rate.
                if (/^(lo|docker|br-|veth|virbr|zt|tun|tap|wg)/.test(m[1])) continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                rx += f[0] || 0;
                tx += f[8] || 0;
            }
            const now = Date.now();
            if (root._prevNet) {
                const dt = (now - root._prevNet.t) / 1000;
                // Counters reset when an interface goes away, which would
                // otherwise read as one enormous spike.
                if (dt > 0 && rx >= root._prevNet.rx && tx >= root._prevNet.tx) {
                    root.netRxRate = (rx - root._prevNet.rx) / dt;
                    root.netTxRate = (tx - root._prevNet.tx) / dt;
                }
            }
            root._prevNet = { rx: rx, tx: tx, t: now };
        }
    }

    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        onLoaded: {
            let model = "", threads = 0, coresField = 0, phys = "0";
            // Unique physical-id:core-id pairs, so a two-socket machine counts
            // both packages rather than reporting one of them. The `cpu cores`
            // field is the fallback for kernels and architectures that do not
            // publish the topology.
            const pairs = {};
            for (const line of text().split("\n")) {
                if (!model) {
                    const m = line.match(/^model name\s*:\s*(.+)$/);
                    if (m) model = m[1];
                }
                if (/^processor\s*:/.test(line)) threads++;
                const pm = line.match(/^physical id\s*:\s*(\d+)/);
                if (pm) phys = pm[1];
                const cm = line.match(/^core id\s*:\s*(\d+)/);
                if (cm) pairs[phys + ":" + cm[1]] = true;
                const cf = line.match(/^cpu cores\s*:\s*(\d+)/);
                if (cf && !coresField) coresField = parseInt(cf[1]);
            }
            const topology = Object.keys(pairs).length;
            root.cpuThreads = threads;
            root.cpuCores = topology > 0 ? topology : (coresField > 0 ? coresField : threads);
            root.cpuModel = root.tidyCpu(model);
        }
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
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' " +
            "\"$(uname -n)\" \"$(uname -r)\" " +
            "\"$(. /etc/os-release 2>/dev/null; printf '%s' \"${PRETTY_NAME:-$NAME}\")\" " +
            "\"$(basename \"${SHELL:-sh}\")\" " +
            // id -un rather than $USER: the shell running this is not a login
            // shell and does not have to have it set.
            "\"$(getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1)\" " +
            // kHz. base_frequency is Intel's, absent elsewhere; the max is what
            // every cpufreq driver publishes.
            "\"$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency 2>/dev/null)\" " +
            "\"$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.hostname = (l[0] || "").trim();
                root.kernel = (l[1] || "").trim();
                root.distro = (l[2] || "").trim();
                root.shellName = (l[3] || "").trim();
                root.fullName = (l[4] || "").trim();
                root.cpuBaseGHz = (parseInt((l[5] || "").trim()) || 0) / 1000000;
                root.cpuMaxGHz = (parseInt((l[6] || "").trim()) || 0) / 1000000;
            }
        }
    }

    // GPU and machine model.
    //
    // A laptop with switchable graphics has two display devices and both report
    // as "VGA compatible controller", so the class does not separate them —
    // taking the first match named the integrated one while a discrete GPU sat
    // beside it. boot_vga does separate them: it is 1 on the device the firmware
    // brought up, which is the integrated one. So the card that is *not* the
    // boot device wins, and the boot device is the fallback for machines with
    // only one.
    //
    // lspci gives a name a person recognises but is not a dependency of this
    // project; the sysfs driver is the fallback, so a machine without pciutils
    // reads "nvidia" rather than nothing. simpledrm and vkms are skipped —
    // neither is hardware anyone means by "GPU".
    //
    // One caveat worth knowing: nvidia-smi is the only way to ask an NVIDIA card
    // how much memory it has, and calling it wakes a card that runtime power
    // management has suspended. This runs once, at shell start, and only when
    // the chosen card is on the nvidia driver.
    Process {
        command: ["sh", "-c",
            "pa=; pv=; pd=; fa=; fv=; fd=;" +
            "for d in /sys/class/drm/card*; do " +
              "case ${d##*/} in *-*) continue ;; esac;" +
              "[ -e $d/device ] || continue;" +
              "a=$(basename $(readlink -f $d/device)); a=${a#0000:};" +
              "v=$(basename $(readlink -f $d/device/driver 2>/dev/null) 2>/dev/null);" +
              "case $v in simpledrm|vkms) continue ;; esac;" +
              "[ x$v = x ] && continue;" +
              "[ x$fa = x ] && { fa=$a; fv=$v; fd=$d; };" +
              "[ x$pa = x ] && [ $(cat $d/device/boot_vga 2>/dev/null || echo 0) = 0 ] " +
                "&& { pa=$a; pv=$v; pd=$d; };" +
            "done;" +
            "[ x$pa = x ] && { pa=$fa; pv=$fv; pd=$fd; };" +
            // The PCI address contains colons, so it cannot be packed into one
            // variable with a colon separator — that truncated 01:00.0 to 01
            // and looked up the wrong device.
            "n=$(lspci -mms $pa 2>/dev/null | tr '\\042' '\\n' | sed -n 6p);" +
            "[ x\"$n\" = x ] && n=$pv;" +
            // amdgpu states its VRAM in sysfs, which costs nothing to read.
            // Intel integrated graphics have no dedicated memory to report at
            // all. NVIDIA reports it only through nvidia-smi, which is deferred
            // — see requestGpuMemory() below for why.
            "m=$(cat $pd/device/mem_info_vram_total 2>/dev/null);" +
            "if [ x$m != x ]; then m=$((m / 1048576)); else m=0; fi;" +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n' \"$n\" \"$m\" " +
                "\"$(cat /sys/class/dmi/id/product_name 2>/dev/null)\" \"$pv\" \"$pa\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                let gpu = (l[0] || "").trim();
                // "GA107M [GeForce RTX 3050 Mobile]" — the bracketed part is the
                // name the machine is sold under; the rest is the die.
                const br = gpu.match(/\[([^\]]+)\]/);
                if (br) gpu = br[1].trim();
                root.gpuModel = gpu;
                root.gpuMemoryMiB = parseInt((l[1] || "").trim()) || 0;

                // DMI is free text and often repeats the board code
                // ("FX516PC_FX516PC"), or is a placeholder nobody filled in.
                let model = (l[2] || "").trim().split("_")[0].trim();
                if (/^(to be filled|system product|default string|none|n\/a)/i.test(model))
                    model = "";
                root.machineModel = model;

                root.gpuDriver = (l[3] || "").trim();
                root.gpuAddress = (l[4] || "").trim();
            }
        }
    }

    // NVIDIA reports VRAM only through nvidia-smi, and calling that wakes a
    // card that runtime power management has suspended: measured on an RTX 3050
    // Mobile, one call held the card awake for 22 seconds at 11.5 W — about
    // 70 mWh — against roughly nothing asleep. That is a poor price for a
    // number shown on one row of one card, so it is asked for only when
    // something is about to display it, and only once per shell.
    property string gpuDriver: ""
    property string gpuAddress: ""
    property bool gpuMemoryRequested: false

    function requestGpuMemory(): void {
        if (root.gpuMemoryRequested || root.gpuMemoryMiB > 0) return;
        if (root.gpuDriver !== "nvidia" || root.gpuAddress === "") return;
        root.gpuMemoryRequested = true;
        gpuMemoryProbe.running = true;
    }

    Process {
        id: gpuMemoryProbe
        command: ["sh", "-c",
            "command -v nvidia-smi >/dev/null 2>&1 || exit 0;" +
            "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits " +
                "-i 0000:" + root.gpuAddress + " 2>/dev/null | head -1 | tr -dc 0-9"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const m = parseInt(text.trim()) || 0;
                if (m > 0) root.gpuMemoryMiB = m;
            }
        }
    }

    Process {
        id: pkgProc
        command: ["sh", "-c",
            "pacman -Qq 2>/dev/null | wc -l;" +
            "pacman -Qqn 2>/dev/null | wc -l;" +
            "pacman -Qqm 2>/dev/null | wc -l;" +
            "if command -v flatpak >/dev/null 2>&1; then " +
              "flatpak list --app 2>/dev/null | wc -l; else echo 0; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").map(v => parseInt(v.trim()) || 0);
                root.packageCount = l[0] || 0;
                root.packageNative = l[1] || 0;
                root.packageForeign = l[2] || 0;
                root.packageFlatpak = l[3] || 0;
            }
        }
    }

    function refreshPackages() { pkgProc.running = true; }
}
