import json
import datetime as dt
import os
import sqlite3
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COLLECTOR = REPO / "scripts/neobrix-ai"


class AiCollectorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        self.env = os.environ.copy()
        self.env.update({
            "NEOBRIX_AI_HOME": str(self.home),
            "XDG_STATE_HOME": str(self.root / "state"),
            "PATH": str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
        })

    def tearDown(self):
        self.temp.cleanup()

    def executable(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return path

    def cursor_db(self):
        path = self.home / ".config/Cursor/User/globalStorage/state.vscdb"
        path.parent.mkdir(parents=True)
        db = sqlite3.connect(path)
        db.execute("CREATE TABLE ItemTable (key TEXT UNIQUE, value BLOB)")
        db.executemany("INSERT INTO ItemTable VALUES (?, ?)", [
            ("cursorAuth/cachedEmail", "person@example.test"),
            ("cursorAuth/stripeMembershipType", "pro_plus"),
            ("cursorAuth/stripeSubscriptionStatus", "active"),
            ("cursorAuth/accessToken", "CURSOR_SECRET_MUST_NOT_LEAK"),
        ])
        db.commit()
        db.close()
        tracking = self.home / ".cursor/ai-tracking/ai-code-tracking.db"
        tracking.parent.mkdir(parents=True)
        db = sqlite3.connect(tracking)
        db.execute("CREATE TABLE ai_code_hashes (timestamp INTEGER, conversationId TEXT, model TEXT)")
        db.execute("CREATE TABLE conversation_summaries (conversationId TEXT PRIMARY KEY, title TEXT, model TEXT, updatedAt INTEGER)")
        db.execute("INSERT INTO conversation_summaries VALUES (?, ?, ?, ?)",
                   ("cursor-session", "Improve the AI tab", "composer-1", 2000000000000))
        db.commit()
        db.close()

    def run_collector(self, *args):
        result = subprocess.run(
            [str(COLLECTOR), *(args or ("refresh",))], env=self.env,
            text=True, capture_output=True, check=True, timeout=15,
        )
        return result.stdout, json.loads(result.stdout)

    def test_offline_record_is_normalized_and_never_contains_credentials(self):
        self.executable("codex", "#!/bin/sh\nexit 0\n")
        self.executable("claude", "#!/bin/sh\nexit 0\n")
        self.executable("cursor", "#!/bin/sh\nexit 0\n")
        self.cursor_db()

        claude = self.home / ".claude"
        project = claude / "projects/example"
        project.mkdir(parents=True)
        (claude / ".credentials.json").write_text(json.dumps({"claudeAiOauth": {
            "accessToken": "CLAUDE_SECRET_MUST_NOT_LEAK",
            "subscriptionType": "team",
        }}))
        event = {
            "type": "assistant", "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
            "message": {"id": "same-message", "role": "assistant", "model": "claude-test", "usage": {"input_tokens": 10, "output_tokens": 5}},
        }
        # A streamed message may be persisted more than once. It contributes
        # once, keyed by the provider message id.
        prompt = {"type": "user", "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
                  "message": {"role": "user", "content": "Review the new control center"}}
        (project / "session.jsonl").write_text(json.dumps(prompt) + "\n" + json.dumps(event) + "\n" + json.dumps(event) + "\n")
        codex = self.home / ".codex"
        codex.mkdir()
        (codex / "auth.json").write_text('{"access_token":"CODEX_SECRET_MUST_NOT_LEAK"}')
        session = codex / "sessions/2026/08/27/rollout-test.jsonl"
        session.parent.mkdir(parents=True)
        session.write_text("\n".join([
            json.dumps({"timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "type": "session_meta",
                        "payload": {"session_id": "codex-session", "cwd": "/projects/neobrix"}}),
            json.dumps({"timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "type": "turn_context",
                        "payload": {"model": "gpt-test"}}),
            json.dumps({"timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "type": "response_item",
                        "payload": {"type": "message", "role": "user",
                                    "content": [{"type": "input_text", "text": "Fix the session browser"}]}}),
        ]) + "\n")

        self.env["NEOBRIX_AI_OFFLINE"] = "1"
        raw, payload = self.run_collector()
        self.assertEqual(payload["schemaVersion"], 2)
        self.assertEqual([item["id"] for item in payload["providers"]], ["codex", "claude", "cursor"])
        cursor = payload["providers"][2]
        self.assertEqual(cursor["plan"], "Pro Plus")
        self.assertEqual(cursor["status"], "Active")
        claude_record = payload["providers"][1]
        self.assertEqual(claude_record["activity"]["todayTokens"], 15)
        self.assertEqual(claude_record["sessions"][0]["id"], "session")
        self.assertEqual(claude_record["sessions"][0]["label"], "Review the new control center")
        codex_record = payload["providers"][0]
        self.assertEqual(codex_record["sessions"][0]["id"], "codex-session")
        self.assertEqual(codex_record["sessions"][0]["label"], "Fix the session browser")
        self.assertEqual(cursor["sessions"][0]["label"], "Improve the AI tab")
        self.assertNotIn("SECRET_MUST_NOT_LEAK", raw)
        state = Path(self.env["XDG_STATE_HOME"]) / "neobrix/ai.json"
        self.assertEqual(stat.S_IMODE(state.stat().st_mode), 0o600)
        self.assertEqual(json.loads(state.read_text()), payload)

    def test_codex_app_server_supplies_plan_and_limit(self):
        self.executable("codex", """#!/usr/bin/env python3
import json, sys
for line in sys.stdin:
    request = json.loads(line)
    if "id" not in request:
        continue
    method = request["method"]
    result = {}
    if method == "initialize": result = {"userAgent": "test"}
    if method == "account/read": result = {"account": {"type": "chatgpt", "planType": "plus"}}
    if method == "account/rateLimits/read": result = {"rateLimits": {"planType": "plus", "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 2000000000}}}
    print(json.dumps({"id": request["id"], "result": result}), flush=True)
""")
        stdout, payload = self.run_collector()
        codex = payload["providers"][0]
        self.assertTrue(codex["authenticated"])
        self.assertEqual(codex["plan"], "Plus")
        self.assertEqual(codex["limits"][0]["label"], "5-hour")
        self.assertEqual(codex["limits"][0]["usedPercent"], 25)

    def test_show_returns_the_last_atomic_snapshot(self):
        self.env["NEOBRIX_AI_OFFLINE"] = "1"
        _, refreshed = self.run_collector()
        _, shown = self.run_collector("show")
        self.assertEqual(shown, refreshed)


if __name__ == "__main__":
    unittest.main()
