"""Native desktop config API integration in temporary homes; no live app is touched."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


REPO = Path(__file__).resolve().parents[1]
BACKEND = Path('/usr/lib/chatgpt/resources/codex')


@unittest.skipUnless(BACKEND.is_file(), 'ChatGPT desktop bundled config backend is required')
class ChatGptDesktopThemeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='neobrix-chatgpt-theme-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / 'config'
        self.config.mkdir()
        self.codex = self.home / 'desktop-config'
        self.codex.mkdir()
        self.settings = self.codex / 'config.toml'
        self.original = '# My config comment\nmodel = "test-model"\n\n[desktop]\nfollowUpQueueMode = "steer"\n'
        self.settings.write_text(self.original)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        for command in ('chatgpt', 'qs', 'gsettings', 'pkill', 'lspci', 'systemctl', 'hyprctl'):
            path = self.bin / command
            path.write_text('#!/bin/sh\nexit 0\n')
            path.chmod(0o700)
        self.env = os.environ | {
            'HOME': str(self.home), 'CODEX_HOME': str(self.codex),
            'XDG_CONFIG_HOME': str(self.config), 'XDG_STATE_HOME': str(self.home / 'state'),
            'XDG_DATA_HOME': str(self.home / 'data'), 'XDG_CACHE_HOME': str(self.home / 'cache'),
            'PATH': str(self.bin) + ':/usr/bin:/bin', 'NEOBRIX_CHATGPT_CODEX': str(BACKEND),
        }
        self.env.pop('HERDR_APP_HOME', None)
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)

    def run_script(self, script='neobrix-generate-chatgpt', mode='dawn', success=True):
        result = subprocess.run([str(REPO / 'scripts' / script), mode], env=self.env,
                                text=True, capture_output=True, timeout=20)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_normal_theme_switch_installs_native_light_and_dark_palettes(self):
        self.run_script('neobrix-theme')
        config = tomllib.loads(self.settings.read_text())
        desktop = config['desktop']
        self.assertEqual(desktop.get('appearanceTheme'), 'system')
        self.assertEqual(desktop['appearanceLightChromeTheme']['surface'], '#fcf6ee')
        self.assertEqual(desktop['appearanceLightChromeTheme']['ink'], '#1e1815')
        self.assertEqual(desktop['appearanceDarkChromeTheme']['surface'], '#2e241c')
        self.assertEqual(desktop['appearanceDarkChromeTheme']['ink'], '#f6ede2')
        self.assertEqual(desktop['followUpQueueMode'], 'steer')
        self.assertEqual(config['model'], 'test-model')
        self.assertIn('# My config comment\n', self.settings.read_text())
        self.assertFalse((self.codex / 'auth.json').exists(), 'Theming must not require sign-in')

    def test_native_update_preserves_custom_fonts_and_other_desktop_preferences(self):
        self.settings.write_text(self.original + '''
[desktop.appearanceLightChromeTheme]
contrast = 31
opaqueWindows = false
[desktop.appearanceLightChromeTheme.fonts]
ui = "My Sans"
code = "My Mono"
content = "My Reading Font"
''')
        self.run_script()
        light = tomllib.loads(self.settings.read_text())['desktop']['appearanceLightChromeTheme']
        self.assertEqual(light['fonts'], {'ui': 'My Sans', 'code': 'My Mono', 'content': 'My Reading Font'})
        self.assertEqual(light['contrast'], 31)
        self.assertIs(light['opaqueWindows'], False)
        self.assertEqual(light['semanticColors']['diffAdded'], '#386e35')
        self.assertEqual(light['semanticColors']['diffRemoved'], '#9e3f39')

    def test_unchanged_palette_does_not_rewrite_the_user_config(self):
        self.run_script()
        before = (self.settings.read_bytes(), self.settings.stat().st_mtime_ns)
        self.run_script(mode='dusk')
        self.assertEqual((self.settings.read_bytes(), self.settings.stat().st_mtime_ns), before)

    def test_invalid_toml_is_not_replaced(self):
        self.settings.write_text('[desktop\ninvalid =')
        self.run_script(success=False)
        self.assertEqual(self.settings.read_text(), '[desktop\ninvalid =')

    def test_invalid_existing_fonts_are_reported_without_overwriting_settings(self):
        original = self.original + '\n[desktop.appearanceLightChromeTheme.fonts]\nui = 42\n'
        self.settings.write_text(original)
        self.run_script(success=False)
        self.assertEqual(self.settings.read_text(), original)

    def test_cli_only_install_is_not_treated_as_the_desktop_app(self):
        self.env.pop('NEOBRIX_CHATGPT_CODEX')
        (self.bin / 'chatgpt').unlink()
        # Exclude the host's real /usr/bin/chatgpt as well as our fake app.
        for name in ('bash', 'dirname', 'readlink'):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env['PATH'] = str(self.bin)
        self.run_script()
        self.assertEqual(self.settings.read_text(), self.original)

    def test_missing_backend_never_replaces_settings(self):
        self.env['NEOBRIX_CHATGPT_CODEX'] = str(self.home / 'missing-backend')
        self.run_script(success=False)
        self.assertEqual(self.settings.read_text(), self.original)


class DesktopConfigProtocolTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='neobrix-chatgpt-rpc-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.settings = self.home / 'config.toml'
        self.settings.write_text('# Private user preferences\nmodel = "keep-model"\n')
        self.backend = self.home / 'backend'
        self.log = self.home / 'calls.jsonl'
        self.env = os.environ | {'HOME': str(self.home), 'CODEX_HOME': str(self.home),
                                 'NEOBRIX_CHATGPT_CODEX': str(self.backend), 'RPC_TEST_LOG': str(self.log)}

    def run_backend(self, source):
        self.backend.write_text('#!/usr/bin/python3\n' + source)
        self.backend.chmod(0o700)
        return subprocess.run([str(REPO / 'scripts/neobrix-generate-chatgpt'), 'dawn'],
                              env=self.env, text=True, capture_output=True, timeout=15)

    def test_backend_errors_never_print_private_configuration_content(self):
        result = self.run_backend('''import json, sys
for line in sys.stdin:
    request = json.loads(line)
    if "id" in request:
        print(json.dumps({"id": request["id"], "error": {
            "code": -32000, "message": "PRIVATE-CONFIG-SECRET", "data": "PRIVATE-CONFIG-SECRET"}}), flush=True)
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('PRIVATE-CONFIG-SECRET', result.stdout + result.stderr)
        self.assertIn('initialize failed', result.stderr)
        self.assertEqual(self.settings.read_text(), '# Private user preferences\nmodel = "keep-model"\n')

    def test_concurrent_edit_is_reread_before_retrying_the_atomic_batch(self):
        result = self.run_backend('''import json, os, sys
from pathlib import Path
reads = writes = 0
for line in sys.stdin:
    request = json.loads(line)
    with Path(os.environ["RPC_TEST_LOG"]).open("a") as log:
        log.write(json.dumps(request) + "\\n")
    if "id" not in request:
        continue
    method = request["method"]
    if method == "config/read":
        reads += 1
        result = {"config": {"desktop": {"appearanceLightChromeTheme": {
            "fonts": {"code": "New font" if reads > 1 else "Old font", "ui": "Keep UI"}}}},
            "layers": [{"name": {"type": "user", "file": str(Path(os.environ["CODEX_HOME"]) / "config.toml")},
                        "version": "v2" if reads > 1 else "v1"}]}
    elif method == "config/batchWrite":
        writes += 1
        if writes == 1:
            print(json.dumps({"id": request["id"], "error": {
                "code": -32000, "message": "Config version mismatch"}}), flush=True)
            continue
        result = {"status": "ok"}
    else:
        result = {}
    print(json.dumps({"id": request["id"], "result": result}), flush=True)
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual([call['method'] for call in calls],
                         ['initialize', 'initialized', 'config/read', 'config/batchWrite', 'config/read', 'config/batchWrite'])
        batches = [call['params'] for call in calls if call['method'] == 'config/batchWrite']
        self.assertEqual([batch['expectedVersion'] for batch in batches], ['v1', 'v2'])
        light = next(edit['value'] for edit in batches[1]['edits']
                     if edit['keyPath'] == 'desktop.appearanceLightChromeTheme')
        self.assertEqual(light['fonts'], {'code': 'New font', 'ui': 'Keep UI'})
        self.assertEqual(light['surface'], '#fcf6ee')


if __name__ == '__main__':
    unittest.main()
