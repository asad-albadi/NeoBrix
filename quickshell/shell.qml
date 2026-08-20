// ─────────────────────────────────────────────────────────────────────────────
//  NEOBRIX — a neo-brutalist Quickshell desktop shell for Hyprland.
//
//  Entry point. Everything visible on screen is created from here:
//    · one Bar per monitor
//    · the panel windows (launcher, control center, calendar, session, clipboard)
//    · the notification toast layer
//
//  Services are singletons under Services/ and are kept alive by the `warmup`
//  bindings below — Quickshell creates a singleton the first time it is used in a
//  live binding, and the notification server in particular must claim its D-Bus
//  name at startup rather than lazily.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import qs.Theme
import qs.Services
import qs.Bar
import qs.Launcher
import qs.Panels
import qs.Notifications
import qs.Wallpaper

ShellRoot {
    id: shell

    // Force early construction of the service singletons. Without a live
    // reference these are only built on first access, which would delay the
    // notification server claiming org.freedesktop.Notifications.
    readonly property var warmup: [
        Theme.mode,
        Panels.current,
        Notifs.count,
        Audio.hasSink,
        Net.connected,
        Bt.available,
        Media.available,
        Hw.hasBattery,
        Apps.all.length,
        Session.canHibernate,
        Wall.current
    ]

    // Wallpaper sits below everything else.
    Wallpaper {}

    // One bar per connected monitor.
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Panels — each is its own layer-shell window, mapped only while open.
    Launcher {}
    ControlCenter {}
    CalendarPanel {}
    SessionPanel {}
    ClipboardPanel {}

    // Bar popovers — one per indicator, each anchored under its own glyph.
    AudioPopover {}
    MicPopover {}
    PowerPopover {}
    NetPopover {}
    BtPopover {}
    NotifPopover {}

    // Toast layer and level OSD.
    NotificationLayer {}
    Osd {}
}
