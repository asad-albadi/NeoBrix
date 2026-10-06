import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GENERATOR = REPO / "scripts/neobrix-generate-steam"


class SteamThemeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.steam = self.home / "Steam with spaces"
        self.env = os.environ | {"HOME": str(self.home),
                                 "XDG_DATA_HOME": str(self.home / "data"),
                                 "NEOBRIX_STEAM_DIR": str(self.steam)}

    def tearDown(self):
        self.temp.cleanup()

    def run_generator(self, mode="dawn"):
        self.assertTrue(GENERATOR.exists(), "Steam generator has not been implemented")
        return subprocess.run(["bash", str(GENERATOR), mode], env=self.env,
                              capture_output=True, text=True, timeout=15)

    def install_fixture(self):
        ui = self.steam / "steamui"
        ui.mkdir(parents=True)
        (ui / "chunk-test.js").write_text(
            'e.exports={TitleBar:"titleHash",RootMenuBar:"menuHash",'
            'SuperNavBar:"navHash",LocalContentContainer:"contentHash"};'
            'e.exports={LibraryContextMenu:"contextHash",MainPanel:"mainHash",'
            'Container:"libraryHash",LeftListSizableContainer:"sidebarHash"};')
        return self.steam / "millennium/themes/neobrix"

    def test_switch_updates_palette_and_preserves_unrelated_files(self):
        theme = self.install_fixture()
        theme.mkdir(parents=True)
        (theme / "user-notes.txt").write_text("keep me")
        for mode, background in [("dawn", "#fcf6ee"), ("dusk", "#2e241c")]:
            with self.subTest(mode=mode):
                result = self.run_generator(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                palette = json.loads((theme / "palette.json").read_text())
                self.assertEqual(palette["--nb-surface"], background)
                css = (theme / "libraryroot.custom.css").read_text()
                self.assertIn(background, css)
                self.assertIn(".titleHash", css)
                self.assertIn(".sidebarHash", css)
                metadata = json.loads((theme / "skin.json").read_text())
                self.assertTrue(metadata["UseDefaultPatches"])
                self.assertTrue((theme / "libraryroot.custom.js").exists())
        self.assertEqual((theme / "user-notes.txt").read_text(), "keep me")

    def test_missing_steam_is_skipped_without_creating_profile(self):
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.steam.exists())

    def test_alternative_module_exports_and_hyphen_classes_are_kept(self):
        theme = self.install_fixture()
        bundle = self.steam / "steamui/chunk-test.js"
        with bundle.open("a") as file:
            file.write('e.exports={LibraryContextMenu:"altContext",MainPanel:"altMain",'
                       'Container:"altLibrary",LeftListSizableContainer:"altSidebar"};'
                       'e.exports={GameListEntryContainer:"entryHash",'
                       'GameListEntryName:"nameHash",GameListEntryLabels:"-labelsHash"};')
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        css = (theme / "libraryroot.custom.css").read_text()
        self.assertIn(".sidebarHash", css)
        self.assertIn(".altSidebar", css)
        self.assertIn(".-labelsHash", css)

    def test_invalid_mode_does_not_write_theme(self):
        theme = self.install_fixture()
        result = self.run_generator("invalid")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(theme.exists())

    def test_standard_steam_symlink_is_detected(self):
        theme = self.install_fixture()
        (self.home / ".steam").mkdir()
        (self.home / ".steam/steam").symlink_to(self.steam)
        self.env.pop("NEOBRIX_STEAM_DIR")
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((theme / "skin.json").exists())

    @unittest.skipUnless(shutil.which("node"), "Node is needed to exercise the sync module")
    def test_live_palette_switch_and_invalid_colors(self):
        module = self.home / "palette-sync.mjs"
        module.write_text((REPO / "theming/steam/palette-sync.js").read_text())
        # Exercise the real module. The doubles represent Millennium's fetch
        # boundary and the DOM; assertions concern the colors it applies.
        harness = r'''
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const colors = new Map();
const documentEvents = new EventTarget();
const windowEvents = new EventTarget();
globalThis.window = windowEvents;
globalThis.document = documentEvents;
document.hidden = false;
document.documentElement = {style: {setProperty: (key, value) => colors.set(key, value)}};
let palette = {'--nb-surface': '#fcf6ee', '--nb-text': '#1e1815'};
globalThis.fetch = async (url, options) => {
    assert.equal(url.pathname.endsWith('/palette.json'), true);
    assert.equal(options.cache, 'no-store');
    return {ok: true, json: async () => palette};
};
let tick;
globalThis.setInterval = callback => { tick = callback; return 1; };
globalThis.clearInterval = () => {};
await import(pathToFileURL(process.argv[1]));
await new Promise(resolve => setImmediate(resolve));
assert.equal(colors.get('--nb-surface'), '#fcf6ee');
palette = {'--nb-surface': '#2e241c', '--nb-text': '#f6ede2',
           '--nb-primary': 'url(https://invalid)', 'background': '#ffffff'};
await tick();
assert.equal(colors.get('--nb-surface'), '#2e241c');
assert.equal(colors.get('--nb-text'), '#f6ede2');
assert.equal(colors.has('--nb-primary'), false);
assert.equal(colors.has('background'), false);
document.hidden = true;
palette = {'--nb-surface': '#fcf6ee'};
await tick();
assert.equal(colors.get('--nb-surface'), '#2e241c');
document.hidden = false;
document.dispatchEvent(new Event('visibilitychange'));
await new Promise(resolve => setImmediate(resolve));
assert.equal(colors.get('--nb-surface'), '#fcf6ee');
globalThis.fetch = async () => { throw new Error('offline'); };
await tick();
assert.equal(colors.get('--nb-surface'), '#fcf6ee');
'''
        result = subprocess.run(["node", "--input-type=module", "-e", harness, str(module)],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
