pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  NEOBRIX — centralised neo-brutalist design system.
//
//  Every colour, size, radius, duration and font used anywhere in the shell is
//  defined here. Components must never hardcode a literal colour or pixel size.
//
//  Two palettes are provided ("dawn" = light, "dusk" = dark). The active mode is
//  persisted to Quickshell's state dir so it survives a shell restart.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── mode ────────────────────────────────────────────────────────────────
    // "dawn" (light, the canonical Neobrix look) or "dusk" (dark variant).
    property string mode: "dawn"
    readonly property bool dark: mode === "dusk"

    function toggleMode() {
        mode = dark ? "dawn" : "dusk";
        persist();
    }

    function persist() { modeFile.setText(mode + "\n"); }

    // The shell themes itself from the palettes below; `neobrix-theme` applies the
    // same palette to the terminals, GTK, Qt and KDE. Without this the toggle only
    // recoloured the shell and every application stayed in the previous mode.
    onModeChanged: applyToApplications()

    function applyToApplications() {
        Quickshell.execDetached(["neobrix-theme", mode]);
    }

    FileView {
        id: modeFile
        path: Quickshell.statePath("theme-mode")
        preload: true
        onLoaded: {
            const t = text().trim();
            if (t === "dawn" || t === "dusk")
                root.mode = t;
        }
        // A missing state file on first run is expected, not an error.
        printErrors: false
    }

    // ── palettes ────────────────────────────────────────────────────────────
    // Warm cream + pastel accents, near-black outlines. Derived from the
    // Neobrix preview screenshots.
    readonly property QtObject dawn: QtObject {
        readonly property color background:   "#ECDFD1"  // desktop / behind everything
        readonly property color surface:      "#FCF6EE"  // card interior (lightest)
        readonly property color surfaceAlt:   "#F1E6D9"  // panel body / bar fill
        readonly property color surfaceDeep:  "#E3D3C1"  // headers, inset wells
        readonly property color foreground:   "#1E1815"
        readonly property color foregroundDim:"#8A7A6C"
        readonly property color outline:      "#171210"  // the chunky border
        readonly property color shadow:       "#171210"
        readonly property color primary:      "#F6A97E"  // peach
        readonly property color secondary:    "#AFDCA0"  // pistachio
        readonly property color tertiary:     "#C4AEF2"  // lavender
        readonly property color pink:         "#F5A8BC"
        readonly property color success:      "#8FCE7C"
        readonly property color warning:      "#EBC963"
        readonly property color error:        "#E8776B"
        readonly property color info:         "#9FC4E8"
        readonly property color onAccent:     "#171210"  // text drawn on accents
        readonly property real  scrimOpacity: 0.22
    }

    readonly property QtObject dusk: QtObject {
        readonly property color background:   "#14100E"
        readonly property color surface:      "#2E241C"  // card interior
        readonly property color surfaceAlt:   "#191310"  // panel body / bar fill
        readonly property color surfaceDeep:  "#100D0B"
        readonly property color foreground:   "#F6EDE2"
        readonly property color foregroundDim:"#9C8A79"
        // Near-black, not cream. A light outline on a dark ground reads as a glow
        // around every card rather than as structure, and the panels looked busy.
        // Because the border no longer separates card from panel, the two surfaces
        // carry that job instead: `surface` is lifted and `surfaceAlt` dropped so
        // the fill gap is wide enough to read on its own.
        readonly property color outline:      "#0D0A08"
        readonly property color shadow:       "#000000"
        readonly property color primary:      "#F0A377"
        readonly property color secondary:    "#9FD08F"
        readonly property color tertiary:     "#B9A2EC"
        readonly property color pink:         "#EE9BB0"
        readonly property color success:      "#84C471"
        readonly property color warning:      "#E0BE58"
        readonly property color error:        "#E06D61"
        readonly property color info:         "#93B8DE"
        readonly property color onAccent:     "#171210"
        readonly property real  scrimOpacity: 0.42
    }

    readonly property QtObject p: dark ? dusk : dawn

    // Flat aliases so components read as `Theme.surface` rather than `Theme.p.surface`.
    readonly property color background:    p.background
    readonly property color surface:       p.surface
    readonly property color surfaceAlt:    p.surfaceAlt
    readonly property color surfaceDeep:   p.surfaceDeep
    readonly property color foreground:    p.foreground
    readonly property color foregroundDim: p.foregroundDim
    readonly property color outline:       p.outline
    readonly property color shadow:        p.shadow
    readonly property color primary:       p.primary
    readonly property color secondary:     p.secondary
    readonly property color tertiary:      p.tertiary
    readonly property color pink:          p.pink
    readonly property color success:       p.success
    readonly property color warning:       p.warning
    readonly property color error:         p.error
    readonly property color info:          p.info
    readonly property color onAccent:      p.onAccent
    readonly property color scrim:         Qt.rgba(0, 0, 0, p.scrimOpacity)

    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    function contrast(a, b) {
        const la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Picks readable text/glyph colour for an arbitrary accent. Needed because the
    // neutral "accents" (surfaceDeep) invert between the two palettes: a fixed dark
    // onAccent disappears on a dark badge in dusk.
    //
    // Whichever of the two inks contrasts more, rather than a luminance cutoff.
    // A cutoff has to sit somewhere and Theme.error sits right beside where this
    // one was: at 0.52 luminance in dusk it fell on the light side of 0.55 and
    // took the light ink, which is light text on a light red — 1.73 contrast
    // where the dark ink gives 4.59. Asking which one actually reads has no
    // threshold to be on the wrong side of.
    //
    // dusk error is the only surface in either palette whose answer changes;
    // every other one picks the ink it always did.
    function textOn(c) {
        return contrast(c, onAccent) >= contrast(c, foreground) ? onAccent : foreground;
    }

    // The outline for a control, given its fill and the surface behind it.
    //
    // This design defines a control with its border, and that border was always
    // the palette's darkest colour. On a light fill that is the whole look. On a
    // dark fill over a dark surface there is nothing to see at all, which is how
    // a dark button on a dark row in dusk came to be visible only by its text.
    //
    // The deciding question is the fill against its background, not the fill on
    // its own: a dark button on the green connected row is perfectly legible and
    // wants the normal dark outline. Only when fill and background are close
    // does the border have to do the separating, and then it takes the light
    // side — foregroundDim rather than foreground, since an outline that bright
    // on every dark control shouts.
    function outlineFor(fill, behind) {
        if (contrast(fill, behind) >= 1.8) return outline;
        return contrast(fill, outline) >= contrast(fill, foregroundDim)
               ? outline : foregroundDim;
    }

    // Accent rotation used for tiles/badges that want variety without randomness.
    readonly property var accents: [primary, secondary, tertiary, pink, info, warning]
    function accent(i) { return accents[Math.abs(i) % accents.length]; }

    // ── geometry ────────────────────────────────────────────────────────────
    readonly property int border:      2   // standard chunky outline
    readonly property int borderThick: 3   // emphasis (active workspace, focus ring)

    readonly property int radiusXs:  4
    readonly property int radiusSm:   7
    readonly property int radiusMd:  13
    readonly property int radiusLg:  15
    readonly property int radiusPill: 999

    // Hard offset shadows — no blur, this is the core brutalist signature.
    readonly property int shadowSm: 3
    readonly property int shadowMd: 4
    readonly property int shadowLg: 6

    readonly property int spaceXs:  4
    readonly property int spaceSm:  6
    readonly property int spaceMd: 10
    readonly property int spaceLg: 14
    readonly property int spaceXl: 20

    // ── bar ─────────────────────────────────────────────────────────────────
    readonly property int barIslandHeight: 38
    readonly property int barMargin:        6
    readonly property int barGap:           8
    readonly property int barExclusive:     barIslandHeight + barMargin * 2 + shadowSm

    // ── typography ──────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontMono:   "JetBrainsMono Nerd Font Mono"

    readonly property int fontXs:  9
    readonly property int fontSm: 10
    readonly property int fontMd: 11
    readonly property int fontLg: 13
    readonly property int fontXl: 17
    readonly property int fontDisplay: 30

    readonly property int weightNormal: Font.Medium
    readonly property int weightBold:   Font.Bold
    readonly property int weightHeavy:  Font.ExtraBold

    // ── motion ──────────────────────────────────────────────────────────────
    // Deliberately short and snappy: brutalism does not glide.
    readonly property int durFast:   90
    readonly property int durNormal: 150
    readonly property int durSlow:   220
    readonly property int easing: Easing.OutCubic
    readonly property int easingPop: Easing.OutBack
}
