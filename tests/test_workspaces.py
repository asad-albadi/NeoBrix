"""Workspace concurrency regressions; no commands reach the live compositor."""
import contextlib
import io
import json
import multiprocessing
import os
from pathlib import Path
import queue
import runpy
import shutil
import socket
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
HELPER = REPO / "scripts/neobrix-workspaces"


def command_worker(state, args, messages, release):
    main = runpy.run_path(str(HELPER))["main"]
    ns = main.__globals__
    ns["STATE"] = Path(state)
    ns["monitors"] = lambda: []
    ns["hypr_json"] = lambda *args: []
    ns["hypr"] = lambda *args: (_ for _ in ()).throw(AssertionError("Unexpected compositor call"))
    original_load = ns["load"]
    original_flock = ns["fcntl"].flock

    def load():
        value = original_load()
        messages.put((args[0], "loaded"))
        return value

    def flock(*values):
        messages.put((args[0], "lock-attempt"))
        return original_flock(*values)

    def migration(data):
        messages.put((args[0], "migration"))
        if not release.wait(10):
            raise TimeoutError("Test did not release migration")

    ns["load"] = load
    ns["fcntl"].flock = flock
    ns["migrate_on_enable"] = migration
    with contextlib.redirect_stdout(io.StringIO()):
        main(args)
    messages.put((args[0], "done"))


class WorkspaceStateTest(unittest.TestCase):
    def test_connected_monitors_reclaim_stale_slots_and_keep_windows_local(self):
        main = runpy.run_path(str(HELPER))["main"]
        module = main.__globals__
        raw_monitors = [
            {"id": 0, "name": "eDP-1", "x": 0, "y": 0, "make": "", "model": "", "serial": "", "description": ""},
            {"id": 1, "name": "DVI-I-1", "x": 1920, "y": 0, "make": "", "model": "", "serial": "", "description": ""},
            {"id": 2, "name": "DVI-I-2", "x": 3840, "y": 0, "make": "", "model": "", "serial": "", "description": ""},
        ]
        clients = [
            {"monitor": 0, "workspace": {"id": 6}, "address": "first", "pinned": False},
            {"monitor": 1, "workspace": {"id": 1}, "address": "second", "pinned": False},
            {"monitor": 2, "workspace": {"id": 21}, "address": "third", "pinned": False},
        ]
        module["monitors"] = lambda: raw_monitors
        module["hypr_json"] = lambda kind: clients if kind == "clients" else []
        window_moves, workspace_moves = [], []
        module["move_named_window"] = lambda address, workspace: window_moves.append((address, workspace))
        module["move_workspace"] = lambda workspace, monitor: workspace_moves.append((workspace, monitor))
        data = {"enabled": True, "spaces": 5,
                "slots": {"eDP-1": 1, "DVI-I-1": 0, "DVI-I-2": 4, "old-monitor": 2}}

        changed = module["compact_connected_slots"](data)

        self.assertTrue(changed)
        self.assertEqual({name: data["slots"][name] for name in ("eDP-1", "DVI-I-1", "DVI-I-2")},
                         {"eDP-1": 0, "DVI-I-1": 1, "DVI-I-2": 2})
        self.assertEqual(window_moves, [("first", 1), ("second", 6), ("third", 11)])
        self.assertEqual(workspace_moves, [(1, "eDP-1"), (6, "DVI-I-1"), (11, "DVI-I-2")])

    def test_probe_cannot_overwrite_setting(self):
        # Pause the probe after loading settings; start another real process
        # changing enabled/spaces, then verify it waits before reading state.
        for args, field, expected in [(["enabled", "0"], "enabled", False),
                                      (["spaces", "3"], "spaces", 3)]:
            with self.subTest(setting=field), tempfile.TemporaryDirectory() as directory:
                state = Path(directory) / "workspaces.json"
                state.write_text(json.dumps({"enabled": True, "spaces": 5, "slots": {}}))
                ctx = multiprocessing.get_context("spawn")
                messages, release = ctx.Queue(), ctx.Event()
                probe = ctx.Process(target=command_worker, args=(str(state), ["show"], messages, release))
                change = ctx.Process(target=command_worker, args=(str(state), args, messages, release))
                processes = []
                try:
                    probe.start(); processes.append(probe)
                    self.assertEqual(messages.get(timeout=10), ("show", "lock-attempt"))
                    self.assertEqual(messages.get(timeout=10), ("show", "loaded"))
                    self.assertEqual(messages.get(timeout=10), ("show", "migration"))
                    change.start(); processes.append(change)
                    self.assertEqual(messages.get(timeout=10), (args[0], "lock-attempt"))
                    with self.assertRaises(queue.Empty):
                        messages.get(timeout=0.2)
                    release.set()
                    for proc in processes:
                        proc.join(timeout=10)
                        self.assertEqual(proc.exitcode, 0)
                    self.assertEqual(json.loads(state.read_text())[field], expected)
                    self.assertFalse(state.with_suffix(".tmp").exists())
                finally:
                    release.set()
                    for proc in processes:
                        if proc.is_alive():
                            proc.terminate()
                        proc.join(timeout=5)
                    messages.close()


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for the event queue test")
class WorkspaceRefreshTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neobrix-workspace-test-")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        module = root / "fixture"
        module.mkdir()
        shutil.copyfile(REPO / "quickshell/Services/WorkspaceMode.qml", module / "WorkspaceMode.qml")
        (module / "qmldir").write_text("singleton WorkspaceMode 1.0 WorkspaceMode.qml\n")
        self.shell = root / "shell.qml"
        shutil.copyfile(REPO / "tests/fixtures/workspace-shell.qml", self.shell)
        binary = root / "bin"
        binary.mkdir()
        helper = binary / "neobrix-workspaces"
        shutil.copyfile(REPO / "tests/fixtures/workspace-probe.py", helper)
        helper.chmod(0o700)
        self.server = socket.socket(socket.AF_UNIX)
        self.addCleanup(self.server.close)
        self.server.bind(str(root / "probe.socket"))
        self.server.listen()
        self.server.settimeout(10)
        self.env = {**os.environ, "QT_QPA_PLATFORM": "offscreen",
                    "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                    "NEOBRIX_TEST_SOCKET": str(root / "probe.socket")}
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        self.env.pop("QS_CONFIG_PATH", None)
        self.log = tempfile.TemporaryFile(mode="w+")
        self.addCleanup(self.log.close)
        self.process = subprocess.Popen(["qs", "-p", str(self.shell), "--no-color"],
                                        env=self.env, stdout=self.log, stderr=self.log)
        self.addCleanup(self.stop_shell)

    def stop_shell(self):
        self.process.terminate()
        self.process.wait(timeout=10)

    def ipc(self, method, *args):
        result = subprocess.run(["qs", "ipc", "-p", str(self.shell), "call", "test", method, *args],
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def accept(self, args):
        try:
            connection, _ = self.server.accept()
        except TimeoutError:
            self.log.seek(0)
            self.fail("No helper request. Quickshell log:\n" + self.log.read())
        self.addCleanup(connection.close)
        connection.settimeout(10)
        stream = connection.makefile("rb")
        self.addCleanup(stream.close)
        self.assertEqual(json.loads(stream.readline()), args)
        return connection

    def finish(self, connection, **state):
        connection.sendall(json.dumps({"enabled": True, "spaces": 5, "monitors": [], **state}).encode() + b"\n")
        # The fake helper closes after writing its result; no arbitrary sleep.
        self.assertEqual(connection.recv(1), b"")

    def test_events_during_probe_and_change_are_drained(self):
        first = self.accept(["show"])
        self.ipc("burst")
        self.assertEqual(self.ipc("pending"), "true")
        self.finish(first)
        second = self.accept(["show"])
        self.assertEqual(self.ipc("pending"), "false")

        # A setting change overlaps the second probe. All incoming events
        # must wait until both commands finish, then produce a fresh probe.
        self.ipc("disable")
        change = self.accept(["enabled", "0"])
        self.ipc("burst")
        self.finish(second)
        self.assertEqual(self.ipc("pending"), "true")
        self.server.settimeout(0.2)
        with self.assertRaises(TimeoutError):
            self.server.accept()
        self.server.settimeout(10)
        self.finish(change)
        third = self.accept(["show"])
        self.finish(third, enabled=False, spaces=3)
        # Queue one final request to confirm the disabled state is consumed
        # and completion at the end of a Process lifecycle loses no events.
        self.ipc("burst")
        fourth = self.accept(["show"])
        self.assertEqual(json.loads(self.ipc("state")), {"enabled": False, "spaces": 3})
        self.finish(fourth, enabled=False, spaces=3)
        self.server.settimeout(0.2)
        with self.assertRaises(TimeoutError):
            self.server.accept()


if __name__ == "__main__":
    unittest.main()
