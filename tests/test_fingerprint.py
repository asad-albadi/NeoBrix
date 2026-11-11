import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "neobrix-fingerprint"


class FingerprintPamTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        pam = self.root / "etc/pam.d"
        greetd = self.root / "etc/greetd"
        pam.mkdir(parents=True)
        greetd.mkdir(parents=True)
        (pam / "hyprlock").write_text(
            "# PAM configuration file for hyprlock\n"
            "auth        include     login\n"
        )
        (pam / "greetd").write_text(
            "#%PAM-1.0\n"
            "auth       required     pam_securetty.so\n"
            "auth       include      system-local-login\n"
        )
        (greetd / "config.toml").write_text(
            '# NeoBrix ReGreet login screen\n'
            '[default_session]\ncommand = "cage -s -- regreet"\nuser = "greeter"\n'
        )
        module = self.root / "usr/lib/security/pam_fprintd.so"
        module.parent.mkdir(parents=True)
        module.touch()
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        fprint = fake_bin / "fprintd-list"
        fprint.write_text(
            "#!/bin/sh\n"
            "echo 'found 1 devices'\n"
            "echo 'Fingerprints for user testuser on sensor:'\n"
            "echo ' - #0: right-index-finger'\n"
        )
        fprint.chmod(0o755)
        self.env = os.environ | {
            "NEOBRIX_TESTING": "1",
            "NEOBRIX_TEST_ROOT": str(self.root),
            "USER": "testuser",
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
        }

    def tearDown(self):
        self.tmp.cleanup()

    def run_helper(self, *args):
        return subprocess.run(
            [str(HELPER), *args], env=self.env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )

    def test_enable_adds_fingerprint_before_existing_password_fallbacks(self):
        result = self.run_helper("enable")

        self.assertEqual(result.returncode, 0, result.stderr)
        for service, fallback in (("hyprlock", "auth        include     login"),
                                  ("greetd", "auth       include      system-local-login")):
            text = (self.root / "etc/pam.d" / service).read_text()
            self.assertIn("# BEGIN NEOBRIX FINGERPRINT", text)
            self.assertIn("pam_fprintd.so max-tries=1 timeout=10", text)
            self.assertLess(text.index("pam_fprintd.so"), text.index(fallback))

    def test_enable_preserves_original_pam_files_as_rollback_backups(self):
        originals = {
            service: (self.root / "etc/pam.d" / service).read_text()
            for service in ("hyprlock", "greetd")
        }

        result = self.run_helper("enable")

        self.assertEqual(result.returncode, 0, result.stderr)
        for service, original in originals.items():
            backup = self.root / "etc/pam.d" / f"{service}.pre-neobrix-fingerprint"
            self.assertEqual(backup.read_text(), original)

    def test_enable_does_not_partially_change_pam_when_one_service_is_invalid(self):
        hyprlock = self.root / "etc/pam.d/hyprlock"
        original = hyprlock.read_text()
        (self.root / "etc/pam.d/greetd").write_text("# invalid PAM service\n")

        result = self.run_helper("enable")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(hyprlock.read_text(), original)
        self.assertFalse((self.root / "etc/pam.d/hyprlock.pre-neobrix-fingerprint").exists())

    def test_greetd_keeps_its_existing_security_guards_before_fingerprint(self):
        result = self.run_helper("enable")

        self.assertEqual(result.returncode, 0, result.stderr)
        text = (self.root / "etc/pam.d/greetd").read_text()
        self.assertLess(text.index("pam_securetty.so"), text.index("pam_fprintd.so"))
        self.assertLess(text.index("pam_fprintd.so"), text.index("system-local-login"))

    def test_disable_removes_only_the_neobrix_blocks(self):
        originals = {
            service: (self.root / "etc/pam.d" / service).read_text()
            for service in ("hyprlock", "greetd")
        }
        self.assertEqual(self.run_helper("enable").returncode, 0)

        result = self.run_helper("disable")

        self.assertEqual(result.returncode, 0, result.stderr)
        for service, original in originals.items():
            self.assertEqual((self.root / "etc/pam.d" / service).read_text(), original)

    def test_enable_refuses_non_neobrix_greeter_without_touching_hyprlock(self):
        hyprlock = self.root / "etc/pam.d/hyprlock"
        original = hyprlock.read_text()
        (self.root / "etc/greetd/config.toml").write_text(
            '[default_session]\ncommand = "noctalia-greeter-session"\nuser = "greeter"\n'
        )

        result = self.run_helper("enable")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not NeoBrix ReGreet", result.stderr)
        self.assertEqual(hyprlock.read_text(), original)


if __name__ == "__main__":
    unittest.main()
