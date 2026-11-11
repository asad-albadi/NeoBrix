import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "neobrix-greeter"


class GreeterTransitionTest(unittest.TestCase):
    def test_enable_replaces_a_non_neobrix_greetd_config_and_keeps_a_rollback_copy(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            etc = root / "etc/greetd"
            etc.mkdir(parents=True)
            noctalia = '[default_session]\ncommand = "noctalia-greeter-session"\nuser = "greeter"\n'
            neobrix = '# NeoBrix ReGreet\n[default_session]\ncommand = "cage -s -- regreet"\nuser = "greeter"\n'
            (etc / "config.toml").write_text(noctalia)
            (etc / "config.toml.neobrix-greeter").write_text(neobrix)
            (etc / "config.toml.pre-regreet").write_text("[default_session]\ncommand = \"agreety\"\n")
            (etc / "RECOVERY").write_text("recovery\n")
            unit_dir = root / "etc/systemd/system"
            unit_dir.mkdir(parents=True)
            (unit_dir / "greetd.service").touch()
            (unit_dir / "display-manager.service").symlink_to(unit_dir / "greetd.service")
            fake_bin = root / "bin"
            fake_bin.mkdir()
            (fake_bin / "sudo").write_text("#!/bin/sh\nexec \"$@\"\n")
            (fake_bin / "sudo").chmod(0o755)

            result = subprocess.run(
                [str(HELPER), "enable"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                env=os.environ | {
                    "NEOBRIX_TESTING": "1",
                    "NEOBRIX_TEST_ROOT": str(root),
                    "PATH": f"{fake_bin}:{os.environ['PATH']}",
                },
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((etc / "config.toml").read_text(), neobrix, result.stdout)
            backups = list(etc.glob("config.toml.before-activate-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), noctalia)


if __name__ == "__main__":
    unittest.main()
