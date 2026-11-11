import json
import os
import pathlib
import subprocess
import tempfile
import unittest


REPO = pathlib.Path(__file__).resolve().parents[1]


class ObsidianThemeTest(unittest.TestCase):
    def generate(self, appearance):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            vault = root / "vault"
            settings = vault / ".obsidian"
            settings.mkdir(parents=True)
            config = root / "config"
            (config / "obsidian").mkdir(parents=True)
            (config / "obsidian/obsidian.json").write_text(json.dumps({
                "vaults": {"test": {"path": str(vault)}}
            }))
            path = settings / "appearance.json"
            path.write_text(json.dumps(appearance))
            subprocess.run(
                [str(REPO / "scripts/neobrix-generate-obsidian-theme"), "dusk"],
                env={**os.environ, "XDG_CONFIG_HOME": str(config)},
                check=True, capture_output=True, text=True,
            )
            self.assertTrue((settings / "themes/NeoBrix/theme.css").is_file())
            self.assertTrue((settings / "themes/NeoBrix/screenshot.png").is_file())
            return json.loads(path.read_text())

    def test_selects_custom_theme_without_overwriting_base_scheme(self):
        appearance = self.generate({"theme": "moonstone", "baseFontSize": 17})
        self.assertEqual(appearance.get("cssTheme"), "NeoBrix")
        self.assertEqual(appearance["theme"], "moonstone")
        self.assertEqual(appearance["baseFontSize"], 17)

    def test_repairs_legacy_invalid_base_scheme(self):
        appearance = self.generate({"theme": "NeoBrix", "nativeMenus": True})
        self.assertEqual(appearance.get("cssTheme"), "NeoBrix")
        self.assertNotIn("theme", appearance)
        self.assertTrue(appearance["nativeMenus"])


if __name__ == "__main__":
    unittest.main()
