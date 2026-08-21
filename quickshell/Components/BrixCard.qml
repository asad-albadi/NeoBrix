// The single primitive every other surface is built from.
//
// A flat filled rectangle, a chunky outline and a *hard offset* shadow (no blur,
// no spread). The shadow is a negative-z child, which Qt Quick paints behind the
// parent, so BrixCard can be dropped straight into any Layout or anchor setup
// exactly like a normal Rectangle.

import QtQuick
import qs.Theme

Rectangle {
    id: root

    // Distance the shadow is offset down-right. 0 disables it.
    property int shadowOffset: Theme.shadowMd
    property color shadowColor: Theme.shadow
    // Set false for inset wells that should read as carved-in rather than raised.
    property bool outlined: true

    color: Theme.surface
    radius: Theme.radiusMd
    border.width: outlined ? Theme.border : 0
    // Overridable, so a control whose fill is dark can ask for an outline that
    // can be seen against it. Cards keep the palette's outline by default.
    property color borderColor: Theme.outline
    border.color: borderColor
    antialiasing: true

    Rectangle {
        z: -1
        x: root.shadowOffset
        y: root.shadowOffset
        width: root.width
        height: root.height
        radius: root.radius
        color: root.shadowColor
        visible: root.shadowOffset > 0
        antialiasing: true
    }
}
