// ─────────────────────────────────────────────────────────────────────────────
//  Control center — the Neobrix "dashboard".
//
//  Two tabs share one window:
//    system        · identity, clock, audio/mic levels, system specs, resources,
//                    media, network, bluetooth, quick actions
//    notifications · the notification centre
//
//  Sampling is reference-counted: SysInfo only reads /proc and Media only ticks
//  its position while this panel is actually open.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "control"
    alignment: "center"
    contentWidth: Math.min(840, screen ? screen.width - Theme.spaceXl * 2 : 840)
    contentHeight: Math.min(520, screen ? screen.height - Theme.barExclusive * 2 : 520)

    onPanelOpened: {
        SysInfo.subscribe();
        Media.subscribePosition();
        SysInfo.refreshPackages();
    }
    onPanelClosed: {
        SysInfo.unsubscribe();
        Media.unsubscribePosition();
    }

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowLg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceMd

            // ── tab strip ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                BrixButton {
                    text: "SYSTEM"
                    icon: "󰒓"
                    fontSize: Theme.fontSm
                    active: Panels.controlTab === "system"
                    activeAccent: Theme.secondary
                    accent: Theme.surface
                    onClicked: Panels.controlTab = "system"
                }

                BrixButton {
                    text: "NOTIFICATIONS"
                    icon: Notifs.count > 0 ? "󱅫" : "󰂚"
                    fontSize: Theme.fontSm
                    active: Panels.controlTab === "notifications"
                    activeAccent: Theme.pink
                    accent: Theme.surface
                    onClicked: {
                        Panels.controlTab = "notifications";
                        Notifs.markAllRead();
                    }
                }

                Item { Layout.fillWidth: true }

                BrixIconButton {
                    icon: Theme.dark ? "󰖨" : "󰖔"
                    tooltip: Theme.dark ? "Switch to light theme" : "Switch to dark theme"
                    accent: Theme.surface
                    onClicked: Theme.toggleMode()
                }

                BrixIconButton {
                    icon: "󰐥"
                    accent: Theme.error
                    iconColor: Theme.onAccent
                    tooltip: "Session"
                    onClicked: Panels.open("session")
                }

                BrixIconButton {
                    icon: "󰅖"
                    accent: Theme.surface
                    tooltip: "Close"
                    onClicked: Panels.close()
                }
            }

            // ── content ─────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SystemTab {
                    anchors.fill: parent
                    visible: Panels.controlTab === "system"
                    active: root.open && visible
                }

                NotificationCenter {
                    anchors.fill: parent
                    visible: Panels.controlTab === "notifications"
                }
            }
        }
    }
}
