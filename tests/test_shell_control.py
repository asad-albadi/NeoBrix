"""Reload must preserve the Quickshell process and report real CLI failures."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]


class ShellControlTest(unittest.TestCase):
    def test_cli_failure_is_reported_without_unbound_variable(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp)
            for name in ("hyprctl", "systemctl"):
                path = binary / name
                path.write_text("#!/bin/sh\nexit 1\n")
                path.chmod(0o700)
            env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"]}
            for command in ("reload", "restart"):
                with self.subTest(command=command):
                    result = subprocess.run([str(REPO / "scripts/neobrix"), command], env=env,
                                            capture_output=True, text=True, timeout=10)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("failed", result.stdout)
                    self.assertNotIn("unbound variable", result.stderr)

    @unittest.skipUnless(shutil.which("qs"), "Quickshell is required for reload integration")
    def test_service_reload_keeps_the_same_shell_process(self):
        with tempfile.TemporaryDirectory(prefix="neobrix-reload-") as tmp:
            root = Path(tmp)
            module = root / "Services"
            module.mkdir()
            control = REPO / "quickshell/Services/ShellControl.qml"
            if control.exists():
                shutil.copyfile(control, module / "ShellControl.qml")
            else:
                (module / "ShellControl.qml").write_text(
                    "pragma Singleton\nimport QtQuick\nQtObject { readonly property bool ready: true }\n")
            (module / "qmldir").write_text("singleton ShellControl 1.0 ShellControl.qml\n")
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "Services" as Services
ShellRoot {
    readonly property bool ready: Services.ShellControl.ready
    Component.onCompleted: console.log("SHELL_CONTROL_READY")
}''')
            runtime = root / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "XDG_RUNTIME_DIR": str(runtime),
                   "XDG_STATE_HOME": str(root / "state"), "XDG_CONFIG_HOME": str(root / "config"),
                   "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(root / "no-bus")}
            for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "QS_CONFIG_PATH"):
                env.pop(key, None)
            log = root / "shell.log"
            with log.open("w") as output:
                process = subprocess.Popen(["qs", "-p", str(root), "--no-color"], env=env,
                                           stdout=output, stderr=output)
                try:
                    def wait_ready(count):
                        deadline = time.monotonic() + 10
                        while time.monotonic() < deadline:
                            text = log.read_text()
                            if text.count("SHELL_CONTROL_READY") >= count:
                                return
                            if process.poll() is not None:
                                self.fail("Shell exited during reload:\n" + text)
                            time.sleep(0.02)
                        self.fail("Shell did not reload:\n" + log.read_text())
                    wait_ready(1)
                    line = next(line for line in (REPO / "systemd/neobrix-shell.service").read_text().splitlines()
                                if line.startswith("ExecReload="))
                    args = shlex.split(line.split("=", 1)[1].replace("$MAINPID", str(process.pid)))
                    if "-c" in args:
                        position = args.index("-c")
                        args[position:position + 2] = ["-p", str(root)]
                    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=10)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    wait_ready(2)
                    self.assertIsNone(process.poll())
                finally:
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
