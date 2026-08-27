pragma Singleton

// Display-safe AI account and activity data.  The collector owns every vendor
// format and credential; this service receives only its normalized JSON.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var providers: []
    property string updatedAt: ""
    property string error: ""
    property bool refreshing: false

    function refresh() {
        if (!refreshing) refreshProc.running = true;
    }

    function provider(id) {
        for (const item of providers)
            if (item.id === id) return item;
        return null;
    }

    function launch(id) {
        const item = provider(id);
        if (!item || !item.installed) return;
        if (id === "cursor") {
            launchProc.command = ["uwsm", "app", "--", "cursor"];
        } else {
            launchProc.command = ["uwsm", "app", "--", "kitty", "--class", "neobrix-ai", "--title", item.name, item.launchCommand];
        }
        launchProc.running = true;
    }

    function resume(id, session) {
        const item = provider(id);
        if (!item || !session) return;
        if (id === "cursor") {
            launch(id);
            return;
        }
        const args = id === "codex" ? ["resume", session.id] : ["--resume", session.id];
        resumeProc.command = ["uwsm", "app", "--", "kitty", "--class", "neobrix-ai",
                              "--title", item.name + " session", item.launchCommand].concat(args);
        resumeProc.running = true;
    }

    function openDashboard(id) {
        const item = provider(id);
        if (!item || item.dashboardUrl === "") return;
        dashboardProc.command = ["uwsm", "app", "--", "xdg-open", item.dashboardUrl];
        dashboardProc.running = true;
    }

    function consume(raw) {
        try {
            const payload = JSON.parse(raw);
            if (payload.schemaVersion !== 2 || !(payload.providers instanceof Array))
                throw new Error("unsupported data");
            root.providers = payload.providers;
            root.updatedAt = payload.updatedAt || "";
            root.error = "";
        } catch (e) {
            root.error = "AI usage data could not be read";
        }
    }

    Process {
        id: cachedProc
        command: ["neobrix-ai", "show"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.consume(text) }
        stderr: StdioCollector {}
    }

    Process {
        id: refreshProc
        command: ["neobrix-ai", "refresh"]
        running: false
        onRunningChanged: root.refreshing = running
        stdout: StdioCollector { onStreamFinished: root.consume(text) }
        stderr: StdioCollector {}
    }

    Process { id: launchProc; running: false; stderr: StdioCollector {} }
    Process { id: resumeProc; running: false; stderr: StdioCollector {} }
    Process { id: dashboardProc; running: false; stderr: StdioCollector {} }
}
