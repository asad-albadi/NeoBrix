// Horizontal slider. Value is normalised 0..1.
//
// Emits `moved` on drag/click/wheel rather than writing `value` itself, so the
// owner stays the single source of truth (important when the backing value comes
// from PipeWire and can change underneath us).

import QtQuick
import qs.Theme

Item {
    id: root

    property real value: 0
    property color accent: Theme.primary
    property int trackHeight: 16
    property real wheelStep: 0.05
    property bool enabled: true

    signal moved(real value)

    implicitHeight: trackHeight
    implicitWidth: 120
    opacity: enabled ? 1 : 0.45

    function commit(mx) {
        const v = Math.max(0, Math.min(1, mx / Math.max(1, track.width)));
        root.moved(v);
    }

    BrixCard {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: Theme.radiusPill
        color: Theme.surfaceDeep
        shadowOffset: Theme.shadowSm

        // Filled portion, inset by the border so it sits inside the outline.
        // (Qt Quick's clip is rectangular, so a square fill would spill over the
        // pill's rounded corners and cover the border.)
        readonly property real inset: border.width

        Rectangle {
            x: track.inset
            y: track.inset
            height: Math.max(0, track.height - track.inset * 2)
            width: Math.max(0, Math.min(1, root.value)) * Math.max(0, track.width - track.inset * 2)
            radius: height / 2
            color: root.accent
            antialiasing: true
        }
    }

    // Handle sits above the track and is not clipped by it.
    BrixCard {
        id: handle
        width: root.trackHeight + 6
        height: root.trackHeight + 6
        radius: Theme.radiusPill
        color: mouse.pressed ? root.accent : Theme.surface
        shadowOffset: mouse.pressed ? 0 : Theme.shadowSm
        border.width: Theme.border
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(root.value * track.width - width / 2)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mev => root.commit(mev.x + 4)
        onPositionChanged: mev => { if (pressed) root.commit(mev.x + 4); }
        onWheel: wev => {
            const dir = wev.angleDelta.y > 0 ? 1 : -1;
            root.moved(Math.max(0, Math.min(1, root.value + dir * root.wheelStep)));
        }
    }
}
