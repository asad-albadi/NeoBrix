import pathlib
import unittest


REPO = pathlib.Path(__file__).resolve().parents[1]
ROW_SOURCE = (REPO / "quickshell/Panels/ConnectivityTab.qml").read_text()


class BluetoothConnectionRowTest(unittest.TestCase):
    def test_connect_action_is_single_flight_with_a_long_grace_period(self):
        """A slow BlueZ connection must not invite a duplicate UI request."""
        self.assertIn("property bool connectPending: false", ROW_SOURCE)
        self.assertIn("function requestConnection()", ROW_SOURCE)
        self.assertIn("if (!btRow.dev || btRow.dev.connected || btRow.connectPending) return;", ROW_SOURCE)
        self.assertIn("id: connectGraceTimer", ROW_SOURCE)
        self.assertIn("interval: 45000", ROW_SOURCE)
        self.assertIn("enabled: btRow.dev && !btRow.connectPending", ROW_SOURCE)
        self.assertIn(
            "onClicked: btRow.dev.connected ? btRow.dev.disconnect() : btRow.requestConnection()",
            ROW_SOURCE,
        )


if __name__ == "__main__":
    unittest.main()
