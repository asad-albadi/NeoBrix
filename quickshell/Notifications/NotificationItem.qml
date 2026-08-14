// One notification card. Shared by the toast layer and the notification centre.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    property var wrapper: null
    property bool popup: false

    signal dismissed()

    readonly property var notif: wrapper ? wrapper.notification : null
    readonly property string urgency: wrapper ? wrapper.urgency : "normal"

    readonly property color accent: urgency === "critical" ? Theme.error
                                  : urgency === "low" ? Theme.info
                                  : Theme.primary

    // Senders differ wildly in how they identify themselves. `notify-send -i name`
    // arrives as an image-path hint (which Quickshell surfaces as an
    // `image://icon/<name>` url) and leaves appIcon empty, while desktop apps
    // usually set appIcon or a desktop entry. Resolve the small header badge from
    // whichever of those exists.
    readonly property bool imageIsIconName: notif !== null
                                            && notif.image.startsWith("image://icon/")
    readonly property string badgeSource: {
        if (!notif) return "";
        if (notif.appIcon !== "") return Quickshell.iconPath(notif.appIcon, true);
        if (notif.desktopEntry !== "") {
            const e = DesktopEntries.byId(notif.desktopEntry);
            if (e && e.icon) return Quickshell.iconPath(e.icon, true);
        }
        // An icon-name image is identity, not content.
        if (imageIsIconName) return notif.image;
        return "";
    }
    // Only real image content (image-data, or a path to an actual picture) earns
    // the large preview.
    readonly property bool hasPreview: notif !== null && notif.image !== "" && !imageIsIconName

    implicitHeight: card.implicitHeight

    BrixCard {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: layout.implicitHeight + Theme.spaceMd * 2
        height: implicitHeight
        radius: Theme.radiusMd
        color: Theme.surface
        shadowOffset: root.popup ? Theme.shadowMd : Theme.shadowSm
        border.width: root.urgency === "critical" ? Theme.borderThick : Theme.border

        // Urgency stripe down the left edge.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.border
            width: 6
            color: root.accent
            radius: Theme.radiusMd
            // Square off the right side so the stripe reads as a hard band.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2
                color: parent.color
            }
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            anchors.leftMargin: Theme.spaceMd + 8
            spacing: Theme.spaceXs

            // ── header ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                BrixCard {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    color: root.accent

                    Image {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: source !== ""
                        source: root.badgeSource
                        sourceSize.width: 28
                        sourceSize.height: 28
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                Text {
                    text: root.notif ? root.notif.appName : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.wrapper ? root.wrapper.ageText : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    color: Theme.foregroundDim
                }

                BrixIconButton {
                    icon: "󰅖"
                    size: 18
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    accent: "transparent"
                    iconColor: Theme.foregroundDim
                    onClicked: root.dismissed()
                }
            }

            // ── body ────────────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif ? root.notif.summary : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMd
                font.weight: Theme.weightBold
                color: Theme.foreground
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif ? root.notif.body : ""
                textFormat: Text.StyledText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                color: Theme.foregroundDim
                wrapMode: Text.WordWrap
                maximumLineCount: root.popup ? 3 : 8
                elide: Text.ElideRight
                // The body is StyledText, so a sender can put any <a href> in it —
                // including schemes that hand a local path or a registered handler
                // to xdg-open. Only web and mail links are followed.
                onLinkActivated: link => {
                    if (/^(https?|mailto):/i.test(link))
                        Quickshell.execDetached(["xdg-open", link]);
                }
            }

            // Image supplied via the image-data/image-path hints.
            //
            // Senders that only pass `-i <icon-name>` end up with image == appIcon;
            // that icon is already drawn in the header badge, so showing it again as
            // a large preview would swamp a one-line notification.
            ClippingRectangle {
                visible: root.hasPreview
                Layout.preferredWidth: Math.min(parent.width, 160)
                Layout.preferredHeight: visible ? 72 : 0
                radius: Theme.radiusXs
                color: Theme.surfaceDeep
                border.width: Theme.border
                border.color: Theme.outline

                Image {
                    anchors.fill: parent
                    source: root.notif ? root.notif.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // ── actions ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: root.notif && root.notif.actions.length > 0
                spacing: Theme.spaceSm

                Repeater {
                    model: root.notif ? root.notif.actions : []

                    delegate: BrixButton {
                        required property var modelData
                        text: modelData.text
                        fontSize: Theme.fontXs
                        accent: Theme.surfaceDeep
                        onClicked: {
                            modelData.invoke();
                            root.dismissed();
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // Middle-click anywhere dismisses; useful for toasts.
    MouseArea {
        anchors.fill: card
        acceptedButtons: Qt.MiddleButton
        onClicked: root.dismissed()
    }
}
