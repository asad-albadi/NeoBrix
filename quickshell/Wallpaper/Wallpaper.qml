// Wallpaper surface — one background layer per monitor.
//
// Two Image layers crossfade so switching wallpapers doesn't flash the desktop.
// The layer sits below everything (WlrLayer.Background) and takes no input.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        // Never intercept clicks meant for the desktop or windows above.
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "neobrix-wallpaper"
        // A flat theme colour shows through while an image loads, and is the whole
        // wallpaper if none is configured.
        color: Theme.background

        // Which of the two layers is currently on top.
        property bool flip: false
        property string pending: ""

        Image {
            id: layerA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            opacity: win.flip ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durSlow } }
        }

        Image {
            id: layerB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            opacity: win.flip ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durSlow } }
        }

        // Load into the hidden layer, then flip once it is ready so the crossfade
        // never shows a half-decoded image.
        function show(path) {
            if (path === "") return;
            const target = win.flip ? layerA : layerB;
            const shown = win.flip ? layerB : layerA;
            if (shown.source == Qt.resolvedUrl("file://" + path)) return;
            target.source = "file://" + path;
        }

        Connections {
            target: Wall
            function onCurrentChanged() { win.show(Wall.current); }
        }

        Component.onCompleted: {
            // First paint: no crossfade needed, just load into layer A.
            if (Wall.current !== "") layerA.source = "file://" + Wall.current;
        }

        // Flip when the freshly loaded layer is ready.
        Connections {
            target: layerA
            function onStatusChanged() {
                if (layerA.status === Image.Ready && win.flip) win.flip = false;
            }
        }
        Connections {
            target: layerB
            function onStatusChanged() {
                if (layerB.status === Image.Ready && !win.flip) win.flip = true;
            }
        }
    }
}
