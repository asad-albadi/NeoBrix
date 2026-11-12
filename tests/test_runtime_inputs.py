"""Exercise real shell controls with synthetic services in an offscreen window."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for input tests")
class RuntimeInputTest(unittest.TestCase):
    def run_input_case(self, case):
        with tempfile.TemporaryDirectory(prefix="neobrix-runtime-input-") as directory:
            root = Path(directory)
            for name in ("Components", "Theme"):
                shutil.copytree(REPO / "quickshell" / name, root / name)
            # Offscreen Qt has no layer-shell PanelWindow backend. Substitute
            # only its platform window boundary; keep the production visual
            # tree and keyboard/pointer handlers under test unchanged.
            popup = root / "Components/BrixPopup.qml"
            source = popup.read_text().replace("PanelWindow {", "FloatingWindow {\n    implicitWidth: 800\n    implicitHeight: 700", 1)
            source = "\n".join(line for line in source.splitlines()
                               if not line.strip().startswith(("anchors { top: true; bottom: true; left: true; right: true }",
                                                               "exclusionMode:", "WlrLayershell.", "mask: open ?")))
            popup.write_text(source)
            for name, filename in (("Panels", "ClipboardPanel.qml"),
                                   ("Notifications", "NotificationItem.qml")):
                (root / name).mkdir()
                shutil.copyfile(REPO / "quickshell" / name / filename, root / name / filename)
            services = root / "Services"
            services.mkdir()
            (services / "qmldir").write_text("singleton Panels 1.0 Panels.qml\nsingleton Clip 1.0 Clip.qml\n")
            (services / "Panels.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string current: ""
    function isOpen(name) { return current === name }
    function open(name) { current = name }
    function toggle(name) { current = current === name ? "" : name }
    function close() { current = "" }
}''')
            (services / "Clip.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var entries: [{id: "synthetic", preview: "Synthetic clipboard entry", isImage: false}]
    property bool loading: false
    property int copied: 0
    property int removed: 0
    function refresh() {}
    function copy(entry) { copied++ }
    function remove(entry) { removed++; entries = [] }
    function wipe() { entries = [] }
}''')
            shutil.copyfile(REPO / "tests/fixtures/runtime-input-shell.qml", root / "shell.qml")
            binary = root / "bin"
            binary.mkdir()
            # Theme and notification link commands cannot reach the real session.
            for name in ("neobrix-theme", "xdg-open"):
                command = binary / name
                command.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$NEOBRIX_INPUT_COMMAND_LOG\"\n")
                if name == "neobrix-theme":
                    command.write_text("#!/bin/sh\nexit 0\n")
                command.chmod(0o700)
            runtime = root / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                   "XDG_RUNTIME_DIR": str(runtime), "XDG_CONFIG_HOME": str(root / "config"),
                   "XDG_STATE_HOME": str(root / "state"), "XDG_CACHE_HOME": str(root / "cache"),
                   "XDG_DATA_HOME": str(root / "data"),
                   "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(root / "no-session-bus"),
                   "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                   "NEOBRIX_INPUT_CASE": case, "NEOBRIX_INPUT_COMMAND_LOG": str(root / "commands")}
            for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "QS_CONFIG_PATH"):
                env.pop(key, None)
            process = subprocess.run(["qs", "-p", str(root / "shell.qml"), "--no-color"],
                                     env=env, capture_output=True, text=True, timeout=15)
            output = process.stdout + process.stderr
            self.assertEqual(process.returncode, 0, output)
            self.assertIn("RUNTIME_INPUT_PASS " + case, output, output)
            self.assertNotIn("RUNTIME_INPUT_FAIL", output, output)
            if case == "notification_link":
                self.assertEqual((root / "commands").read_text().strip(), "https://example.org/synthetic")

    def test_clipboard_delete_does_not_copy_or_close(self):
        self.run_input_case("clipboard_delete")

    def test_clipboard_row_still_copies_and_closes(self):
        self.run_input_case("clipboard_copy")

    def test_notification_body_left_click_invokes_default(self):
        self.run_input_case("notification_left")

    def test_notification_middle_click_only_dismisses(self):
        self.run_input_case("notification_middle")

    def test_notification_action_button_keeps_its_action(self):
        self.run_input_case("notification_action")

    def test_notification_link_keeps_its_action(self):
        self.run_input_case("notification_link")

    def test_escape_bubbles_from_focused_input(self):
        self.run_input_case("escape")

    def test_child_escape_handler_gets_first_chance(self):
        self.run_input_case("escape_child")


if __name__ == "__main__":
    unittest.main()
