// Displays: arrange the screens, set what each one does, remember it.
//
// Three parts, left to right and top to bottom in order of how often they are
// touched: the arrangement map, the settings for whichever screen is selected,
// and the saved profiles.
//
// Every change goes out through Monitors, which shells out to neobrix-monitors
// with a revert timer. Nothing here talks to Hyprland, and nothing here is
// permanent until it has been confirmed -- the banner at the top is the only way
// a change becomes the saved layout.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    // Set by the control centre while this tab is the visible one, so the layout
    // is re-read only when somebody is looking at it.
    property bool active: false
    onActiveChanged: active ? Monitors.subscribe() : Monitors.unsubscribe()

    property string selected: ""

    readonly property var current: {
        if (root.selected !== "") {
            const m = Monitors.byName(root.selected);
            if (m) return m;
        }
        return Monitors.count > 0 ? Monitors.list[0] : null;
    }

    // Follow hotplug: a screen that goes away should not leave its settings on
    // screen, and the first one is a better default than nothing.
    Connections {
        target: Monitors
        function onListChanged() {
            if (root.selected !== "" && !Monitors.byName(root.selected))
                root.selected = "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceMd

        // ── the unconfirmed-change banner ───────────────────────────────────
        // Deliberately at the top and impossible to miss. The script reverts on
        // its own timer whether or not this is ever seen; this is how you say
        // "keep it" before that happens.
        BrixCard {
            id: banner
            Layout.fillWidth: true
            visible: Monitors.pending || Monitors.lastError !== ""
            Layout.preferredHeight: 44
            radius: Theme.radiusMd
            color: Monitors.lastError !== "" ? Theme.error : Theme.warning
            shadowOffset: Theme.shadowSm

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spaceSm
                spacing: Theme.spaceSm

                Text {
                    Layout.fillWidth: true
                    text: Monitors.lastError !== ""
                          ? Monitors.lastError
                          : "Keep this arrangement?  Reverting in " + Monitors.pendingSeconds + "s"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightHeavy
                    color: Theme.textOn(banner.color)
                }

                BrixButton {
                    visible: Monitors.pending
                    text: "KEEP"
                    fontSize: 9
                    vPadding: 4
                    accent: Theme.secondary
                    behind: banner.color
                    onClicked: Monitors.confirm()
                }

                BrixButton {
                    visible: Monitors.pending
                    text: "REVERT"
                    fontSize: 9
                    vPadding: 4
                    accent: Theme.surface
                    behind: banner.color
                    onClicked: Monitors.revert()
                }

                BrixButton {
                    visible: Monitors.lastError !== "" && !Monitors.pending
                    text: "DISMISS"
                    fontSize: 9
                    vPadding: 4
                    accent: Theme.surface
                    behind: banner.color
                    onClicked: Monitors.lastError = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            // ── left: arrangement, then profiles ────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spaceMd

                BrixCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.surface
                    shadowOffset: Theme.shadowSm

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceSm
                        spacing: Theme.spaceXs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceSm

                            SectionHeader { text: "ARRANGEMENT"; icon: "󰍹"; Layout.fillWidth: true }

                            Text {
                                text: Monitors.count === 1 ? "1 screen"
                                                           : Monitors.count + " screens"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.foregroundDim
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs

                            Text {
                                Layout.fillWidth: true
                                text: Monitors.hasGap
                                      ? "A screen is not touching the others — the pointer cannot cross the gap."
                                      : Monitors.count > 1
                                        ? "Drag to move. Edges and centres snap — hold Ctrl to place freely."
                                        : "Nothing to arrange with one screen."
                                wrapMode: Text.WordWrap
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Monitors.hasGap ? Theme.weightHeavy : Theme.weightBold
                                color: Monitors.hasGap ? Theme.warning : Theme.foregroundDim
                            }

                            BrixButton {
                                visible: Monitors.hasGap
                                text: "TIDY UP"
                                fontSize: 8
                                vPadding: 2
                                accent: Theme.warning
                                behind: Theme.surface
                                onClicked: Monitors.arrange()
                            }
                        }

                        // The map. Positions are logical layout coordinates:
                        // the mode divided by the scale, which is the space a
                        // screen actually takes up next to its neighbours.
                        Item {
                            id: canvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            // A tile dragged past the edge would otherwise paint
                            // over the card and outside the window entirely.
                            clip: true

                            readonly property real pad: 10
                            readonly property real minX: {
                                let v = 0; let first = true;
                                for (const m of Monitors.list) { if (first || m.x < v) { v = m.x; first = false; } }
                                return v;
                            }
                            readonly property real minY: {
                                let v = 0; let first = true;
                                for (const m of Monitors.list) { if (first || m.y < v) { v = m.y; first = false; } }
                                return v;
                            }
                            readonly property real spanX: {
                                let v = 1;
                                for (const m of Monitors.list) v = Math.max(v, m.x + m.logicalWidth - canvas.minX);
                                return v;
                            }
                            readonly property real spanY: {
                                let v = 1;
                                for (const m of Monitors.list) v = Math.max(v, m.y + m.logicalHeight - canvas.minY);
                                return v;
                            }
                            readonly property real factor: Math.min(
                                (width - pad * 2) / spanX, (height - pad * 2) / spanY)

                            // Snap tolerance is measured on the canvas, not in
                            // logical pixels: a fixed logical threshold is a
                            // third of a screen on a wide layout and nothing at
                            // all on a narrow one. 12px under the pointer feels
                            // the same whatever is plugged in.
                            readonly property real tol: 12 / canvas.factor

                            // Every position worth landing on, for the dragged
                            // screen's own leading edge.
                            function candidates(name, size, axis) {
                                const out = [0];   // square up with the layout corner
                                for (const o of Monitors.list) {
                                    if (o.name === name) continue;
                                    const p = axis === "x" ? o.x : o.y;
                                    const s = axis === "x" ? o.logicalWidth : o.logicalHeight;
                                    out.push(p + s,                 // just past it
                                             p - size,              // just before it
                                             p,                     // near edges level
                                             p + s - size,          // far edges level
                                             p + (s - size) / 2);   // centred on it
                                }
                                // Duplicates are common once three screens are
                                // involved, and each one would draw another line
                                // on top of the last.
                                const seen = {};
                                const uniq = [];
                                for (const c of out) {
                                    const k = Math.round(c);
                                    if (seen[k]) continue;
                                    seen[k] = true;
                                    uniq.push(k);
                                }
                                return uniq;
                            }

                            // Nearest wins. Taking the first within tolerance
                            // meant whichever screen came first in the list
                            // decided, which is what made this feel arbitrary.
                            function snapTo(value, cands) {
                                let best = value, bestD = canvas.tol;
                                for (const c of cands) {
                                    const d = Math.abs(c - value);
                                    if (d < bestD) { best = c; bestD = d; }
                                }
                                return Math.round(best);
                            }

                            function toCanvasX(lx) { return pad + (lx - canvas.minX) * canvas.factor; }
                            function toCanvasY(ly) { return pad + (ly - canvas.minY) * canvas.factor; }
                            function toLogicalX(cx) { return (cx - pad) / canvas.factor + canvas.minX; }
                            function toLogicalY(cy) { return (cy - pad) / canvas.factor + canvas.minY; }

                            Repeater {
                                model: Monitors.list

                                delegate: Rectangle {
                                    id: tile
                                    required property var modelData

                                    // Bound at creation and after any change,
                                    // but not while being dragged -- a binding
                                    // would fight the drag and snap it back.
                                    x: canvas.toCanvasX(modelData.x)
                                    y: canvas.toCanvasY(modelData.y)
                                    width: Math.max(28, modelData.logicalWidth * canvas.factor)
                                    height: Math.max(20, modelData.logicalHeight * canvas.factor)

                                    radius: Theme.radiusXs
                                    color: modelData.disabled ? Theme.surfaceDeep
                                         : root.current && root.current.name === modelData.name
                                           ? Theme.primary : Theme.surfaceAlt
                                    border.width: 2
                                    border.color: modelData.focused ? Theme.secondary : Theme.outline

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 0

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: tile.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Theme.weightHeavy
                                            color: Theme.textOn(tile.color)
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: tile.height > 34
                                            text: tile.modelData.disabled
                                                  ? "off"
                                                  : tile.modelData.logicalWidth + "×" + tile.modelData.logicalHeight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            color: Theme.textOn(tile.color)
                                            opacity: 0.75
                                        }
                                        // The tile already turns on its side when
                                        // a screen is rotated, since it is drawn
                                        // from the real footprint. This says which
                                        // way, which the shape alone cannot.
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: tile.height > 48
                                                     && Monitors.rotationLabel(tile.modelData.transform) !== ""
                                            text: Monitors.rotationLabel(tile.modelData.transform)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            font.weight: Theme.weightHeavy
                                            color: Theme.textOn(tile.color)
                                            opacity: 0.9
                                        }
                                    }

                                    // Dragging is done by hand rather than with
                                    // drag.target. The target's x/y turned out
                                    // not to be in this canvas's coordinate
                                    // space -- a release reported x=968 inside a
                                    // canvas 498 wide, which put a screen at
                                    // 5776,3615 -- so the pointer is mapped into
                                    // the canvas explicitly and the tile is
                                    // moved from that. No ambiguity about whose
                                    // frame anything is in.
                                    MouseArea {
                                        id: ma
                                        anchors.fill: parent
                                        cursorShape: Monitors.count > 1 ? Qt.SizeAllCursor
                                                                        : Qt.PointingHandCursor

                                        property real grabX: 0
                                        property real grabY: 0
                                        property bool dragging: false

                                        function rebind() {
                                            tile.x = Qt.binding(() => canvas.toCanvasX(tile.modelData.x));
                                            tile.y = Qt.binding(() => canvas.toCanvasY(tile.modelData.y));
                                        }

                                        onPressed: mouse => {
                                            root.selected = tile.modelData.name;
                                            if (Monitors.count < 2) return;
                                            const p = ma.mapToItem(canvas, mouse.x, mouse.y);
                                            ma.grabX = p.x - tile.x;
                                            ma.grabY = p.y - tile.y;
                                            ma.dragging = true;
                                        }

                                        onPositionChanged: mouse => {
                                            if (!ma.dragging) return;
                                            const p = ma.mapToItem(canvas, mouse.x, mouse.y);
                                            tile.x = p.x - ma.grabX;
                                            tile.y = p.y - ma.grabY;
                                        }

                                        onCanceled: {
                                            ma.dragging = false;
                                            ma.rebind();
                                        }

                                        onReleased: mouse => {
                                            if (!ma.dragging) return;
                                            ma.dragging = false;

                                            const lx0 = canvas.toLogicalX(tile.x);
                                            const ly0 = canvas.toLogicalY(tile.y);
                                            const w = tile.modelData.logicalWidth;
                                            const h = tile.modelData.logicalHeight;

                                            // Ctrl means "leave it exactly where I
                                            // put it". Snapping is a convenience,
                                            // not a rule.
                                            const free = (mouse.modifiers & Qt.ControlModifier) !== 0;
                                            const lx = free ? Math.round(lx0)
                                                : canvas.snapTo(lx0, canvas.candidates(tile.modelData.name, w, "x"));
                                            const ly = free ? Math.round(ly0)
                                                : canvas.snapTo(ly0, canvas.candidates(tile.modelData.name, h, "y"));

                                            ma.rebind();
                                            if (lx === tile.modelData.x && ly === tile.modelData.y)
                                                return;

                                            // place() rather than set(): a drop on
                                            // the left is a negative coordinate, and
                                            // the layout is shifted back to the
                                            // origin afterwards.
                                            Monitors.place(tile.modelData.name, lx, ly);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── profiles ────────────────────────────────────────────────
                BrixCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    radius: Theme.radiusMd
                    color: Theme.surface
                    shadowOffset: Theme.shadowSm

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceSm
                        spacing: Theme.spaceXs

                        SectionHeader { text: "PROFILES"; icon: "󰆓"; Layout.fillWidth: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs

                            BrixCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: Theme.radiusXs
                                color: Theme.surfaceAlt
                                shadowOffset: 0

                                TextInput {
                                    id: profileName
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceXs
                                    anchors.rightMargin: Theme.spaceXs
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    color: Theme.foreground
                                    selectionColor: Theme.primary
                                    selectedTextColor: Theme.onAccent
                                    clip: true
                                    onAccepted: { Monitors.save(text); text = ""; }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        visible: profileName.text === ""
                                        text: "Name this arrangement"
                                        font: profileName.font
                                        color: Theme.foregroundDim
                                    }
                                }
                            }

                            BrixButton {
                                text: Monitors.currentSetSaved ? "UPDATE" : "SAVE"
                                fontSize: 9
                                vPadding: 4
                                accent: Theme.secondary
                                behind: Theme.surface
                                onClicked: { Monitors.save(profileName.text); profileName.text = ""; }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: Monitors.profiles
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 2

                            delegate: RowLayout {
                                required property var modelData
                                width: ListView.view ? ListView.view.width : 0
                                spacing: Theme.spaceXs

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.modelData.name
                                          + (parent.modelData.fingerprint === Monitors.fingerprint
                                             ? "  ·  in use now" : "")
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Theme.weightBold
                                    color: Theme.foreground
                                }

                                BrixButton {
                                    text: "APPLY"
                                    fontSize: 8
                                    vPadding: 2
                                    accent: Theme.surfaceAlt
                                    behind: Theme.surface
                                    onClicked: Monitors.applyProfile(parent.modelData.name)
                                }

                                BrixButton {
                                    text: "FORGET"
                                    fontSize: 8
                                    vPadding: 2
                                    accent: Theme.error
                                    behind: Theme.surface
                                    onClicked: Monitors.forget(parent.modelData.name)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: Monitors.profiles.length === 0
                            text: "Nothing saved yet. A profile remembers this set of screens and comes back when they do."
                            wrapMode: Text.WordWrap
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            color: Theme.foregroundDim
                        }
                    }
                }
            }

            // ── right: the selected screen ──────────────────────────────────
            BrixCard {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    SectionHeader {
                        text: root.current ? root.current.name : "NO SCREEN"
                        icon: "󰍺"
                        Layout.fillWidth: true
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.current !== null
                        text: {
                            if (!root.current) return "";
                            const m = root.current;
                            const dpi = Monitors.dpiOf(m);
                            const bits = [];
                            if (m.make || m.model) bits.push((m.make + " " + m.model).trim());
                            if (dpi) bits.push(dpi + " dpi");
                            if (m.physicalWidth) bits.push(Math.round(m.physicalWidth / 25.4 * 10) / 10 + "″ wide");
                            return bits.join("  ·  ");
                        }
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }

                    // ── mode ────────────────────────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXs
                        text: "RESOLUTION AND REFRESH"
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Theme.weightHeavy
                        color: Theme.foregroundDim
                    }

                    BrixSelect {
                        Layout.fillWidth: true
                        enabled: root.current !== null && !root.current.disabled
                        options: {
                            if (!root.current) return [];
                            const out = [];
                            const seen = {};
                            for (const m of root.current.modes) {
                                if (seen[m]) continue;
                                seen[m] = true;
                                // "1920x1080@144.00Hz" reads better as
                                // "1920 × 1080  ·  144 Hz".
                                const res = m.split("@")[0];
                                const hz = parseFloat((m.split("@")[1] || "").replace("Hz", ""));
                                out.push({
                                    label: res.replace("x", " × ") + "  ·  " + Math.round(hz) + " Hz",
                                    value: res + "@" + (Math.round(hz * 100) / 100),
                                });
                            }
                            return out;
                        }
                        value: root.current
                               ? root.current.width + "x" + root.current.height + "@"
                                 + (Math.round(root.current.refreshRate * 100) / 100)
                               : undefined
                        onPicked: v => Monitors.set(root.current.name, { mode: v })
                    }

                    // ── scale ───────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXs
                        spacing: Theme.spaceXs

                        Text {
                            Layout.fillWidth: true
                            text: "SCALE"
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Theme.weightHeavy
                            color: Theme.foregroundDim
                        }

                        Text {
                            visible: root.current !== null
                                     && Monitors.suggestedScale(root.current) !== root.current.scale
                            text: "suggested " + (root.current
                                  ? Monitors.scaleLabel(Monitors.suggestedScale(root.current)) : "")
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            color: Theme.foregroundDim
                        }
                    }

                    BrixSelect {
                        Layout.fillWidth: true
                        enabled: root.current !== null && !root.current.disabled
                        options: root.current ? Monitors.validScales(root.current.width, root.current.height) : []
                        value: root.current ? root.current.scale : undefined
                        onPicked: v => Monitors.set(root.current.name, { scale: v })
                    }

                    // ── rotation ────────────────────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXs
                        text: "ROTATION"
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Theme.weightHeavy
                        color: Theme.foregroundDim
                    }

                    BrixSelect {
                        Layout.fillWidth: true
                        enabled: root.current !== null && !root.current.disabled
                        options: Monitors.transformOptions
                        value: root.current ? root.current.transform : undefined
                        onPicked: v => Monitors.set(root.current.name, { transform: v })
                    }

                    // ── mirror ──────────────────────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXs
                        visible: Monitors.count > 1
                        text: "MIRROR"
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Theme.weightHeavy
                        color: Theme.foregroundDim
                    }

                    BrixSelect {
                        Layout.fillWidth: true
                        visible: Monitors.count > 1
                        enabled: root.current !== null && !root.current.disabled
                        options: {
                            const out = [{ label: "Not mirroring", value: "none" }];
                            if (!root.current) return out;
                            for (const m of Monitors.list)
                                if (m.name !== root.current.name)
                                    out.push({ label: "Mirror of " + m.name, value: m.name });
                            return out;
                        }
                        value: root.current && root.current.mirrorOf !== "" ? root.current.mirrorOf : "none"
                        onPicked: v => Monitors.set(root.current.name, { mirror: v })
                    }

                    Item { Layout.fillHeight: true }

                    // ── switches ────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Text {
                            Layout.fillWidth: true
                            text: "VARIABLE REFRESH"
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Theme.weightHeavy
                            color: Theme.foregroundDim
                        }

                        BrixToggle {
                            checked: root.current ? root.current.vrr : false
                            onToggled: on => Monitors.set(root.current.name, { vrr: on ? 1 : 0 })
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "SCREEN ON"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Theme.weightHeavy
                                color: Theme.foregroundDim
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: root.enabledCount < 2 && root.current && !root.current.disabled
                                text: "the only screen left on"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.foregroundDim
                            }
                        }

                        BrixToggle {
                            // Turning off the last screen leaves a machine with
                            // no output and no way to click anything, so it is
                            // simply not offered.
                            enabled: root.current !== null
                                     && (root.current.disabled || root.enabledCount > 1)
                            checked: root.current ? !root.current.disabled : false
                            onToggled: on => Monitors.set(root.current.name,
                                                          { disabled: on ? "false" : "true" })
                        }
                    }
                }
            }
        }
    }

    readonly property int enabledCount: {
        let n = 0;
        for (const m of Monitors.list) if (!m.disabled) n++;
        return n;
    }
}
