// AI subscriptions and local activity, normalized by neobrix-ai.  Account
// quotas and this machine's activity are labelled separately on purpose: local
// token totals are not a substitute for a vendor's billing meter.

import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root
    property bool active: false
    onActiveChanged: { if (active) Ai.refresh(); }

    function compact(value) {
        const n = Number(value || 0);
        if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M";
        if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K";
        return String(n);
    }

    function resetText(value) {
        if (!value) return "";
        const when = new Date(value);
        if (isNaN(when.getTime())) return "";
        const delta = when.getTime() - Date.now();
        if (delta <= 0) return "resetting";
        const hours = Math.ceil(delta / 3600000);
        if (hours < 24) return "resets in " + hours + "h";
        return "resets in " + Math.ceil(hours / 24) + "d";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            ColumnLayout {
                spacing: 0
                Text {
                    text: "AI ACCOUNTS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    color: Theme.foreground
                }
                Text {
                    text: "Vendor limits and activity recorded on this machine"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: Ai.error !== ""
                text: Ai.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.error
            }

            BrixButton {
                text: Ai.refreshing ? "REFRESHING" : "REFRESH"
                icon: "󰑐"
                fontSize: Theme.fontXs
                enabled: !Ai.refreshing
                accent: Theme.surface
                onClicked: Ai.refresh()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: Theme.spaceSm
            rowSpacing: Theme.spaceSm

            Repeater {
                model: Ai.providers

                delegate: BrixCard {
                    id: card
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    radius: Theme.radiusMd
                    color: Theme.surface
                    shadowOffset: Theme.shadowSm
                    opacity: modelData.installed ? 1 : 0.62

                    readonly property color providerColor: modelData.id === "codex" ? Theme.tertiary
                                                          : modelData.id === "claude" ? Theme.primary
                                                          : Theme.info
                    readonly property string providerIcon: modelData.id === "codex" ? "󱙺"
                                                           : modelData.id === "claude" ? "󰚩" : "󰨞"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceMd
                        spacing: Theme.spaceSm

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceSm
                            BrixCard {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: Theme.radiusSm
                                color: card.providerColor
                                shadowOffset: Theme.shadowSm
                                Text {
                                    anchors.centerIn: parent
                                    text: card.providerIcon
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXl
                                    color: Theme.textOn(card.providerColor)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.name.toUpperCase()
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontMd
                                    font.weight: Theme.weightHeavy
                                    color: Theme.foreground
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !card.modelData.installed ? "NOT INSTALLED"
                                          : card.modelData.plan !== ""
                                            ? card.modelData.plan.toUpperCase()
                                              + (card.modelData.status !== "" && card.modelData.status !== "Ready"
                                                 ? " · " + card.modelData.status.toUpperCase() : "")
                                            : card.modelData.status.toUpperCase()
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Theme.weightHeavy
                                    color: /past due|failed/i.test(card.modelData.status) ? Theme.error
                                         : card.modelData.authenticated ? card.providerColor : Theme.foregroundDim
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.accountLabel !== ""
                            text: card.modelData.accountLabel
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightBold
                            color: Theme.foregroundDim
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs
                            visible: card.modelData.limits.length > 0

                            Repeater {
                                model: card.modelData.limits
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label.toUpperCase()
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightHeavy
                                            color: Theme.foreground
                                        }
                                        Text {
                                            text: Math.round(modelData.usedPercent) + "%"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightHeavy
                                            color: card.providerColor
                                        }
                                    }
                                    BrixProgress {
                                        Layout.fillWidth: true
                                        value: modelData.usedPercent / 100
                                        accent: card.providerColor
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignRight
                                        text: root.resetText(modelData.resetsAt)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontXs
                                        font.weight: Theme.weightBold
                                        color: Theme.foregroundDim
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.limits.length === 0
                            text: card.modelData.id === "cursor" && card.modelData.authenticated
                                  ? "EXACT USAGE IS AVAILABLE IN CURSOR'S DASHBOARD"
                                  : card.modelData.status.toUpperCase()
                            wrapMode: Text.WordWrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightHeavy
                            color: Theme.foregroundDim
                        }

                        Item { Layout.fillHeight: true }

                        BrixCard {
                            Layout.fillWidth: true
                            implicitHeight: activityLayout.implicitHeight + Theme.spaceSm * 2
                            radius: Theme.radiusSm
                            color: Theme.surfaceAlt
                            shadowOffset: 0
                            ColumnLayout {
                                id: activityLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spaceSm
                                spacing: Theme.spaceXs
                                Text {
                                    text: "THIS MACHINE"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Theme.weightHeavy
                                    color: Theme.foregroundDim
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text {
                                            text: card.modelData.id === "cursor"
                                                  ? card.modelData.activity.todaySessions
                                                  : root.compact(card.modelData.activity.todayTokens)
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontLg
                                            font.weight: Theme.weightHeavy; color: card.providerColor
                                        }
                                        Text {
                                            text: card.modelData.id === "cursor" ? "TODAY SESSIONS" : "TOKENS TODAY"
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightBold; color: Theme.foregroundDim
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text {
                                            text: card.modelData.activity.weekSessions
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontLg
                                            font.weight: Theme.weightHeavy; color: Theme.foreground
                                        }
                                        Text {
                                            text: "7-DAY SESSIONS"
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightBold; color: Theme.foregroundDim
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs
                            BrixButton {
                                Layout.fillWidth: true
                                text: "OPEN"
                                icon: "󰆍"
                                fontSize: Theme.fontXs
                                enabled: card.modelData.installed
                                accent: card.providerColor
                                onClicked: Ai.launch(card.modelData.id)
                            }
                            BrixIconButton {
                                visible: card.modelData.dashboardUrl !== ""
                                icon: "󰖟"
                                tooltip: "Open usage dashboard"
                                accent: Theme.surfaceAlt
                                onClicked: Ai.openDashboard(card.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
