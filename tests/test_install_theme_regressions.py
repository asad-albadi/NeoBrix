"""Installer/theme regressions confined to temporary homes and an offscreen shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class TemporaryHomeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neobrix-install-theme-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.cfg = self.home / "config"
        self.cfg.mkdir()
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = os.environ | {
            "HOME": str(self.home), "XDG_CONFIG_HOME": str(self.cfg),
            "XDG_DATA_HOME": str(self.home / "data"),
            "XDG_STATE_HOME": str(self.home / "state"),
            "XDG_CACHE_HOME": str(self.home / "cache"),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
        }
        self.env.pop("QS_CONFIG_PATH", None)
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def run_script(self, script, *args):
        result = subprocess.run([str(REPO / script), *args], env=self.env,
                                text=True, capture_output=True, timeout=25)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def stub(self, name, body="exit 0\n"):
        target = self.bin / name
        target.write_text("#!/usr/bin/env bash\n" + body)
        target.chmod(0o700)

    def require_private_snapshot_before_copy(self):
        self.home.chmod(0o755)
        self.cfg.chmod(0o700)
        self.env["REAL_COPY"] = shutil.which("cp")
        self.stub("cp", r'''destination="${!#}"
case "$destination" in
  "$HOME/.config-backup/"*)
    relative="${destination#"$HOME/.config-backup/"}"
    snapshot="$HOME/.config-backup/${relative%%/*}"
    [[ $(stat -c '%a' "$snapshot") == 700 ]] || {
        echo "snapshot must be private before copying: $snapshot" >&2
        exit 69
    }
    ;;
esac
exec "$REAL_COPY" "$@"
''')

    def run_with_public_umask(self, script, *args):
        previous = os.umask(0o022)
        try:
            return self.run_script(script, *args)
        finally:
            os.umask(previous)


class RestoreTest(TemporaryHomeTest):
    def backup(self, relative, content):
        path = self.home / ".config-backup/deploy-20260101" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def test_sparse_restore_keeps_unbacked_files_and_saves_replaced_current_file(self):
        self.backup("hypr/hyprland.lua", "original")
        local = self.cfg / "hypr/machine/local.lua"
        local.parent.mkdir(parents=True)
        local.write_text("my machine")
        unrelated = self.cfg / "hypr/other.conf"
        unrelated.write_text("keep")
        target = self.cfg / "hypr/hyprland.lua"
        target.write_text("current custom config")
        self.run_script("install/deploy.sh", "--restore")
        self.assertTrue(local.exists(), "restore removed the machine override")
        self.assertEqual(local.read_text(), "my machine")
        self.assertEqual(unrelated.read_text(), "keep")
        self.assertEqual(target.read_text(), "original")
        saved = list((self.home / ".config-backup").glob("restore-*/hypr/hyprland.lua"))
        self.assertEqual([path.read_text() for path in saved], ["current custom config"])

    def test_restore_does_not_write_through_symlink_ancestor(self):
        self.backup("hypr/config/input.lua", "original")
        external = self.home / "external"
        external.mkdir()
        (external / "input.lua").write_text("external original")
        (external / "other.lua").write_text("keep sibling")
        (self.cfg / "hypr").mkdir()
        (self.cfg / "hypr/config").symlink_to(external, target_is_directory=True)
        self.run_script("install/deploy.sh", "--restore")
        self.assertEqual((external / "input.lua").read_text(), "external original")
        self.assertFalse((self.cfg / "hypr/config").is_symlink())
        self.assertEqual((self.cfg / "hypr/config/input.lua").read_text(), "original")
        self.assertTrue((self.cfg / "hypr/config/other.lua").exists(), "unbacked symlink child was removed")
        self.assertEqual((self.cfg / "hypr/config/other.lua").read_text(), "keep sibling")
        saved = list((self.home / ".config-backup").glob("restore-*/hypr/config"))
        self.assertTrue(any(path.is_symlink() and path.resolve() == external for path in saved))

    def test_restore_detaches_nested_links_and_preserves_the_original_parent_undo(self):
        self.backup("hypr/config/input.lua", "restored input")
        outside = self.home / "outside-hypr"
        outside.mkdir()
        outside_config = self.home / "outside-config"
        outside_config.mkdir()
        (outside_config / "input.lua").write_text("external input")
        (outside_config / "sibling.lua").write_text("external sibling")
        (outside / "local.lua").write_text("parent sibling")
        (outside / "config").symlink_to(outside_config, target_is_directory=True)
        (self.cfg / "hypr").symlink_to(outside, target_is_directory=True)

        self.run_script("install/deploy.sh", "--restore")

        self.assertFalse((self.cfg / "hypr").is_symlink())
        self.assertFalse((self.cfg / "hypr/config").is_symlink())
        self.assertEqual((self.cfg / "hypr/config/input.lua").read_text(), "restored input")
        self.assertEqual((self.cfg / "hypr/config/sibling.lua").read_text(), "external sibling")
        self.assertEqual((self.cfg / "hypr/local.lua").read_text(), "parent sibling")
        self.assertEqual((outside_config / "input.lua").read_text(), "external input")
        self.assertEqual((outside_config / "sibling.lua").read_text(), "external sibling")
        self.assertTrue((outside / "config").is_symlink())
        self.assertEqual((outside / "config").resolve(), outside_config)
        saved = list((self.home / ".config-backup").glob("restore-*/hypr"))
        self.assertEqual(len(saved), 1)
        self.assertTrue(saved[0].is_symlink())
        self.assertEqual(saved[0].resolve(), outside)
        self.assertTrue((saved[0] / "config").is_symlink())
        self.assertEqual((saved[0] / "config/input.lua").read_text(), "external input")

    def test_dry_restore_leaves_all_files_unchanged(self):
        self.backup("hypr/hyprland.lua", "original")
        target = self.cfg / "hypr/hyprland.lua"
        target.parent.mkdir()
        target.write_text("current")
        self.run_script("install/deploy.sh", "--restore", "--dry-run")
        self.assertEqual(target.read_text(), "current")
        self.assertEqual(list((self.home / ".config-backup").glob("restore-*")), [])


class DeployThemeTest(TemporaryHomeTest):
    def prepare_deploy(self):
        # All commands that can reach a running desktop/server are replaced.
        for command in ("qs", "gsettings", "pkill", "herdr", "lspci", "systemctl"):
            self.stub(command)
        for command in ("hyprlock", "hypridle", "grim", "slurp", "wl-copy",
                        "cliphist", "notify-send", "wpctl", "magick"):
            self.stub(command)
        self.stub("hyprctl", '[[ $1 == version ]] && echo "Hyprland 0.56.0"; exit 0\n')
        self.stub("fc-list", 'echo "JetBrainsMono Nerd Font"\n')
        walls = self.home / "data/neobrix/wallpapers"
        walls.mkdir(parents=True)
        (walls / "neobrix-dawn.png").touch()
        self.env["NEOBRIX_POWER_SUPPLY_DIR"] = str(self.home / "no-battery")

    def test_fresh_deploy_generates_terminal_and_lock_includes(self):
        self.prepare_deploy()
        self.run_script("install/deploy.sh", "--no-enable")
        for relative in ("kitty/neobrix-theme.conf", "alacritty/neobrix-theme.toml",
                         "hypr/hyprlock-palette.conf", "hypr/hyprlock-sysinfo.conf",
                         "hypr/hyprlock-battery.conf"):
            self.assertTrue((self.cfg / relative).is_file(), f"Missing initial theme: {relative}")


    def test_link_backup_is_private_before_copy_and_preserves_file_modes(self):
        self.prepare_deploy()
        self.require_private_snapshot_before_copy()
        unit = self.cfg / "systemd/user/neobrix-shell.service"
        unit.parent.mkdir(parents=True)
        unit.write_text("private configuration behind config root\n")
        unit.chmod(0o644)
        self.run_with_public_umask("install/deploy.sh")
        snapshots = list((self.home / ".config-backup").glob("deploy-*"))
        self.assertEqual(len(snapshots), 1)
        self.assertEqual(snapshots[0].stat().st_mode & 0o777, 0o700)
        saved = snapshots[0] / "systemd/user/neobrix-shell.service"
        self.assertEqual(saved.stat().st_mode & 0o777, 0o644)
        self.assertEqual(saved.read_text(), "private configuration behind config root\n")
        self.assertEqual(self.cfg.stat().st_mode & 0o777, 0o700)

    def test_legacy_backup_is_private_before_copy_and_dry_run_creates_nothing(self):
        self.prepare_deploy()
        self.require_private_snapshot_before_copy()
        legacy = self.cfg / "hypr/hyprland.conf"
        legacy.parent.mkdir()
        legacy.write_text("private legacy config\n")
        legacy.chmod(0o644)
        self.run_with_public_umask("install/deploy.sh", "--dry-run", "--no-enable")
        self.assertFalse((self.home / ".config-backup").exists())
        self.assertEqual(legacy.read_text(), "private legacy config\n")
        self.assertEqual(self.cfg.stat().st_mode & 0o777, 0o700)
        self.run_with_public_umask("install/deploy.sh", "--no-enable")
        snapshots = list((self.home / ".config-backup").glob("deploy-*"))
        self.assertEqual(len(snapshots), 1)
        self.assertEqual(snapshots[0].stat().st_mode & 0o777, 0o700)
        self.assertEqual((snapshots[0] / "hypr/hyprland.conf").stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.cfg.stat().st_mode & 0o777, 0o700)

    def test_deploy_and_restore_preserve_custom_launchers_and_units(self):
        self.prepare_deploy()
        self.env["SYSTEMCTL_LOG"] = str(self.home / "systemctl-calls")
        self.stub("systemctl", 'printf "%s\\n" "$*" >> "$SYSTEMCTL_LOG"\n')
        binary = self.home / ".local/bin"
        binary.mkdir(parents=True)
        launcher = binary / "neobrix"
        launcher.write_text("original unrelated launcher\n")
        custom_theme = self.home / "custom-theme-command"
        custom_theme.write_text("original theme command\n")
        theme_link = binary / "neobrix-theme"
        theme_link.symlink_to(custom_theme)
        unit = self.cfg / "systemd/user/neobrix-shell.service"
        unit.parent.mkdir(parents=True)
        unit.write_text("[Unit]\nDescription=Original user unit\n")

        self.run_script("install/deploy.sh")
        self.assertTrue(launcher.is_symlink())
        self.assertTrue(unit.is_symlink())
        snapshots = list((self.home / ".config-backup").glob("deploy-*"))
        self.assertEqual(len(snapshots), 1, "replacement backups were not created")
        snapshot = snapshots[0]
        self.assertEqual((snapshot / ".local-bin/neobrix").read_text(), "original unrelated launcher\n")
        self.assertEqual((snapshot / "systemd/user/neobrix-shell.service").read_text(),
                         "[Unit]\nDescription=Original user unit\n")
        self.assertTrue((snapshot / ".local-bin/neobrix-theme").is_symlink())
        self.assertEqual((snapshot / ".local-bin/neobrix-theme").resolve(), custom_theme)

        # Our existing links do not produce another backup or replace the original.
        self.run_script("install/deploy.sh")
        self.assertEqual(list((self.home / ".config-backup").glob("deploy-*")), snapshots)
        self.assertEqual((snapshot / ".local-bin/neobrix").read_text(), "original unrelated launcher\n")
        systemctl_log = self.home / "systemctl-calls"
        calls_before_restore = systemctl_log.read_text().splitlines()
        self.run_script("install/deploy.sh", "--restore")
        self.assertEqual(systemctl_log.read_text().splitlines()[len(calls_before_restore):],
                         ["--user daemon-reload"])
        self.assertFalse(launcher.is_symlink())
        self.assertEqual(launcher.read_text(), "original unrelated launcher\n")
        self.assertFalse(unit.is_symlink())
        self.assertEqual(unit.read_text(), "[Unit]\nDescription=Original user unit\n")
        self.assertTrue(theme_link.is_symlink())
        self.assertEqual(theme_link.resolve(), custom_theme)
        self.assertEqual(custom_theme.read_text(), "original theme command\n")
        self.assertFalse((self.cfg / ".local-bin").exists())


class CleanupBackupTest(TemporaryHomeTest):
    def test_confirmed_cleanup_snapshot_is_private_before_copy(self):
        self.require_private_snapshot_before_copy()
        fixture = self.home / "fixture/install"
        (fixture / "lib").mkdir(parents=True)
        script = fixture / "cleanup.sh"
        # Only the confirmation and system boundaries are synthetic. Exercise
        # the actual cleanup detection, backup creation, copy, and removal.
        source = (REPO / "install/cleanup.sh").read_text().replace(
            "/etc/greetd/config.toml", str(self.home / "absent-greetd-config"))
        script.write_text(source)
        script.chmod(0o700)
        (fixture / "lib/ask.sh").write_text(
            'NB_TTY=synthetic\nc_ok=; c_warn=; c_dim=; c_off=\nconfirm() { return 0; }\n')
        self.stub("systemctl", "exit 0\n")
        self.stub("pacman", "exit 1\n")
        self.stub("sudo", "exit 99\n")
        old = self.cfg / "noctalia"
        old.mkdir(mode=0o755)
        private = old / "settings.json"
        private.write_text("private old desktop settings\n")
        private.chmod(0o644)
        self.run_with_public_umask(str(script))
        snapshots = list((self.home / ".config-backup").glob("cleanup-*"))
        self.assertEqual(len(snapshots), 1)
        self.assertEqual(snapshots[0].stat().st_mode & 0o777, 0o700)
        saved = snapshots[0] / "config/noctalia/settings.json"
        self.assertEqual(saved.read_text(), "private old desktop settings\n")
        self.assertEqual(saved.stat().st_mode & 0o777, 0o644)
        self.assertEqual(saved.parent.stat().st_mode & 0o777, 0o755)
        self.assertEqual(self.cfg.stat().st_mode & 0o777, 0o700)
        self.assertFalse(old.exists())


class SettingsTest(TemporaryHomeTest):
    def editor_settings(self, text):
        (self.home / ".cursor").mkdir()
        path = self.cfg / "Cursor/User/settings.json"
        path.parent.mkdir(parents=True)
        path.write_text(text)
        return path

    def test_editor_preserves_jsonc_comments_strings_and_unrelated_settings(self):
        path = self.editor_settings('''{
  // user explanation
  "editor.fontSize": 20, // large text
  /* block comment */ "files.autoSave": "afterDelay",
  "custom.path": "https://example.test/a,}/*keep*/", // commas in strings
  "terminal.integrated.profiles.linux": {"bash": {"path": "/bin/bash"}},
}
''')
        self.run_script("scripts/neobrix-generate-editor-theme", "dusk")
        text = path.read_text()
        for preserved in ['// user explanation', '// large text', '/* block comment */',
                          '"editor.fontSize": 20', '"files.autoSave": "afterDelay"',
                          'https://example.test/a,}/*keep*/', '"bash": {"path": "/bin/bash"}']:
            self.assertIn(preserved, text)
        self.assertIn('"workbench.colorTheme": "Neobrix Dusk"', text)
        self.run_script("scripts/neobrix-generate-editor-theme", "dawn")
        self.assertIn('"workbench.colorTheme": "Neobrix Dawn"', path.read_text())
        self.assertIn('// large text', path.read_text())

    def test_malformed_editor_settings_are_left_untouched(self):
        original = '{"editor.fontSize": 20, BAD}'
        path = self.editor_settings(original)
        self.run_script("scripts/neobrix-generate-editor-theme", "dusk")
        self.assertEqual(path.read_text(), original)

    def test_zed_ignores_commented_and_nested_keys_and_preserves_system_mode(self):
        path = self.cfg / "zed/settings.json"
        path.parent.mkdir()
        path.write_text('''{
  // "theme": "Not the active setting",
  "languages": {"JSON": {"theme": "keep nested"}},
  "theme": {
    // a closing brace in an explanation }
    "mode": /* follow desktop */ "system",
    "light": "One Light",
    "dark": "One Dark",
    "extra": "preserve me"
  },
  "terminal": {
    // "shell": "commented setting",
    "working_directory": "current_project_directory",
    "shell": "system"
  },
  "editor_font_size": 19,
}
''')
        self.run_script("scripts/neobrix-generate-zed", "dusk")
        text = path.read_text()
        for preserved in ['// "theme": "Not the active setting"',
                          '"languages": {"JSON": {"theme": "keep nested"}}',
                          '// a closing brace in an explanation }',
                          '"mode": /* follow desktop */ "system"',
                          '"extra": "preserve me"', '// "shell": "commented setting"',
                          '"working_directory": "current_project_directory"']:
            self.assertIn(preserved, text)
        self.assertIn('"light": "Neobrix Dawn"', text)
        self.assertIn('"dark": "Neobrix Dusk"', text)
        self.assertIn('"program": "/usr/bin/fish"', text)
        self.run_script("scripts/neobrix-generate-zed", "dawn")
        self.assertIn('"mode": /* follow desktop */ "system"', path.read_text())

    def test_malformed_zed_settings_are_left_untouched(self):
        path = self.cfg / "zed/settings.json"
        path.parent.mkdir()
        original = '{"theme": {"mode": "system"}, BAD}'
        path.write_text(original)
        self.run_script("scripts/neobrix-generate-zed", "dusk")
        self.assertEqual(path.read_text(), original)


class ZenLockTest(TemporaryHomeTest):
    def test_running_profile_dangling_lock_preserves_preferences(self):
        profile = self.home / ".zen/profile"
        profile.mkdir(parents=True)
        prefs = profile / "prefs.js"
        original = 'user_pref("ui.systemUsesDarkTheme", 1);\n'
        prefs.write_text(original)
        (profile / "lock").symlink_to("127.0.0.1:+12345")
        self.run_script("scripts/neobrix-generate-zen-theme")
        self.assertEqual(prefs.read_text(), original)
        (profile / "lock").unlink()
        self.run_script("scripts/neobrix-generate-zen-theme")
        self.assertNotIn("ui.systemUsesDarkTheme", prefs.read_text())


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for startup regression")
class ThemeStartupTest(TemporaryHomeTest):
    def test_initial_and_persisted_palettes_apply_once_then_follow_toggles(self):
        # Real singleton/FileView; only its state path and external command are isolated.
        for saved, first in [(None, "dawn"), ("dawn", "dawn"), ("dusk", "dusk")]:
            with self.subTest(saved=saved):
                root = self.home / (saved or "fresh")
                root.mkdir()
                mode = root / "theme-mode"
                if saved:
                    mode.write_text(saved + "\n")
                module = root / "fixture"
                module.mkdir()
                source = (REPO / "quickshell/Theme/Theme.qml").read_text()
                source = source.replace('Quickshell.statePath("theme-mode")', json.dumps(str(mode)))
                (module / "Theme.qml").write_text(source)
                (module / "qmldir").write_text("singleton Theme 1.0 Theme.qml\n")
                log = root / "calls"
                self.stub("neobrix-theme", 'printf "%s\\n" "$1" >> "$THEME_CALLS"\n')
                shell = root / "shell.qml"
                shell.write_text('''import QtQuick
import Quickshell
import "fixture"
ShellRoot {
    readonly property string themeMode: Theme.mode
    Timer { interval: 300; running: true; onTriggered: Theme.toggleMode() }
    Timer { interval: 650; running: true; onTriggered: Qt.quit() }
}
''')
                result = subprocess.run(["qs", "-p", str(shell), "--no-color"],
                                        env=self.env | {"QT_QPA_PLATFORM": "offscreen", "THEME_CALLS": str(log)},
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(log.exists(), result.stdout + result.stderr)
                self.assertEqual(log.read_text().splitlines(),
                                 [first, "dusk" if first == "dawn" else "dawn"])


if __name__ == "__main__":
    unittest.main()
