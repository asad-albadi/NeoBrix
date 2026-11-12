import QtQuick
import QtTest
import Quickshell
import qs.Components
import qs.Services
import qs.Panels
import qs.Notifications

ShellRoot {
    id: shell
    property int defaults: 0
    property int actions: 0
    property int dismissed: 0
    property int childEscapes: 0
    readonly property string scenario: Quickshell.env("NEOBRIX_INPUT_CASE")

    ClipboardPanel { id: clipboard }

    BrixPopup {
        id: popup
        panel: "escape"
        contentWidth: 250
        contentHeight: 100
        TextInput {
            id: childInput
            anchors.fill: parent
            text: "Synthetic profile name"
            Keys.onEscapePressed: event => {
                if (shell.scenario === "escape_child" && shell.childEscapes === 0) {
                    shell.childEscapes++;
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
        }
    }

    QtObject {
        id: defaultAction
        readonly property string identifier: "default"
        readonly property string text: ""
        function invoke() { shell.defaults++ }
    }
    QtObject {
        id: buttonAction
        readonly property string identifier: "synthetic"
        readonly property string text: "Run synthetic action"
        function invoke() { shell.actions++ }
    }
    QtObject {
        id: syntheticNotification
        readonly property var actions: [defaultAction, buttonAction]
        readonly property string appName: "Synthetic sender"
        readonly property string summary: "Synthetic summary"
        readonly property string body: '<a href="https://example.org/synthetic">Synthetic link</a>'
        readonly property string appIcon: ""
        readonly property string desktopEntry: ""
        readonly property string image: ""
    }
    QtObject {
        id: syntheticWrapper
        readonly property var notification: syntheticNotification
        readonly property string urgency: "normal"
        readonly property string ageText: "now"
    }

    FloatingWindow {
        id: toast
        visible: shell.scenario.indexOf("notification_") === 0
        implicitWidth: 360
        implicitHeight: 320
        NotificationItem {
            id: card
            width: 350
            wrapper: syntheticWrapper
            popup: true
            onDismissed: shell.dismissed++
        }
    }

    TestCase {
        id: checks
        name: "RuntimeInputs"
        when: false

        function find(item, predicate) {
            if (predicate(item)) return item;
            for (const child of item.children || []) {
                const match = find(child, predicate);
                if (match) return match;
            }
            return null;
        }

        function equal(actual, expected, message) {
            if (actual !== expected)
                throw new Error((message || "Unexpected value") + ": expected " + expected + ", got " + actual);
        }
        function ensure(value, message) { if (!value) throw new Error(message); }

        function exercise() {
            try {
                if (shell.scenario.indexOf("clipboard_") === 0) {
                    Panels.open("clipboard");
                    wait(150);
                    const target = shell.scenario === "clipboard_delete"
                        ? find(clipboard.contentItem, item => item.icon === "󰅖")
                        : find(clipboard.contentItem, item => item.text === "Synthetic clipboard entry");
                    ensure(target !== null, "clipboard control exists");
                    mouseClick(target, target.width / 2, target.height / 2);
                    if (shell.scenario === "clipboard_delete") {
                        equal(Clip.removed, 1, "Delete must remove the entry");
                        equal(Clip.copied, 0, "Delete must not copy the entry");
                        equal(Panels.current, "clipboard", "Delete must keep history open");
                    } else {
                        equal(Clip.copied, 1, "Row must copy the entry");
                        equal(Clip.removed, 0);
                        equal(Panels.current, "");
                    }
                } else if (shell.scenario.indexOf("escape") === 0) {
                    Panels.open("escape");
                    wait(150);
                    childInput.forceActiveFocus();
                    ensure(childInput.activeFocus, "child input has focus");
                    keyClick(Qt.Key_Escape);
                    if (shell.scenario === "escape_child") {
                        equal(shell.childEscapes, 1);
                        equal(Panels.current, "escape", "Child handlers may consume Escape first");
                        keyClick(Qt.Key_Escape);
                    }
                    equal(Panels.current, "", "Escape must close a popup from its child input");
                    Panels.open("escape");
                    wait(50);
                    childInput.forceActiveFocus();
                    keyClick(Qt.Key_Escape);
                    equal(Panels.current, "", "Popup must remain dismissible after reopening");
                } else {
                    wait(150);
                    let target;
                    if (shell.scenario === "notification_action")
                        target = find(card, item => item.text === "Run synthetic action");
                    else if (shell.scenario === "notification_link")
                        target = find(card, item => item.text === syntheticNotification.body);
                    else
                        target = find(card, item => item.text === "Synthetic summary");
                    ensure(target !== null, "notification control exists");
                    const button = shell.scenario === "notification_middle" ? Qt.MiddleButton : Qt.LeftButton;
                    mouseClick(target, shell.scenario === "notification_link" ? 20 : target.width / 2,
                               target.height / 2, button);
                    wait(50);
                    equal(shell.defaults, shell.scenario === "notification_left" ? 1 : 0,
                            "Only left-clicking the body invokes the default");
                    equal(shell.actions, shell.scenario === "notification_action" ? 1 : 0);
                    equal(shell.dismissed, shell.scenario === "notification_link" ? 0 : 1);
                }
                console.log("RUNTIME_INPUT_PASS " + shell.scenario);
            } catch (error) {
                console.log("RUNTIME_INPUT_FAIL " + shell.scenario + " " + error);
            } finally {
                Qt.quit();
            }
        }
    }

    Timer { interval: 100; running: true; onTriggered: checks.exercise() }
}
