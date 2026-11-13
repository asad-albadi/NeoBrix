"""Herdr desktop theming through NeoBrix's existing entry point, in a temp home."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_theme_contrast import contrast


REPO = Path(__file__).resolve().parents[1]
GENERATOR = REPO / "scripts/neobrix-generate-herdr"


class HerdrGuiThemeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neobrix-herdr-gui-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "config"
        self.app = self.config / "herdr-app"
        self.app.mkdir(parents=True)
        self.settings = self.app / "settings.json"
        self.personal = {"zoom": 1.25, "font": "My Mono", "font_size": 16,
                         "sounds": {"enabled": False}, "minimum_contrast": 1.0,
                         "theme": "graphite", "appearance": "dark"}
        self.settings.write_text(json.dumps(self.personal))
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "calls.jsonl"
        self.binary = self.bin / "herdr-app"
        self.binary.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
with Path(os.environ["HERDR_TEST_LOG"]).open("a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
sys.exit(int(os.environ.get("HERDR_TEST_OFFLINE", "0")))
''')
        self.binary.chmod(0o700)
        self.env = os.environ | {"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.config),
                                 "HERDR_TEST_LOG": str(self.log),
                                 "PATH": str(self.bin) + ":/usr/bin:/bin"}
        self.env.pop("HERDR_APP_HOME", None)
        self.env.pop("HERDR_CONFIG_PATH", None)

    def run_generator(self, mode="dawn", success=True):
        result = subprocess.run([str(GENERATOR), mode], env=self.env, text=True,
                                capture_output=True, timeout=15)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_switch_updates_gui_even_without_the_tui_and_keeps_personal_settings(self):
        for mode, appearance in (("dawn", "light"), ("dusk", "dark"), ("dawn", "light")):
            self.run_generator(mode)
            current = json.loads(self.settings.read_text())
            expected = self.personal | {"theme": {"light": "neobrix-dawn", "dark": "neobrix-dusk"},
                                        "appearance": appearance}
            self.assertEqual(current, expected)
            self.assertFalse((self.config / "herdr").exists(), "GUI users must not need a TUI config")
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(calls, [["do", "app.theme", "--name", "neobrix-dawn"],
                                 ["do", "app.theme", "--name", "neobrix-dusk"],
                                 ["do", "app.theme", "--name", "neobrix-dawn"]])

    def test_gui_themes_use_neobrix_surfaces_and_legible_terminal_and_panel_text(self):
        self.run_generator()
        for mode, background, foreground, sidebar in (
            ("dawn", "#fcf6ee", "#1e1815", "#f1e6d9"),
            ("dusk", "#2e241c", "#f6ede2", "#191310"),
        ):
            theme = json.loads((self.app / "themes" / f"neobrix-{mode}.json").read_text())
            self.assertEqual(theme["background"], background)
            self.assertEqual(theme["foreground"], foreground)
            self.assertEqual(theme["colors"]["chrome"], sidebar)
            self.assertEqual(len(theme["ansi"]), 16)
            roles = theme["colors"]
            for role in ("foreground", "muted", "dim", "accent", "working", "blocked", "done"):
                for surface in ("background", "chrome", "selected"):
                    self.assertGreaterEqual(contrast(roles[role], roles[surface]), 4.5,
                                            f"{mode}: {role} on {surface}")
            self.assertGreaterEqual(contrast(roles["solid_foreground"], roles["solid"]), 4.5)
            if mode == "dawn":
                for color in theme["ansi"]:
                    self.assertGreaterEqual(contrast(color, background), 4.5)

    def test_rerun_preserves_layouts_keys_and_other_themes(self):
        owned = {"layouts/main.json": '{"theme":"paper","children":[]}',
                 "keys.json": '{"bindings":[]}', "themes/mine.json": '{"background":"#123456"}'}
        for relative, content in owned.items():
            target = self.app / relative
            target.parent.mkdir(exist_ok=True)
            target.write_text(content)
        self.run_generator()
        themes = {p.name: (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in (self.app / "themes").glob("neobrix-*.json")}
        self.assertEqual(len(themes), 2)
        self.run_generator()
        self.assertEqual(themes, {p.name: (p.read_bytes(), p.stat().st_mtime_ns)
                                 for p in (self.app / "themes").glob("neobrix-*.json")})
        for relative, content in owned.items():
            self.assertEqual((self.app / relative).read_text(), content)

    def test_invalid_settings_are_not_overwritten(self):
        self.settings.write_text('{"zoom": broken')
        self.run_generator(success=False)
        self.assertEqual(self.settings.read_text(), '{"zoom": broken')
        self.assertFalse(self.log.exists())

    def test_invalid_gui_settings_do_not_block_the_independent_tui(self):
        import tomllib
        self.settings.write_text('{"zoom": broken')
        tui = self.config / "herdr/config.toml"
        tui.parent.mkdir()
        tui.write_text('[theme]\nname = "catppuccin"\n')
        binary = self.bin / "herdr"
        binary.write_text("#!/bin/sh\nexit 0\n")
        binary.chmod(0o700)
        self.run_generator(success=False)
        generated = tomllib.loads(tui.read_text())
        self.assertEqual(generated["theme"]["name"], "terminal")
        self.assertEqual(generated["theme"]["custom"]["light"]["panel_bg"], "#fcf6ee")
        self.assertEqual(self.settings.read_text(), '{"zoom": broken')

    def test_closed_app_is_prepared_for_next_launch(self):
        self.env["HERDR_TEST_OFFLINE"] = "1"
        self.run_generator("dusk")
        self.assertEqual(json.loads(self.settings.read_text())["appearance"], "dark")
        self.assertTrue((self.app / "themes/neobrix-dusk.json").exists())

    def test_custom_app_home_is_respected(self):
        alternate = self.home / "alternate-app"
        self.env["HERDR_APP_HOME"] = str(alternate)
        self.run_generator("dusk")
        self.assertEqual(json.loads((alternate / "settings.json").read_text())["appearance"], "dark")
        self.assertEqual(json.loads(self.settings.read_text()), self.personal)

    def test_absent_gui_does_not_create_configuration(self):
        self.binary.unlink()
        self.settings.unlink()
        self.app.rmdir()
        self.run_generator()
        self.assertFalse(self.app.exists())


if __name__ == "__main__":
    unittest.main()
