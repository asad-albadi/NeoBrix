import json
import pathlib
import subprocess
import unittest


REPO = pathlib.Path(__file__).resolve().parents[1]
MODEL = REPO / "quickshell/Services/KeyboardLayout.js"


class KeyboardLayoutTest(unittest.TestCase):
    def call_model(self, method, *args):
        script = """
const fs = require('fs');
const vm = require('vm');
const context = vm.createContext({});
if (fs.existsSync(process.argv[1]))
    vm.runInContext(fs.readFileSync(process.argv[1], 'utf8'), context);
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
console.log(JSON.stringify(typeof context[input.method] === 'function'
    ? context[input.method](...input.args) : null));
"""
        result = subprocess.run(
            ["node", "-e", script, str(MODEL)],
            input=json.dumps({"method": method, "args": args}),
            capture_output=True, text=True, check=True,
        )
        state = json.loads(result.stdout)
        self.assertIsNotNone(state, "keyboard layout model is not implemented")
        return state

    def describe(self, keyboards, preferred=""):
        return self.call_model("describe", keyboards, preferred)

    def test_main_keyboard_drives_label_instead_of_media_device(self):
        state = self.describe([
            {"name": "media-keys", "layout": "us,ara", "active_layout_index": 0},
            {"name": "keyboard", "layout": "us,ara", "active_layout_index": 1,
             "active_keymap": "Arabic", "main": True},
        ])
        self.assertEqual(state["keyboard"], "keyboard")
        self.assertEqual(state["label"], "AR")
        self.assertEqual(state["name"], "Arabic")
        self.assertEqual(state["count"], 2)

    def test_layout_event_keyboard_takes_precedence_over_main(self):
        self.assertEqual(self.describe([
            {"name": "external", "layout": "us,ara", "active_layout_index": 0,
             "active_keymap": "English (US)", "main": True},
            {"name": "laptop", "layout": "us,ara", "active_layout_index": 1,
             "active_keymap": "Arabic"},
        ], "laptop")["label"], "AR")

    def test_removed_keyboard_falls_back_to_main_and_lists_all_layouts(self):
        state = self.describe([
            {"name": "remaining", "layout": "us,de,ara", "active_layout_index": 1,
             "active_keymap": "German", "main": True},
        ], "unplugged")
        self.assertEqual(state["label"], "DE")
        self.assertEqual(state.get("layouts"), [
            {"index": 0, "name": "English (US)", "label": "EN", "current": False},
            {"index": 1, "name": "German", "label": "DE", "current": True},
            {"index": 2, "name": "Arabic", "label": "AR", "current": False},
        ])

    def test_no_keyboard_hides_indicator(self):
        state = self.describe([])
        self.assertEqual(state["label"], "")
        self.assertEqual(state["count"], 0)
        self.assertEqual(state.get("layouts"), [])

    def test_single_layout_and_english_variant(self):
        state = self.describe([
            {"name": "keyboard", "layout": "gb", "active_layout_index": 0,
             "active_keymap": "English (UK)"},
        ])
        self.assertEqual(state["label"], "EN")
        self.assertEqual(state["count"], 1)
        self.assertEqual(state.get("selectedIndex"), 0)

    def test_picking_a_layout_selects_its_exact_index_for_all_keyboards(self):
        state = self.describe([
            {"name": "keyboard", "layout": "us,de,ara", "active_layout_index": 0},
        ])
        self.assertEqual(self.call_model("selectionCommand", state, 2),
                         ["hyprctl", "switchxkblayout", "all", "2"])

    def test_current_or_invalid_selection_does_not_switch_layout(self):
        state = self.describe([
            {"name": "keyboard", "layout": "us,ara", "active_layout_index": 0},
        ])
        for index in [0, -1, 2, 0.5, "1"]:
            with self.subTest(index=index):
                self.assertEqual(self.call_model("selectionCommand", state, index), [])


if __name__ == "__main__":
    unittest.main()
