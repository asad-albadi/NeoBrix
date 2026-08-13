// Shared window archetype for every panel in the shell.
//
// A full-screen overlay layer surface so that "click anywhere else to dismiss"
// and Escape both work reliably, with the payload aligned to one edge/corner.
// The window is only mapped while open (plus a short close animation), so a
// closed panel costs nothing but an unmapped surface.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Services

PanelWindow {
    id: root

    default property alias content: body.data

    // Which entry in the Panels singleton this window is. Setting this is what
    // makes the panel openable; `open` is derived from it and must never be
    // assigned to.
    //
    // An earlier version had each panel write `open: Panels.isOpen("control")`
    // and a close() that did `root.open = false`. That assignment *destroys* the
    // binding, so after the first Escape or click-outside the window stopped
    // tracking the singleton and could never open again — while the X button,
    // which goes through Panels, kept working. Routing every close through
    // Panels keeps the binding intact.
    property string panel: ""

    readonly property bool open: panel !== "" && Panels.isOpen(panel)

    // center | topRight | topLeft | topCenter | bottomCenter
    property string alignment: "center"
    property bool scrimEnabled: true
    property bool closeOnClickOutside: true
    property int edgeMargin: Theme.barExclusive + Theme.spaceSm
    property int sideMargin: Theme.barMargin + Theme.spaceSm
    property int contentWidth: 400
    property int contentHeight: 300

    signal panelClosed()
    signal panelOpened()

    function close() { if (root.open) Panels.close(); }
    function toggle() { Panels.toggle(root.panel); }

    // The window stays mapped for the length of the close animation.
    //
    // This is set imperatively rather than bound to `open || closeTimer.running`:
    // with that binding QML re-evaluates `rendered` as soon as `open` goes false —
    // *before* onOpenChanged gets to start the timer — so every close unmapped the
    // layer surface, remapped it a moment later when the timer started, then
    // unmapped it again. That map/unmap/map/unmap thrash eventually wedged the
    // surface: the panel's state said "open" while nothing was ever shown again
    // until the shell restarted.
    property bool rendered: false
    visible: rendered

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "neobrix-popup"

    // While closing, the surface is still mapped but must not swallow clicks —
    // otherwise every panel eats input across the whole screen for the duration of
    // its fade-out, which reads as "the bar ignored my click".
    mask: open ? null : closedMask
    Region { id: closedMask }

    onOpenChanged: {
        if (open) {
            closeTimer.stop();
            rendered = true;
            keyCatcher.forceActiveFocus();
            panelOpened();
        } else {
            closeTimer.restart();
            panelClosed();
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.durNormal
        onTriggered: root.rendered = false
    }

    // Scrim / click-outside catcher.
    Rectangle {
        anchors.fill: parent
        color: root.scrimEnabled ? Theme.scrim : "transparent"
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

        MouseArea {
            anchors.fill: parent
            onClicked: { if (root.closeOnClickOutside) root.close(); }
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Item {
        id: holder
        width: root.contentWidth
        height: root.contentHeight

        // Positioning per alignment mode.
        anchors.horizontalCenter: (root.alignment === "center"
                                   || root.alignment === "topCenter"
                                   || root.alignment === "bottomCenter")
                                  ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.alignment === "center" ? parent.verticalCenter : undefined
        anchors.top: root.alignment.startsWith("top") ? parent.top : undefined
        anchors.topMargin: root.alignment.startsWith("top") ? root.edgeMargin : 0
        anchors.bottom: root.alignment === "bottomCenter" ? parent.bottom : undefined
        anchors.bottomMargin: root.alignment === "bottomCenter" ? root.edgeMargin : 0
        anchors.right: root.alignment === "topRight" ? parent.right : undefined
        anchors.rightMargin: root.alignment === "topRight" ? root.sideMargin : 0
        anchors.left: root.alignment === "topLeft" ? parent.left : undefined
        anchors.leftMargin: root.alignment === "topLeft" ? root.sideMargin : 0

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.95
        transformOrigin: root.alignment === "topRight" ? Item.TopRight
                       : root.alignment === "topLeft" ? Item.TopLeft
                       : Item.Center

        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }

        Item {
            id: body
            anchors.fill: parent
        }
    }
}
