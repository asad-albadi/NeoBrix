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
    property double nowMs: Date.now()
    property var selectedProvider: null
    onActiveChanged: { if (active) Ai.refresh(); }

    Timer {
        interval: 30000
        running: root.active
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    function compact(value) {
        const n = Number(value || 0);
        if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M";
        if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K";
        return String(n);
    }

    function resetMoment(value) {
        if (!value) return "";
        const when = new Date(value);
        if (isNaN(when.getTime())) return "";
        return Qt.formatDateTime(when, "ddd d MMM · h:mm AP").toUpperCase();
    }

    function resetCountdown(value) {
        if (!value) return "";
        const when = new Date(value);
        if (isNaN(when.getTime())) return "";
        const minutes = Math.max(0, Math.ceil((when.getTime() - root.nowMs) / 60000));
        if (minutes === 0) return "RESETTING";
        const days = Math.floor(minutes / 1440);
        const hours = Math.floor((minutes % 1440) / 60);
        const mins = minutes % 60;
        const clock = hours + ":" + String(mins).padStart(2, "0");
        return "RESET IN " + (days > 0 ? days + "D " : "") + clock;
    }

    function sessionMoment(value) {
        const when = new Date(value);
        return isNaN(when.getTime()) ? "UNKNOWN TIME"
                                    : Qt.formatDateTime(when, "ddd d MMM · h:mm AP").toUpperCase();
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
                    text: root.selectedProvider ? root.selectedProvider.name.toUpperCase() + " SESSIONS"
                                                : "AI ACCOUNTS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    color: Theme.foreground
                }
                Text {
                    text: root.selectedProvider ? "Local session history · newest first"
                                                : "Vendor limits and activity recorded on this machine"
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
                visible: root.selectedProvider !== null
                text: "BACK"
                icon: "󰁍"
                fontSize: Theme.fontXs
                accent: Theme.surface
                onClicked: root.selectedProvider = null
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
            visible: root.selectedProvider === null

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
                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignRight
                                        spacing: 0
                                        Text {
                                            Layout.alignment: Qt.AlignRight
                                            text: root.resetMoment(modelData.resetsAt)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightBold
                                            color: Theme.foregroundDim
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignRight
                                            text: root.resetCountdown(modelData.resetsAt)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontXs
                                            font.weight: Theme.weightHeavy
                                            color: card.providerColor
                                        }
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
                                text: "SESSIONS " + ((card.modelData.sessions || []).length)
                                icon: "󰈙"
                                fontSize: Theme.fontXs
                                enabled: card.modelData.installed
                                accent: Theme.surfaceAlt
                                onClicked: root.selectedProvider = card.modelData
                            }
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.selectedProvider !== null
            spacing: Theme.spaceSm

            BrixCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm
                clip: true

                ListView {
                    id: sessionList
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    clip: true
                    spacing: Theme.spaceXs
                    model: root.selectedProvider ? (root.selectedProvider.sessions || []) : []
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: BrixCard {
                        id: sessionRow
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: sessionInfo.implicitHeight + Theme.spaceMd * 2
                        radius: Theme.radiusSm
                        color: sessionMouse.containsMouse ? Theme.surfaceDeep : Theme.surfaceAlt
                        shadowOffset: sessionMouse.containsMouse ? Theme.shadowSm : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceSm
                            spacing: Theme.spaceSm
                            ColumnLayout {
                                id: sessionInfo
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: sessionRow.modelData.label
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Theme.weightHeavy
                                    color: Theme.foreground
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (sessionRow.modelData.detail || "UNKNOWN MODEL").toUpperCase()
                                          + " · " + root.sessionMoment(sessionRow.modelData.updatedAt)
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Theme.weightBold
                                    color: Theme.foregroundDim
                                }
                            }
                            BrixButton {
                                text: root.selectedProvider.id === "cursor" ? "OPEN" : "RESUME"
                                icon: root.selectedProvider.id === "cursor" ? "󰆍" : "󰑓"
                                fontSize: Theme.fontXs
                                accent: root.selectedProvider.id === "codex" ? Theme.tertiary
                                      : root.selectedProvider.id === "claude" ? Theme.primary : Theme.info
                                onClicked: Ai.resume(root.selectedProvider.id, sessionRow.modelData)
                            }
                        }
                        MouseArea {
                            id: sessionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ai.resume(root.selectedProvider.id, sessionRow.modelData)
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: sessionList.count === 0
                        spacing: Theme.spaceSm
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰈙"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXl + 8
                            color: Theme.foregroundDim
                        }
                        Text {
                            text: "NO LOCAL SESSIONS YET"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.weightHeavy
                            color: Theme.foregroundDim
                        }
                    }
                }
            }
        }
    }
}
