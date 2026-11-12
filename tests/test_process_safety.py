"""Runtime records must never turn stale PIDs into process-control authority."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class ProcessSafetyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neobrix-process-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.binary = self.root / "bin"
        self.binary.mkdir()
        (self.binary / "notify-send").write_text("#!/bin/sh\nexit 0\n")
        (self.binary / "notify-send").chmod(0o700)
        for name in ("gpu-screen-recorder", "systemd-inhibit"):
            (self.binary / name).symlink_to(shutil.which("sleep"))
        self.env = {**os.environ, "XDG_RUNTIME_DIR": str(self.runtime),
                    "NEOBRIX_RECORD_DIR": str(self.root / "recordings"),
                    "PATH": str(self.binary) + os.pathsep + os.environ["PATH"]}

    def run_helper(self, script, *args):
        return subprocess.run([str(REPO / "scripts" / script), *args],
                              env=self.env, capture_output=True, text=True, timeout=10)

    def worker(self, ignored_signal=None):
        process = subprocess.Popen([shutil.which("sleep"), "30"], start_new_session=True,
                                   preexec_fn=(lambda: signal.signal(ignored_signal, signal.SIG_IGN))
                                   if ignored_signal is not None else None)
        def cleanup():
            if process.poll() is None:
                process.kill()
            process.wait(timeout=5)
        self.addCleanup(cleanup)
        return process

    def stamp(self, pid):
        return Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()[19]

    def test_record_status_rejects_pid_without_process_identity(self):
        process = self.worker()
        (self.runtime / "neobrix-record.pid").write_text(str(process.pid) + "\n")
        self.assertNotEqual(self.run_helper("neobrix-record", "status").returncode, 0)

    def test_idle_status_rejects_pid_without_process_identity(self):
        process = self.worker()
        (self.runtime / "neobrix-inhibit.pid").write_text(str(process.pid) + "\n")
        result = self.run_helper("neobrix-idle", "inhibit", "status")
        self.assertEqual(result.stdout.strip(), "off")
        self.assertNotEqual(result.returncode, 0)

    def test_record_status_rejects_process_group_pid(self):
        (self.runtime / "neobrix-record.pid").write_text("-1\n")
        self.assertNotEqual(self.run_helper("neobrix-record", "status").returncode, 0)

    def test_record_accepts_matching_process_and_rejects_reused_pid(self):
        process = self.worker()
        record = self.runtime / "neobrix-record.pid"
        record.write_text(f"{process.pid} {self.stamp(process.pid)}\n")
        self.assertEqual(self.run_helper("neobrix-record", "status").returncode, 0)
        record.write_text(f"{process.pid} 0\n")
        self.assertNotEqual(self.run_helper("neobrix-record", "status").returncode, 0)

    def test_private_runtime_rejects_symlink_directory(self):
        link = self.root / "linked-runtime"
        link.symlink_to(self.runtime, target_is_directory=True)
        self.env["XDG_RUNTIME_DIR"] = str(link)
        result = self.run_helper("neobrix-record", "status")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private", result.stderr)

    def test_stale_stop_does_not_signal_an_unrelated_process(self):
        process = self.worker()
        (self.runtime / "neobrix-record.pid").write_text(str(process.pid) + "\n")
        self.assertEqual(self.run_helper("neobrix-record", "stop").returncode, 0)
        self.assertIsNone(process.poll())
        (self.runtime / "neobrix-inhibit.pid").write_text(str(process.pid) + "\n")
        self.assertEqual(self.run_helper("neobrix-idle", "inhibit", "off").returncode, 0)
        self.assertIsNone(process.poll())

    def test_matching_recorder_can_be_stopped(self):
        process = self.worker()
        (self.runtime / "neobrix-record.pid").write_text(f"{process.pid} {self.stamp(process.pid)}\n")
        self.assertEqual(self.run_helper("neobrix-record", "stop").returncode, 0)
        process.wait(timeout=5)
        self.assertFalse((self.runtime / "neobrix-record.pid").exists())

    def test_unresponsive_recorder_remains_visible_after_failed_stop(self):
        process = self.worker(signal.SIGINT)
        record = self.runtime / "neobrix-record.pid"
        record.write_text(f"{process.pid} {self.stamp(process.pid)}\n")
        result = self.run_helper("neobrix-record", "stop")
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(process.poll())
        self.assertTrue(record.exists())
        self.assertEqual(self.run_helper("neobrix-record", "status").returncode, 0)

    def test_unresponsive_inhibitor_remains_visible_after_failed_stop(self):
        process = self.worker(signal.SIGTERM)
        record = self.runtime / "neobrix-inhibit.pid"
        record.write_text(f"{process.pid} {self.stamp(process.pid)}\n")
        result = self.run_helper("neobrix-idle", "inhibit", "off")
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(process.poll())
        self.assertTrue(record.exists())
        self.assertEqual(self.run_helper("neobrix-idle", "inhibit", "status").stdout.strip(), "on")

    def test_active_process_survives_executable_package_replacement(self):
        executable = self.binary / "gpu-screen-recorder"
        executable.unlink()
        shutil.copy2(shutil.which("sleep"), executable)
        process = subprocess.Popen([str(executable), "30"], start_new_session=True)
        def cleanup():
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=5)
        self.addCleanup(cleanup)
        (self.runtime / "neobrix-record.pid").write_text(f"{process.pid} {self.stamp(process.pid)}\n")
        executable.unlink()
        shutil.copy2(shutil.which("sleep"), executable)
        self.assertEqual(self.run_helper("neobrix-record", "status").returncode, 0)

    def test_fallback_runtime_is_private_and_unsafe_explicit_runtime_is_rejected(self):
        self.env.pop("XDG_RUNTIME_DIR", None)
        self.env["TMPDIR"] = str(self.root)
        self.run_helper("neobrix-record", "status")
        fallback = self.root / f"neobrix-runtime-{os.getuid()}"
        self.assertTrue(fallback.is_dir())
        self.assertEqual(fallback.stat().st_mode & 0o777, 0o700)
        self.env["XDG_RUNTIME_DIR"] = str(self.runtime)
        self.runtime.chmod(0o755)
        result = self.run_helper("neobrix-record", "status")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private", result.stderr)


if __name__ == "__main__":
    unittest.main()
