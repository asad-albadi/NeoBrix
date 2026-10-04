import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
PALETTE = REPO / "scripts/lib/palette.sh"
ZED = REPO / "scripts/neobrix-generate-zed"
EDITOR = REPO / "scripts/neobrix-generate-editor-theme"
HERDR = REPO / "scripts/neobrix-generate-herdr"


def luminance(color):
    """Relative luminance for an opaque #rrggbb or #rrggbbaa colour."""
    color = color.lstrip("#")[:6]
    channels = [int(color[index:index + 2], 16) / 255 for index in range(0, 6, 2)]

    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = map(linear, channels)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast(foreground, background):
    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


class DawnThemeContrastTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name) / "home"
        self.config = Path(self.temp.name) / "config"
        self.home.mkdir()
        self.config.mkdir()
        self.env = os.environ | {"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.config)}

        # Both generators intentionally skip absent applications. These empty
        # directories model installed applications without touching the user’s
        # real profiles.
        (self.home / ".cursor").mkdir()
        (self.config / "zed").mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def run_generator(self, path):
        subprocess.run([str(path), "dawn"], env=self.env, check=True, timeout=15,
                       text=True, capture_output=True)

    def zed_theme(self):
        self.run_generator(ZED)
        return json.loads((self.config / "zed/themes/neobrix.json").read_text())["themes"][0]["style"]

    def cursor_theme(self):
        self.run_generator(EDITOR)
        return json.loads((self.home / ".cursor/extensions/neobrix-theme/themes/neobrix-dawn.json").read_text())

    def test_dawn_terminal_foregrounds_are_legible_on_the_editor_background(self):
        style = self.zed_theme()
        background = style["terminal.background"]
        ansi = [value for key, value in style.items()
                if key.startswith("terminal.ansi.") and key != "terminal.ansi.background"]

        failures = [f"{color} ({contrast(color, background):.2f}:1)" for color in ansi
                    if contrast(color, background) < 4.5]
        self.assertEqual(failures, [], "Dawn terminal foregrounds must meet 4.5:1: " + ", ".join(failures))

    def test_dawn_zed_syntax_uses_legible_ink_not_soft_surface_accents(self):
        style = self.zed_theme()
        background = style["editor.background"]
        colors = [token["color"] for token in style["syntax"].values()]
        failures = [f"{color} ({contrast(color, background):.2f}:1)" for color in colors
                    if contrast(color, background) < 4.5]
        self.assertEqual(failures, [], "Dawn Zed syntax foregrounds must meet 4.5:1: " + ", ".join(failures))

    def test_dawn_cursor_diagnostics_and_git_labels_are_legible(self):
        theme = self.cursor_theme()
        colors = theme["colors"]
        background = colors["editor.background"]
        keys = [
            "descriptionForeground", "errorForeground", "editorError.foreground",
            "editorWarning.foreground", "editorInfo.foreground",
            "gitDecoration.modifiedResourceForeground", "gitDecoration.addedResourceForeground",
            "gitDecoration.deletedResourceForeground", "gitDecoration.untrackedResourceForeground",
        ]
        failures = [f"{key}={colors[key]} ({contrast(colors[key], background):.2f}:1)"
                    for key in keys if contrast(colors[key], background) < 4.5]
        self.assertEqual(failures, [], "Dawn Cursor labels must meet 4.5:1: " + ", ".join(failures))

    def test_herdr_theme_is_valid_and_preserves_unrelated_user_settings(self):
        herdr_dir = self.config / "herdr"
        herdr_dir.mkdir()
        config = herdr_dir / "config.toml"
        config.write_text('''onboarding = false

[ui.toast]
delivery = "system"

[theme]
name = "catppuccin"

[theme.custom]
surface_dim = "#444444"
''')
        bin_dir = Path(self.temp.name) / "bin"
        bin_dir.mkdir()
        fake_herdr = bin_dir / "herdr"
        fake_herdr.write_text("#!/bin/sh\nexit 0\n")
        fake_herdr.chmod(0o755)
        env = self.env | {"PATH": str(bin_dir) + os.pathsep + self.env["PATH"]}

        subprocess.run([str(HERDR), "dawn"], env=env, check=True, timeout=15,
                       text=True, capture_output=True)

        import tomllib
        generated = tomllib.loads(config.read_text())
        self.assertFalse(generated["onboarding"])
        self.assertEqual(generated["ui"]["toast"]["delivery"], "system")
        self.assertIs(generated["theme"]["auto_switch"], True)
        self.assertEqual(generated["theme"]["light_name"], "terminal")
        self.assertEqual(generated["theme"]["dark_name"], "terminal")
        self.assertEqual(generated["theme"]["custom"]["surface_dim"], "#444444")
        self.assertEqual(generated["theme"]["custom"]["light"]["panel_bg"], "#fcf6ee")
        self.assertEqual(generated["theme"]["custom"]["light"]["text"], "#1e1815")


if __name__ == "__main__":
    unittest.main()
