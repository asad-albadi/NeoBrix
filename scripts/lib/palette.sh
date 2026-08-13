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
        FG_DIM=8a7a6c
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

        # ANSI ramp for the terminals.
        N_BLACK=171210; N_RED=d1584c; N_GREEN=5f9c4c; N_YELLOW=b9922c
        N_BLUE=4a7fb5; N_MAGENTA=9b6fd6; N_CYAN=3f9d92; N_WHITE=e3d3c1
        B_BLACK=8a7a6c; B_RED=e8776b; B_GREEN=8fce7c; B_YELLOW=ebc963
        B_BLUE=9fc4e8; B_MAGENTA=c4aef2; B_CYAN=6fc7bb; B_WHITE=fcf6ee

        GTK_SCHEME=prefer-light; GTK_THEME=adw-gtk3; ICONS=Papirus-Light
        KDE_SCHEME=NeobrixDawn
        ;;
    dusk)
        DESKTOP=14100e
        BG=241d18
        SURFACE_ALT=1c1613
        BG_ALT=1c1613
        BG_DEEP=100d0b
        FG=f6ede2
        FG_DIM=9c8a79
        OUTLINE=f0e2d2      # cream outline on dark — still the strongest line
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

        GTK_SCHEME=prefer-dark; GTK_THEME=adw-gtk3-dark; ICONS=Papirus-Dark
        KDE_SCHEME=NeobrixDusk
        ;;
    *)
        printf 'neobrix_palette: unknown mode: %s\n' "$1" >&2
        return 2
        ;;
    esac
}
