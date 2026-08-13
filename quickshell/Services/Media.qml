pragma Singleton

// MPRIS — native D-Bus binding. `playerctl` is never spawned.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property bool available: players.length > 0

    // Sticky selection: keep showing the player the user last interacted with,
    // otherwise prefer whichever is actually playing.
    property var pinned: null

    readonly property var active: {
        if (pinned && players.indexOf(pinned) !== -1) return pinned;
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool playing: active !== null && active.isPlaying
    readonly property string title: active && active.trackTitle ? active.trackTitle : ""
    readonly property string artist: active && active.trackArtist ? active.trackArtist : ""
    readonly property string album: active && active.trackAlbum ? active.trackAlbum : ""
    readonly property string artUrl: active && active.trackArtUrl ? active.trackArtUrl : ""
    readonly property string identity: active ? active.identity : ""
    readonly property string desktopEntry: active && active.desktopEntry ? active.desktopEntry : ""

    readonly property real length: active && active.lengthSupported ? active.length : 0
    readonly property real position: active && active.positionSupported ? active.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    readonly property bool canGoNext: active !== null && active.canGoNext
    readonly property bool canGoPrevious: active !== null && active.canGoPrevious
    readonly property bool canToggle: active !== null && active.canTogglePlaying
    readonly property bool canSeek: active !== null && active.canSeek && active.positionSupported

    function fmtTime(sec) {
        if (!isFinite(sec) || sec <= 0) return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function toggle() { if (active && active.canTogglePlaying) active.togglePlaying(); }
    function next() { if (active && active.canGoNext) active.next(); }
    function previous() { if (active && active.canGoPrevious) active.previous(); }
    function seekTo(fraction) {
        if (active && canSeek && length > 0) active.position = fraction * length;
    }
    function selectPlayer(p) { pinned = p; }

    // MPRIS position is not push-based; refresh it only while a panel is showing
    // a progress bar for a player that is actually playing.
    property int positionSubscribers: 0
    function subscribePosition() { positionSubscribers++; }
    function unsubscribePosition() { positionSubscribers = Math.max(0, positionSubscribers - 1); }

    Timer {
        interval: 1000
        repeat: true
        running: root.positionSubscribers > 0 && root.playing && root.active !== null
                 && root.active.positionSupported
        onTriggered: if (root.active) root.active.positionChanged()
    }
}
