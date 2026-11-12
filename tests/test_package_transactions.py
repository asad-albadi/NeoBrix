"""Pacman mutations use one consented, rolling-release-safe transaction."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class PackageTransactionTest(unittest.TestCase):
    def test_optional_mpv_support_shares_the_confirmed_full_upgrade(self):
        with tempfile.TemporaryDirectory(prefix="neobrix-packages-") as tmp:
            root = Path(tmp)
            binary = root / "bin"
            binary.mkdir()
            pacman = binary / "pacman"
            pacman.write_text('''#!/bin/bash
case "$1" in
  -Qq) case "$2" in cliphist|mpv-mpris) exit 1;; *) exit 0;; esac;;
  -Si|-Sy) exit 0;;
  -S|-Syu) printf '%s\\n' "$*" >> "$NB_TEST_TRANSACTION_LOG"; exit 0;;
esac
exit 1
''')
            sudo = binary / "sudo"
            sudo.write_text('''#!/bin/bash
if [[ $1 == pacman ]]; then exec "$@"; fi
exit 0
''')
            for path in (pacman, sudo):
                path.chmod(0o700)
            log = root / "transactions"
            env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                   "NB_TEST_TRANSACTION_LOG": str(log)}
            result = subprocess.run([str(REPO / "install/packages.sh"), "--yes"],
                                    env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            transactions = log.read_text().splitlines()
            self.assertEqual(len(transactions), 1, transactions)
            args = transactions[0].split()
            self.assertEqual(args[0], "-Syu")
            self.assertIn("--needed", args)
            self.assertIn("--noconfirm", args)
            self.assertIn("cliphist", args)
            self.assertIn("mpv-mpris", args)
            self.assertIn("full system upgrade", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
