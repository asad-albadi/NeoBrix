// Vertical slider — the tall level columns from the Neobrix dashboard.
// Fills from the bottom; value is normalised 0..1.

import QtQuick
import qs.Theme

Item {
    id: root

    property real value: 0
    property color accent: Theme.primary
    property int trackWidth: 26
    property real wheelStep: 0.05
    property bool enabled: true

    signal moved(real value)

    implicitWidth: trackWidth
    implicitHeight: 90
    opacity: enabled ? 1 : 0.45

    function commit(my) {
        const v = 1 - Math.max(0, Math.min(1, my / Math.max(1, track.height)));
        root.moved(v);
    }

    BrixCard {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.trackWidth
        height: parent.height
        radius: Theme.radiusSm
        color: Theme.surface
        shadowOffset: Theme.shadowSm
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: track.border.width
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, track.width - track.border.width * 2)
            height: Math.round(Math.max(0, Math.min(1, root.value))
                               * Math.max(0, track.height - track.border.width * 2))
            color: root.accent
            antialiasing: true
            Behavior on height { NumberAnimation { duration: Theme.durFast } }
        }

        // Grip line so the column reads as interactive even when nearly empty.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((1 - root.value) * track.height) - height / 2
            width: parent.width
            height: Theme.borderThick
            color: Theme.outline
            visible: root.value > 0.02 && root.value < 0.98
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mev => root.commit(mev.y)
        onPositionChanged: mev => { if (pressed) root.commit(mev.y); }
        onWheel: wev => {
            const dir = wev.angleDelta.y > 0 ? 1 : -1;
            root.moved(Math.max(0, Math.min(1, root.value + dir * root.wheelStep)));
        }
    }
}
