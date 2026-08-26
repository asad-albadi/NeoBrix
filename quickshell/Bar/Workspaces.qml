// Hyprland workspaces — driven entirely by Quickshell's Hyprland IPC binding
// (event socket), never by polling `hyprctl`.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    // Show at least this many slots so the bar geometry does not jump around on
    // a fresh session; Hyprland is configured with 3 persistent workspaces.
    property int minSlots: 3
    property var monitor: null

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barIslandHeight - Theme.spaceSm

    readonly property var hyprWorkspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []

    // Union of "exists in Hyprland" and "always show" slots, restricted to this
    // monitor when the bar is per-monitor. Special workspaces (negative ids) are
    // surfaced separately.
    readonly property var slots: {
        const byId = {};
        for (const ws of root.hyprWorkspaces) {
            if (ws.id < 0) continue;
            if (root.monitor && ws.monitor && ws.monitor.name !== root.monitor.name) continue;
            byId[ws.id] = ws;
        }
        const ids = Object.keys(byId).map(Number);
        const highest = ids.length > 0 ? Math.max.apply(null, ids) : 0;
        const upTo = Math.max(root.minSlots, highest);

        const out = [];
        for (let i = 1; i <= upTo; i++)
            out.push({ id: i, ws: byId[i] || null });
        return out;
    }

    // Most windows are named by their Hyprland class, which is not an icon name:
    // "kitty" and "cursor" resolve straight through the icon theme, "zen" does
    // not — its desktop entry is what knows the icon. heuristicLookup is the
    // fuzzy class-to-entry match built for exactly this, with the class itself
    // as the fallback and a generic icon behind that.
    function iconFor(cls) {
        if (!cls) return "";
        const entry = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : cls,
                                   "application-x-executable");
    }

    readonly property var specialWorkspace: {
        for (const ws of root.hyprWorkspaces)
            if (ws.id < 0 && ws.toplevels && ws.toplevels.values.length > 0) return ws;
        return null;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceSm

        Repeater {
            model: root.slots

            delegate: Item {
                id: slot
                required property var modelData

                readonly property var ws: modelData.ws
                readonly property bool exists: ws !== null
                readonly property bool focused: exists && ws.focused
                readonly property bool active: exists && ws.active
                readonly property bool urgent: exists && ws.urgent
                readonly property var wins: exists && ws.toplevels ? ws.toplevels.values : []
                readonly property int windows: wins.length
                readonly property bool occupied: windows > 0

                // Up to three marks. Beyond that the last one becomes a count,
                // so a workspace with nine windows is still three marks wide and
                // the group cannot run off the island.
                // One expression for the fill, so the ink can be chosen against
                // it instead of guessed. The urgent chip is Theme.error, which
                // is light in dawn and dark in dusk — assuming onAccent put
                // near-black text on a dark red chip in dusk.
                readonly property color chipColor:
                    slot.urgent ? Theme.error
                  : slot.focused ? Theme.primary
                  : slot.occupied ? Theme.surfaceDeep
                  : mouse.containsMouse ? Theme.surface
                  : "transparent"

                readonly property int maxMarks: 3
                readonly property int marks: Math.min(windows, maxMarks)
                readonly property bool overflowing: windows > maxMarks

                // The focused workspace is a wide pill; the rest are square
                // chips. Either grows by its marks — the width is already
                // animated, and the focused chip already changed size, so
                // growing to fit what is open is the behaviour that was there.
                implicitWidth: (focused ? 38 : 24) + marks * 15
                implicitHeight: 24
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing }
                }

                BrixCard {
                    anchors.fill: parent
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    border.width: slot.focused ? Theme.borderThick : Theme.border
                    color: slot.chipColor

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: slot.modelData.id
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            font.weight: slot.focused ? Theme.weightHeavy : Theme.weightBold
                            color: slot.occupied || slot.focused || slot.urgent
                                   ? Theme.textOn(slot.chipColor)
                                   : Theme.foregroundDim
                        }

                        Repeater {
                            model: slot.marks

                            delegate: Item {
                                id: mark
                                required property int index

                                // The last mark stands in for everything past
                                // it, so the count includes itself: two icons
                                // and "+7" for nine windows.
                                readonly property bool isCount:
                                    slot.overflowing && index === slot.marks - 1

                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12

                                readonly property var toplevel:
                                    slot.wins.length > mark.index ? slot.wins[mark.index] : null
                                // The wayland app id arrives with the window and
                                // notifies when it changes. lastIpcObject is what
                                // its name says — the last object from a full
                                // client query — so for a window that has just
                                // opened it is still empty, which is exactly why
                                // a new window's chip grew with no icon in it.
                                // It stays as the fallback, for anything the
                                // wayland handle does not name.
                                readonly property string cls: {
                                    if (!mark.toplevel) return "";
                                    const wl = mark.toplevel.wayland;
                                    if (wl && wl.appId) return wl.appId;
                                    const ipc = mark.toplevel.lastIpcObject;
                                    return ipc && ipc.class ? ipc.class : "";
                                }

                                IconImage {
                                    visible: !mark.isCount
                                    anchors.fill: parent
                                    source: mark.isCount ? "" : root.iconFor(mark.cls)
                                }

                                Text {
                                    visible: mark.isCount
                                    anchors.centerIn: parent
                                    text: "+" + (slot.windows - slot.marks + 1)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Theme.weightBold
                                    color: slot.focused || slot.urgent
                                           ? Theme.textOn(slot.chipColor)
                                           : Theme.foregroundDim
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(slot.modelData.id)
                }

                WorkspacePreview {
                    anchorTarget: slot
                    windows: slot.wins
                    workspaceId: slot.modelData.id
                    triggerHovered: mouse.containsMouse
                    onWindowChosen: toplevel => {
                        if (toplevel && toplevel.address)
                            Hypr.focusWindow(toplevel.address);
                        else
                            Hypr.focusWorkspace(slot.modelData.id);
                    }
                }
            }
        }

        // Scratchpad indicator — only present when the special workspace has
        // something in it.
        BrixCard {
            visible: root.specialWorkspace !== null
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Theme.radiusXs
            shadowOffset: 0
            color: Theme.tertiary

            Text {
                anchors.centerIn: parent
                text: "󰸉"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                color: Theme.onAccent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.toggleSpecialWorkspace()
            }
        }
    }

    // Scroll anywhere on the group to move between workspaces.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wev => {
            Hypr.focusWorkspaceRelative(wev.angleDelta.y > 0 ? "m-1" : "m+1");
        }
    }
}
