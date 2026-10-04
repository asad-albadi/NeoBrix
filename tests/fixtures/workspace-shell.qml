import Quickshell
import Quickshell.Io
import "./fixture" as Fixture

ShellRoot {
    readonly property bool enabled: Fixture.WorkspaceMode.enabled
    IpcHandler {
        target: "test"
        function burst(): void {
            for (let i = 0; i < 8; ++i) Fixture.WorkspaceMode.refresh()
        }
        function disable(): void { Fixture.WorkspaceMode.setEnabled(false) }
        function pending(): string { return String(Fixture.WorkspaceMode.refreshPending) }
        function state(): string {
            return JSON.stringify({enabled: Fixture.WorkspaceMode.enabled, spaces: Fixture.WorkspaceMode.spaces})
        }
    }
}
