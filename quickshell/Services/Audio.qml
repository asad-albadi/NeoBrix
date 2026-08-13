pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Audio — native PipeWire, no pactl/wpctl polling.
//
//  PwObjectTracker is required for a node's `audio` sub-object to be bound; only
//  the default sink/source and any live streams are tracked so we don't bind the
//  whole graph.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool hasSink: sink !== null && sink.audio !== null
    // A VM with no emulated capture device has no default source at all — the
    // microphone UI is hidden rather than shown broken.
    readonly property bool hasSource: source !== null && source.audio !== null

    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool muted: hasSink ? sink.audio.muted : true
    readonly property real micVolume: hasSource ? source.audio.volume : 0
    readonly property bool micMuted: hasSource ? source.audio.muted : true

    readonly property string sinkName: sink ? (sink.nickname || sink.description || sink.name) : "No output"
    readonly property string sourceName: source ? (source.nickname || source.description || source.name) : "No input"

    // All sinks/sources present on the graph, for the output picker.
    readonly property var sinks: {
        const out = [];
        for (const n of Pipewire.nodes.values)
            if (n.isSink && !n.isStream && n.audio) out.push(n);
        return out;
    }

    readonly property string volumeIcon: {
        if (!hasSink || muted) return "󰝟";
        if (volume < 0.01) return "󰕿";
        if (volume < 0.5) return "󰖀";
        return "󰕾";
    }

    readonly property string micIcon: micMuted ? "󰍭" : "󰍬"

    function setVolume(v) {
        if (!hasSink) return;
        sink.audio.volume = Math.max(0, Math.min(1.0, v));
    }
    function stepVolume(d) { setVolume(volume + d); }
    function toggleMute() { if (hasSink) sink.audio.muted = !sink.audio.muted; }

    function setMicVolume(v) {
        if (!hasSource) return;
        source.audio.volume = Math.max(0, Math.min(1.0, v));
    }
    function toggleMicMute() { if (hasSource) source.audio.muted = !source.audio.muted; }

    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node; }

    // Binds the objects we actually read. Without this their `audio` property
    // stays null.
    PwObjectTracker {
        objects: {
            const objs = [];
            if (Pipewire.defaultAudioSink) objs.push(Pipewire.defaultAudioSink);
            if (Pipewire.defaultAudioSource) objs.push(Pipewire.defaultAudioSource);
            for (const n of Pipewire.nodes.values)
                if (n.isSink && !n.isStream) objs.push(n);
            return objs;
        }
    }
}
