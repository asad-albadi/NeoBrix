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
    // center | topCenter | bottomCenter | topLeft | topRight | topAnchor
    property string alignment: "center"
    // topAnchor only: screen x to centre the card under.
    property real anchorX: 0
    property bool scrimEnabled: true
    property bool closeOnClickOutside: true
    // Leave the bar itself clickable while this is open. Without it the popup's
    // full-screen surface swallows the first click on any other indicator, so
    // moving from one popover to its neighbour took two clicks — one to dismiss,
    // one to open — and read as the bar ignoring the first.
    property bool barClickThrough: alignment === "topAnchor"
    property int edgeMargin: Theme.barExclusive + Theme.spaceSm
    property int sideMargin: Theme.barMargin + Theme.spaceSm
    property int contentWidth: 400
    property int contentHeight: 300

    // Centred under anchorX, but never off-screen: a popover under the last
    // indicator would otherwise hang past the right edge.
    readonly property int anchoredX: Math.round(Math.max(sideMargin,
        Math.min(anchorX - contentWidth / 2, width - contentWidth - sideMargin)))

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
    mask: open ? (root.barClickThrough ? barlessMask : null) : closedMask
    Region { id: closedMask }

    // Everything below the bar, so a click on the bar itself reaches the bar.
    //
    // Expressed as one rectangle rather than the screen minus a subtracted
    // strip: a nested Region with Intersection.Subtract had no observable
    // effect here — clicks in the cut-out area were still taken by this
    // surface, tested up to a 400px strip — and the bar spans the full width at
    // the top, so what is wanted is a single rect anyway.
    Region {
        id: barlessMask
        x: 0
        y: Theme.barExclusive
        width: root.width
        height: Math.max(0, root.height - Theme.barExclusive)
    }

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
        anchors.left: (root.alignment === "topLeft" || root.alignment === "topAnchor")
                      ? parent.left : undefined
        anchors.leftMargin: root.alignment === "topAnchor" ? root.anchoredX
                          : root.alignment === "topLeft" ? root.sideMargin : 0

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.95
        transformOrigin: root.alignment === "topRight" ? Item.TopRight
                       : root.alignment === "topLeft" ? Item.TopLeft
                       : root.alignment === "topAnchor" ? Item.Top
                       : Item.Center

        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }

        // Everything inside the panel belongs to the panel.
        //
        // Only interactive items consume mouse events, so a click on a card, a
        // heading, or the gap between two controls fell straight through to the
        // scrim below and dismissed the window. That made the panel feel like it
        // closed at random, and made dragging, typing or picking from a list a
        // matter of hitting exactly the right pixel.
        //
        // Declared before `body`, so it sits underneath it: real controls still
        // get the event first, and this catches only what nothing else wanted.
        // Wheel events are untouched -- MouseArea does not handle them -- so
        // lists inside the panel still scroll.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: body
            anchors.fill: parent
        }
    }
}
