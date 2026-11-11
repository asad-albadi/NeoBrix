import json
import os
import shutil
import re
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
                self.assertEqual(metadata["webkitCSS"], "webkit.css")
                self.assertEqual(metadata["webkitJS"], "webkit.js")
                self.assertTrue((theme / "webkit.css").exists())
                self.assertTrue((theme / "webkit.js").exists())
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

    @unittest.skipUnless(shutil.which("chromium"), "Chromium is needed for CSS rendering")
    def test_library_surfaces_use_neobrix_colors_and_hard_shadows(self):
        theme = self.install_fixture()
        for mode, panel, surface in [
            ("dusk", "rgb(25, 19, 16)", "rgb(46, 36, 28)"),
            ("dawn", "rgb(241, 230, 217)", "rgb(252, 246, 238)")]:
            with self.subTest(mode=mode):
                result = self.run_generator(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                css = (theme / "libraryroot.custom.css").read_text()
                # Representative Steam DOM, including the actual sidebar,
                # news, and shelf classes missed by the first theme.
                html = '''<!doctype html><html><head><style>'''+css+'''</style></head>
<body class="DesktopUI"><div class="_3xRRJfD2xy95i9NhJxLTp0">
<div id="sidebar" class="_1ijTaXJJA5YWl_fW2IxcaT"></div>
<div id="news" class="_17uEBe5Ri8TMsnfELvs8-N"></div>
<div id="shelf" class="V7RuDNUxhxoBRaiGWbk3B">
<div id="card" class="WYgDg9NyCcMIVuMyZ_NBC"></div></div>
</div><div class="_2iE-78WxX2Pj4GHbq7YJiA">
<div id="hero" class="_2gZXhRmKUk68pA28-5ZmGQ"></div>
<div class="_1_cYNJSvS6IXs9vLTEYjy5"><div id="actions" class="_1U7LKpx70kEsz3jJwAFOi-"></div></div>
</div><div class="title-bar-actions window-controls">
<div id="minimize" class="title-area-icon minimizeButton"><div></div></div>
<div id="maximize" class="title-area-icon maximizeButton"><div></div></div>
<div id="close" class="title-area-icon closeButton"><div></div></div>
</div><pre id="result"></pre><script>
const style = id => getComputedStyle(document.getElementById(id));
document.getElementById('result').textContent = JSON.stringify({
 sidebar: style('sidebar').backgroundColor, news: style('news').backgroundColor,
 shelf: style('shelf').backgroundColor, shadow: style('card').boxShadow,
 border: style('card').borderTopWidth,
 heroTop: document.getElementById('hero').getBoundingClientRect().top,
 actionsTop: document.getElementById('actions').getBoundingClientRect().top,
 overlay: getComputedStyle(document.getElementById('hero'),'::after').backgroundImage,
 controls: ['minimize','maximize','close'].map(id=>({
   visible:style(id).visibility, right:style(id).right,
   mask:getComputedStyle(document.getElementById(id),'::before').webkitMaskImage
 }))
});</script></body></html>'''
                preview = self.home / "preview.html"
                preview.write_text(html)
                browser = subprocess.run(
                    ["chromium", "--headless", "--no-sandbox", "--disable-gpu",
                     "--dump-dom", preview.as_uri()], capture_output=True, text=True, timeout=30)
                match = re.search(r'<pre id="result">(.*?)</pre>', browser.stdout)
                self.assertIsNotNone(match, browser.stderr[-1000:])
                styles = json.loads(match.group(1))
                self.assertEqual(styles["sidebar"], panel)
                self.assertEqual(styles["news"], surface)
                self.assertEqual(styles["shelf"], panel)
                self.assertIn("4px 4px 0px", styles["shadow"])
                self.assertEqual(styles["border"], "2px")
                self.assertEqual(styles["heroTop"], styles["actionsTop"])
                self.assertIn("linear-gradient", styles["overlay"])
                self.assertEqual(len({control["right"] for control in styles["controls"]}), 3)
                for control in styles["controls"]:
                    self.assertEqual(control["visible"], "visible")
                    self.assertNotEqual(control["mask"], "none")

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
let palette = {'--nb-surface': '#fcf6ee', '--nb-text': '#1e1815', '--nb-color-scheme': 'light'};
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
assert.equal(colors.get('--nb-color-scheme'), 'light');
palette = {'--nb-surface': '#2e241c', '--nb-text': '#f6ede2',
           '--nb-color-scheme': 'dark', '--nb-primary': 'url(https://invalid)', 'background': '#ffffff'};
await tick();
assert.equal(colors.get('--nb-surface'), '#2e241c');
assert.equal(colors.get('--nb-text'), '#f6ede2');
assert.equal(colors.get('--nb-color-scheme'), 'dark');
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
