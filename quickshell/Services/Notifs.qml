pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Notifications.
//
//  Quickshell owns org.freedesktop.Notifications for this session — there is no
//  second daemon (mako/dunst/swaync are not installed). Notifications are kept in
//  two lists: `popups` (on-screen toasts, auto-expiring) and `history` (the
//  notification centre, persisted across a shell reload via keepOnReload).
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int maxHistory: 60
    readonly property int defaultTimeout: 6000
    readonly property int criticalTimeout: 0        // 0 = stays until dismissed

    // Newest first.
    property var history: []
    property var popups: []

    property bool doNotDisturb: false

    readonly property int count: history.length
    readonly property bool hasUnread: unreadCount > 0
    property int unreadCount: 0

    function markAllRead() { unreadCount = 0; }

    function dismissPopup(wrapper) {
        popups = popups.filter(p => p !== wrapper);
    }

    function removeFromHistory(wrapper) {
        history = history.filter(p => p !== wrapper);
        if (wrapper.notification) wrapper.notification.dismiss();
    }

    function clearHistory() {
        const old = history;
        history = [];
        popups = [];
        unreadCount = 0;
        for (const w of old)
            if (w.notification) w.notification.dismiss();
    }

    function clearPopups() { popups = []; }

    function urgencyOf(n) {
        if (!n) return "normal";
        switch (n.urgency) {
        case NotificationUrgency.Critical: return "critical";
        case NotificationUrgency.Low: return "low";
        default: return "normal";
        }
    }

    NotificationServer {
        id: server

        // Retain notifications after the sending app closes them so history works.
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;

            const wrapper = wrapperComponent.createObject(root, {
                notification: notification,
                time: new Date()
            });

            const newHistory = [wrapper].concat(root.history);
            if (newHistory.length > root.maxHistory) {
                const dropped = newHistory.splice(root.maxHistory);
                for (const d of dropped) {
                    if (d.notification) d.notification.dismiss();
                    d.destroy();
                }
            }
            root.history = newHistory;
            root.unreadCount = root.unreadCount + 1;

            if (!root.doNotDisturb)
                root.popups = [wrapper].concat(root.popups).slice(0, 4);
        }
    }

    // A tiny wrapper so we can attach our own arrival timestamp and expiry timer
    // to each notification without mutating the server object.
    Component {
        id: wrapperComponent
        QtObject {
            id: wrapper
            required property var notification
            property date time: new Date()

            readonly property string urgency: root.urgencyOf(notification)
            readonly property int timeout: {
                if (!notification) return root.defaultTimeout;
                if (urgency === "critical") return root.criticalTimeout;
                if (notification.expireTimeout > 0) return notification.expireTimeout;
                return root.defaultTimeout;
            }

            readonly property string ageText: {
                root.ageTick;   // re-evaluate when the shared tick fires
                const secs = Math.floor((new Date() - time) / 1000);
                if (secs < 60) return "now";
                if (secs < 3600) return Math.floor(secs / 60) + "m";
                if (secs < 86400) return Math.floor(secs / 3600) + "h";
                return Math.floor(secs / 86400) + "d";
            }

            property Timer expiry: Timer {
                interval: wrapper.timeout > 0 ? wrapper.timeout : 1
                running: wrapper.timeout > 0 && root.popups.indexOf(wrapper) !== -1
                onTriggered: root.dismissPopup(wrapper)
            }

            property Connections conn: Connections {
                target: wrapper.notification
                function onClosed() {
                    root.popups = root.popups.filter(p => p !== wrapper);
                    root.history = root.history.filter(p => p !== wrapper);
                }
            }
        }
    }

    // Keeps relative timestamps ("3m") fresh in the notification centre.
    property int ageTick: 0
    Timer {
        interval: 30000
        repeat: true
        running: root.history.length > 0
        onTriggered: root.ageTick++
    }
}
