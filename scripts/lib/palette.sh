# ─────────────────────────────────────────────────────────────────────────────
#  The Neobrix palettes, in one place.
#
#      source .../lib/palette.sh
#      neobrix_palette dawn      # or dusk
#
#  Sourced by neobrix-theme (which renders these into the terminals, GTK, Qt, KDE
#  and hyprlock) and by neobrix-generate-identity (which draws the README
#  swatches). Without this file the palette existed in three places and the
#  documentation drifted from the shell the first time a colour changed.
#
#  quickshell/Theme/Theme.qml remains the reference for the shell itself — QML
#  cannot read shell variables. Keep the two in sync; the role names below match
#  Theme.qml exactly so a diff is obvious.
# ─────────────────────────────────────────────────────────────────────────────

neobrix_palette() {
    case "${1:-dawn}" in
    dawn)
        # Core roles — these mirror Theme.qml's `dawn` block.
        DESKTOP=ecdfd1      # background: the desktop, behind everything
        BG=fcf6ee           # surface: card interior, the lightest tone
        SURFACE_ALT=f1e6d9  # surfaceAlt: panel body / bar fill
        BG_ALT=f0e2d2       # (legacy alias used by the generated app themes)
        BG_DEEP=e3d3c1      # surfaceDeep: headers, inset wells
        FG=1e1815
        # Muted copy remains a foreground in terminals and editors, so it must
        # stay readable rather than behave like a decorative surface tint.
        FG_DIM=6b5f54
        OUTLINE=171210      # the chunky border
        PRIMARY=f6a97e      # peach
        SECONDARY=afdca0    # pistachio
        TERTIARY=c4aef2     # lavender
        PINK=f5a8bc
        SUCCESS=8fce7c
        WARNING=ebc963
        ERROR=e8776b
        INFO=9fc4e8
        ON_ACCENT=171210

        # Text-safe inks for Dawn.  The soft peach/mint/lavender roles above
        # remain surface fills; these colours meet 4.5:1 on #ecdfd1, the
        # darkest editor background used by Dawn.
        N_BLACK=171210; N_RED=9e3f39; N_GREEN=386e35; N_YELLOW=815b12
        N_BLUE=32618d; N_MAGENTA=7040a4; N_CYAN=246c64; N_WHITE=5c5046
        B_BLACK=6b5f54; B_RED=a9433d; B_GREEN=26713b; B_YELLOW=7d5510
        B_BLUE=376793; B_MAGENTA=7d4aae; B_CYAN=216d67; B_WHITE=66594d
        INK_PRIMARY=8d4b25; INK_SECONDARY=386e35; INK_TERTIARY=7040a4
        INK_PINK=8d3e62; INK_SUCCESS=386e35; INK_WARNING=815b12
        INK_ERROR=9e3f39; INK_INFO=32618d

        GTK_SCHEME=prefer-light; GTK_THEME=adw-gtk3; ICONS=Papirus-Light
        KDE_SCHEME=NeobrixDawn
        ;;
    dusk)
        DESKTOP=14100e
        BG=2e241c
        SURFACE_ALT=191310
        BG_ALT=191310
        BG_DEEP=100d0b
        FG=f6ede2
        FG_DIM=9c8a79
        OUTLINE=0d0a08      # near-black; see Theme.qml for why not cream
        PRIMARY=f0a377
        SECONDARY=9fd08f
        TERTIARY=b9a2ec
        PINK=ee9bb0
        SUCCESS=84c471
        WARNING=e0be58
        ERROR=e06d61
        INFO=93b8de
        ON_ACCENT=171210

        N_BLACK=100d0b; N_RED=e06d61; N_GREEN=84c471; N_YELLOW=e0be58
        N_BLUE=93b8de; N_MAGENTA=b9a2ec; N_CYAN=6fc7bb; N_WHITE=c9b8a6
        B_BLACK=6b5b4d; B_RED=ee8b80; B_GREEN=a5da94; B_YELLOW=ecd07f
        B_BLUE=b3cfea; B_MAGENTA=cfbcf5; B_CYAN=93ddd2; B_WHITE=f6ede2
        INK_PRIMARY=f0a377; INK_SECONDARY=9fd08f; INK_TERTIARY=b9a2ec
        INK_PINK=ee9bb0; INK_SUCCESS=84c471; INK_WARNING=e0be58
        INK_ERROR=e06d61; INK_INFO=93b8de

        GTK_SCHEME=prefer-dark; GTK_THEME=adw-gtk3-dark; ICONS=Papirus-Dark
        KDE_SCHEME=NeobrixDusk
        ;;
    *)
        printf 'neobrix_palette: unknown mode: %s\n' "$1" >&2
        return 2
        ;;
    esac
}
