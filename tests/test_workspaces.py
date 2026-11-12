"""Workspace concurrency regressions; no commands reach the live compositor."""
import contextlib
import io
import json
import multiprocessing
import os
from pathlib import Path
import queue
import re
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
    def test_bar_focus_uses_clicked_monitor_and_repairs_foreign_workspace(self):
        # The bar is a layer surface: clicking the middle screen need not
        # change Hyprland's focused monitor. Workspace 8 may also still be
        # owned by the left screen from before per-monitor mode was enabled.
        for occupied in (False, True):
            with self.subTest(occupied=occupied), tempfile.TemporaryDirectory() as directory:
                main = runpy.run_path(str(HELPER))["main"]
                module = main.__globals__
                module["STATE"] = Path(directory) / "state.json"
                module["save"]({"enabled": True, "spaces": 5,
                                "slots": {"left": 0, "middle": 1, "right": 2}})
                module["monitors"] = lambda: [
                    {"id": 0, "name": "left", "focused": True, "activeWorkspace": {"id": 8}},
                    {"id": 1, "name": "middle", "focused": False, "activeWorkspace": {"id": 6}},
                    {"id": 2, "name": "right", "focused": False, "activeWorkspace": {"id": 11}},
                ]
                module["hypr_json"] = lambda kind: ([{"id": 8, "monitor": "left", "windows": int(occupied)}]
                    if kind == "workspaces" else
                    [{"monitor": 0, "workspace": {"id": 8}, "address": "left-app", "pinned": False}]
                    if occupied else [])
                calls = []
                module["hypr"] = lambda *args: calls.append(args)
                main(["focus", "3", "--monitor", "middle"])
                expected = []
                if occupied:
                    expected += [
                        ("eval", 'hl.dispatch(hl.dsp.window.move({ window = "address:left-app", workspace = 1, silent = true }))'),
                        ("eval", 'hl.dispatch(hl.dsp.workspace.move({ workspace = 1, monitor = "left" }))'),
                    ]
                expected += [
                    ("eval", 'hl.dispatch(hl.dsp.workspace.move({ workspace = 8, monitor = "middle" }))'),
                    ("eval", 'hl.dispatch(hl.dsp.focus({ monitor = "middle" }))'),
                    ("eval", 'hl.dispatch(hl.dsp.focus({ workspace = 8 }))'),
                ]
                self.assertEqual(calls, expected)

    def test_cycle_uses_requested_monitors_active_workspace(self):
        main = runpy.run_path(str(HELPER))["main"]
        module = main.__globals__
        with tempfile.TemporaryDirectory() as directory:
            module["STATE"] = Path(directory) / "state.json"
            module["save"]({"enabled": True, "spaces": 5, "slots": {"left": 0, "middle": 1}})
            module["monitors"] = lambda: [
                {"id": 0, "name": "left", "focused": True, "activeWorkspace": {"id": 1}},
                {"id": 1, "name": "middle", "activeWorkspace": {"id": 8}},
            ]
            calls = []
            module["hypr_json"] = lambda *args: []
            module["hypr"] = lambda *args: calls.append(args)
            main(["cycle", "1", "--monitor", "middle"])
            self.assertEqual(calls, [
                ("eval", 'hl.dispatch(hl.dsp.focus({ monitor = "middle" }))'),
                ("eval", 'hl.dispatch(hl.dsp.focus({ workspace = 9 }))'),
            ])

    def test_disconnected_bar_monitor_does_not_focus_another_screen(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        module["load"] = lambda: {"enabled": True, "spaces": 5, "slots": {"left": 0}}
        module["monitors"] = lambda: [{"id": 0, "name": "left", "focused": True}]
        calls = []
        module["hypr"] = lambda *args: calls.append(args)
        with self.assertRaisesRegex(ValueError, "not connected"):
            module["execute"](type("Args", (), {"cmd": "focus", "value": 3, "monitor": "middle"})())
        self.assertEqual(calls, [])

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

    def test_global_number_bindings_keep_all_ten_workspaces(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        module["load"] = lambda: {"enabled": False, "spaces": 3, "slots": {}}
        module["monitors"] = lambda: []
        dispatched = []
        module["hypr"] = lambda *args: dispatched.append(args)
        for command in ("focus", "move"):
            module["execute"](type("Args", (), {"cmd": command, "value": 10})())
        self.assertEqual(dispatched, [
            ("eval", "hl.dispatch(hl.dsp.focus({ workspace = 10 }))"),
            ("eval", "hl.dispatch(hl.dsp.window.move({ workspace = 10, silent = true }))"),
        ])

    def test_compaction_keeps_special_and_pinned_clients_untouched(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        module["monitors"] = lambda: [{"id": 0, "name": "DP-1"}]
        module["hypr_json"] = lambda *args: [
            {"monitor": 0, "workspace": {"id": -99}, "address": "scratch", "pinned": False},
            {"monitor": 0, "workspace": {"id": 6}, "address": "pinned", "pinned": True},
            {"monitor": 0, "workspace": {"id": 7}, "address": "ordinary", "pinned": False},
        ]
        dispatched = []
        module["hypr"] = lambda *args: dispatched.append(args)
        module["compact_connected_slots"]({"enabled": True, "spaces": 5, "slots": {"DP-1": 1}})
        self.assertEqual(dispatched, [
            ("eval", 'hl.dispatch(hl.dsp.window.move({ window = "address:ordinary", workspace = 2, silent = true }))'),
            ("eval", 'hl.dispatch(hl.dsp.workspace.move({ workspace = 2, monitor = "DP-1" }))'),
        ])

    def test_duplicate_display_metadata_gets_private_stable_ranges(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        monitors = [dict(id=i, name=name, make="Acme", model="27Q", serial="",
                         description="Acme 27Q") for i, name in enumerate(("DP-1", "DP-2"))]
        module["monitors"] = lambda: monitors
        # An existing assignment made with only the first panel attached must
        # remain its assignment when its indistinguishable sibling is added.
        data = {"enabled": True, "spaces": 5, "slots": {"Acme|27Q||Acme 27Q": 0}}
        assigned = module["mapping"](data)
        self.assertEqual([(m["name"], m["slot"]) for m in assigned], [("DP-1", 0), ("DP-2", 1)])
        monitors.reverse()
        self.assertEqual({m["name"]: m["slot"] for m in module["mapping"](data)}, {"DP-1": 0, "DP-2": 1})
        monitors[:] = [m for m in monitors if m["name"] == "DP-2"]
        self.assertEqual(module["mapping"](data)[0]["slot"], 1)

    def test_duplicate_serial_hotplug_keeps_existing_connectors_local_number(self):
        for new_on_left in (False, True):
            with self.subTest(new_on_left=new_on_left):
                module = runpy.run_path(str(HELPER))["main"].__globals__
                existing = dict(id=0, name="DP-2", make="Acme", model="27Q", serial="0",
                                description="Acme 27Q", x=0)
                newcomer = dict(existing, id=1, name="DP-1", x=1920)
                monitors = [existing]
                module["monitors"] = lambda: monitors
                data = {"enabled": True, "spaces": 5, "slots": {"Acme|27Q|0|Acme 27Q": 0}}
                self.assertEqual(module["mapping"](data)[0]["slot"], 0)
                if new_on_left:
                    newcomer["x"] = -1920
                monitors[:] = [newcomer, existing] if new_on_left else [existing, newcomer]
                clients = [{"monitor": 0, "workspace": {"id": 2}, "address": "existing", "pinned": False}]
                module["hypr_json"] = lambda *args: clients
                dispatched = []
                def compositor(*args):
                    dispatched.append(args)
                    if "hl.dsp.window.move(" in args[1]:
                        clients[0]["workspace"]["id"] = int(re.search(r"workspace = (\d+)", args[1])[1])
                module["hypr"] = compositor
                module["compact_connected_slots"](data)
                module["migrate_on_enable"](data)
                if new_on_left:
                    self.assertEqual(dispatched, [
                        ("eval", 'hl.dispatch(hl.dsp.window.move({ window = "address:existing", workspace = 7, silent = true }))'),
                        ("eval", 'hl.dispatch(hl.dsp.workspace.move({ workspace = 7, monitor = "DP-2" }))'),
                    ])
                else:
                    self.assertEqual(dispatched, [], "Hotplug must retain local workspace 2")
                slots = {m["name"]: m["slot"] for m in module["mapping"](data)}
                self.assertEqual(slots, {"DP-1": 0 if new_on_left else 1,
                                         "DP-2": 1 if new_on_left else 0})

    def test_unique_serial_keeps_its_slot_across_dock_connectors(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        monitor = dict(id=0, name="DP-2", make="Acme", model="27Q", serial="unique",
                       description="Acme 27Q")
        module["monitors"] = lambda: [monitor]
        data = {"enabled": True, "spaces": 5, "slots": {"Acme|27Q|unique|Acme 27Q": 2}}
        self.assertEqual(module["mapping"](data)[0]["slot"], 2)
        monitor["name"] = "DP-5"
        self.assertEqual(module["mapping"](data)[0]["slot"], 2)
        self.assertEqual(data["slots"], {"Acme|27Q|unique|Acme 27Q": 2})

    def test_legacy_duplicate_serial_assignment_uses_physical_order(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        monitors = [dict(id=i, name=name, make="Acme", model="27Q", serial="0",
                         description="Acme 27Q") for i, name in enumerate(("DP-2", "DP-1"))]
        module["monitors"] = lambda: monitors
        data = {"enabled": True, "spaces": 5, "slots": {"Acme|27Q|0|Acme 27Q": 0}}
        self.assertEqual([(m["name"], m["slot"]) for m in module["mapping"](data)],
                         [("DP-2", 0), ("DP-1", 1)])

    def test_changing_space_count_keeps_pinned_and_special_clients(self):
        module = runpy.run_path(str(HELPER))["main"].__globals__
        module["monitors"] = lambda: [{"id": 0, "name": "DP-1"}]
        module["hypr_json"] = lambda *args: [
            {"monitor": 0, "workspace": {"id": -99}, "address": "scratch", "pinned": False},
            {"monitor": 0, "workspace": {"id": 5}, "address": "pinned", "pinned": True},
            {"monitor": 0, "workspace": {"id": 5}, "address": "ordinary", "pinned": False},
        ]
        dispatched = []
        module["hypr"] = lambda *args: dispatched.append(args)
        module["migrate_spaces"]({"enabled": True, "spaces": 5, "slots": {"DP-1": 0}}, 5, 3)
        self.assertEqual(dispatched, [
            ("eval", 'hl.dispatch(hl.dsp.window.move({ window = "address:ordinary", workspace = 1, silent = true }))'),
            ("eval", 'hl.dispatch(hl.dsp.workspace.move({ workspace = 1, monitor = "DP-1" }))'),
        ])

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

    def test_bar_actions_forward_their_own_monitor(self):
        self.finish(self.accept(["show"]))
        self.ipc("focusMiddle")
        self.finish(self.accept(["focus", "3", "--monitor", "DVI-I-1"]))
        self.ipc("cycleMiddle")
        self.finish(self.accept(["cycle", "1", "--monitor", "DVI-I-1"]))


if __name__ == "__main__":
    unittest.main()
