import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]
MONITORS = REPO / "scripts/neobrix-monitors"
LUA = shutil.which("lua")


class MonitorSecurityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neobrix-monitor-security-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.state = self.root / "state"
        self.fixture = self.root / "monitors.json"
        self.log = self.root / "eval.jsonl"
        self.generated = self.root / "generated.lua"
        self.monitor = {
            "id": 0, "name": "eDP-1", "description": "Test panel",
            "width": 1920, "height": 1080, "refreshRate": 60,
            "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
            "disabled": False, "mirrorOf": "none", "focused": True,
            "availableModes": ["1920x1080@60.00Hz"],
        }
        self.write_monitors()
        stub = self.bin / "hyprctl"
        stub.write_text(
            "#!/usr/bin/env python3\n"
            "import json,os,pathlib,sys\n"
            "if sys.argv[1:3] == ['-j','monitors']:\n"
            "    print(pathlib.Path(os.environ['MONITOR_FIXTURE']).read_text())\n"
            "elif sys.argv[1] == 'eval':\n"
            "    with open(os.environ['MONITOR_EVAL_LOG'],'a') as f: f.write(json.dumps(sys.argv[2])+'\\n')\n"
            "    print('ok')\n"
            "else: sys.exit(2)\n"
        )
        stub.chmod(0o755)
        self.env = os.environ | {
            "HOME": str(self.root), "PATH": f"{self.bin}:{os.environ['PATH']}",
            "XDG_STATE_HOME": str(self.state), "XDG_RUNTIME_DIR": str(self.runtime),
            "MONITOR_FIXTURE": str(self.fixture), "MONITOR_EVAL_LOG": str(self.log),
            "NB_GENERATED": str(self.generated), "TMPDIR": str(self.root),
        }

    def write_monitors(self):
        self.fixture.write_text(json.dumps([self.monitor]))

    def run_monitors(self, *args, env=None):
        return subprocess.run([str(MONITORS), *args], env=env or self.env,
                              capture_output=True, text=True, timeout=10)

    def saved_profile(self):
        result = self.run_monitors("save", "Desk")
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.state / "neobrix/monitors.json"
        state = json.loads(path.read_text())
        return path, state, next(iter(state["profiles"].values()))

    def evals(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_lua_values(self, source, values, generated=False):
        # The real Lua parser evaluates generated code with an inert API. Any
        # interpolation bug either raises an error or changes these exact bytes.
        if not LUA:
            self.skipTest("Lua interpreter unavailable")
        prelude = '''
local function hex(s)
    return (s:gsub('.', function(c) return string.format('%02x', string.byte(c)) end))
end
hl = { monitor = function(o)
    for _, k in ipairs({'output', 'mode', 'position', 'mirror'}) do
        if o[k] ~= nil then print(k .. '=' .. hex(o[k])) end
    end
end }
'''
        code = prelude + ("local configure = (function()\n" + source + "\nend)(); configure({})"
                          if generated else source)
        result = subprocess.run([LUA, "-"], input=code, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = result.stdout.splitlines()
        for key, value in values.items():
            self.assertIn(key + "=" + value.encode().hex(), actual)

    @unittest.skipUnless(LUA, "Lua interpreter unavailable")
    def test_apply_preserves_strings_as_data(self):
        self.monitor["name"] = 'virtual-"panel\\one\n\t\x01'
        self.write_monitors()
        path, state, profile = self.saved_profile()
        output = profile["outputs"][self.monitor["name"]]
        output["mode"] = 'preferred", injected=(function() error("INJECTED") end)(), ignored="'
        output["position"] = 'auto\\center\n\r\x00'
        output["mirror"] = 'other"screen\\end'
        path.write_text(json.dumps(state))
        result = self.run_monitors("apply", "Desk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.evals()), 1)
        self.assert_lua_values(self.evals()[0], {"output": self.monitor["name"],
                                                **{key: output[key] for key in ("mode", "position", "mirror")}})

    @unittest.skipUnless(LUA, "Lua interpreter unavailable")
    def test_generated_startup_keeps_profile_names_in_comments(self):
        path, state, profile = self.saved_profile()
        profile["name"] = 'Desk\nerror("PROFILE_NAME_EXECUTED")\r--'
        output = profile["outputs"]["eDP-1"]
        output["mirror"] = 'screen"two\\part\nnext'
        path.write_text(json.dumps(state))
        result = self.run_monitors("generate")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_lua_values(self.generated.read_text(), {"mirror": output["mirror"]}, generated=True)

    def test_invalid_scalar_values_are_rejected_before_dispatch(self):
        path, state, profile = self.saved_profile()
        original = dict(profile["outputs"]["eDP-1"])
        cases = [("scale", "os.execute('false')"), ("scale", float("nan")),
                 ("scale", float("inf")), ("scale", 0), ("scale", -1),
                 ("scale", True), ("transform", 0.5), ("transform", False),
                 ("vrr", {}), ("mode", []), ("disabled", "false")]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                self.log.unlink(missing_ok=True)
                profile["outputs"]["eDP-1"] = original | {field: value}
                path.write_text(json.dumps(state))
                result = self.run_monitors("apply", "Desk")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.evals(), [])

    @unittest.skipUnless(LUA, "Lua interpreter unavailable")
    def test_empty_mirror_keeps_the_no_mirroring_default(self):
        path, state, profile = self.saved_profile()
        profile["outputs"]["eDP-1"]["mirror"] = ""
        path.write_text(json.dumps(state))
        result = self.run_monitors("apply", "Desk")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_lua_values(self.evals()[0], {"mirror": "none"})

    @unittest.skipUnless(LUA, "Lua interpreter unavailable")
    def test_detached_revert_uses_the_same_safe_string_encoding(self):
        self.monitor["name"] = 'virtual-"panel\\one\nnext'
        self.monitor["mirrorOf"] = 'other"panel\\two'
        self.write_monitors()
        result = self.run_monitors("--revert-after", "1", "set", self.monitor["name"], "vrr=1")
        self.assertEqual(result.returncode, 0, result.stderr)
        deadline = time.monotonic() + 5
        while len(self.evals()) < 2 and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual(len(self.evals()), 2)
        self.assert_lua_values(self.evals()[1], {"output": self.monitor["name"],
                                                "mirror": self.monitor["mirrorOf"]})

    def test_newer_change_keeps_its_snapshot_until_its_own_deadline(self):
        first = self.run_monitors("--revert-after", "1", "set", "eDP-1", "vrr=1")
        self.assertEqual(first.returncode, 0, first.stderr)
        pending = self.runtime / "neobrix-monitors-pending.json"
        baseline = json.loads(pending.read_text())
        second = self.run_monitors("--revert-after", "2", "set", "eDP-1", "vrr=0")
        self.assertEqual(second.returncode, 0, second.stderr)
        latest = json.loads(pending.read_text())
        self.assertNotEqual(baseline["id"], latest["id"])
        self.assertEqual(baseline["outputs"], latest["outputs"])
        time.sleep(1.1)
        self.assertTrue(pending.is_file(), "the older watcher removed the newer snapshot")
        self.assertEqual(len(self.evals()), 2)
        deadline = time.monotonic() + 5
        while len(self.evals()) < 3 and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual(len(self.evals()), 3)
        self.assertFalse(pending.exists())

    def test_monitor_pending_state_uses_private_fallback(self):
        # An unsafe XDG directory must never become the shared state location.
        unsafe = self.root / "shared"
        unsafe.mkdir(mode=0o777)
        unsafe.chmod(0o777)
        env = self.env | {"XDG_RUNTIME_DIR": str(unsafe)}
        result = self.run_monitors("--revert-after", "1", "set", "eDP-1", "vrr=1", env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((unsafe / "neobrix-monitors-pending.json").exists())
        env.pop("XDG_RUNTIME_DIR")
        result = self.run_monitors("--revert-after", "1", "set", "eDP-1", "vrr=1", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        private = self.root / f"neobrix-runtime-{os.getuid()}"
        self.assertTrue((private / "neobrix-monitors-pending.json").is_file())
        self.assertEqual(private.stat().st_mode & 0o777, 0o700)
        self.assertFalse((unsafe / "neobrix-monitors-pending.json").exists())
        self.run_monitors("confirm", env=env)

    def test_power_policy_uses_private_fallback(self):
        unsafe = self.root / "shared"
        unsafe.mkdir(mode=0o777)
        unsafe.chmod(0o777)
        for name, source in {
            "powerprofilesctl": '#!/bin/sh\ncase "$1" in get) echo balanced;; list) printf "balanced:\\npower-saver:\\n";; set) exit 0;; esac\n',
            "neobrix-monitors": '#!/bin/sh\nexit 0\n',
        }.items():
            path = self.bin / name
            path.write_text(source)
            path.chmod(0o755)
        result = subprocess.run([str(REPO / "scripts/neobrix-power"), "battery"],
                                env=self.env | {"XDG_RUNTIME_DIR": str(unsafe)},
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((unsafe / "neobrix").exists())
        env = dict(self.env)
        env.pop("XDG_RUNTIME_DIR")
        result = subprocess.run([str(REPO / "scripts/neobrix-power"), "battery"],
                                env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.root / f"neobrix-runtime-{os.getuid()}" / "neobrix/power-profile-on-mains"
        self.assertTrue(state.is_file())
        self.assertEqual(state.read_text(), "balanced")
        self.assertFalse((unsafe / "neobrix").exists())


if __name__ == "__main__":
    unittest.main()
