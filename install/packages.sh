#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Neobrix packages.
#
#  Installs everything the desktop needs from the CachyOS/Arch repositories. There
#  are no AUR dependencies: Zen Browser is in the `cachyos` repo as
#  zen-browser-bin, and on plain Arch it can be installed from the AUR or the
#  upstream tarball (see README).
#
#    ./install/packages.sh            install what's missing
#    ./install/packages.sh --list     print the package list and exit
#    ./install/packages.sh --check    report missing packages, install nothing
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── core: compositor, shell, session ────────────────────────────────────────
CORE=(
    hyprland          # compositor
    quickshell        # the shell itself
    hyprlock          # lock screen
    hypridle          # idle daemon
    hyprpolkitagent   # graphical polkit agent
    hyprpicker        # colour picker
    uwsm              # session/systemd integration
)

# ── services the shell binds to natively ────────────────────────────────────
SERVICES=(
    pipewire pipewire-pulse pipewire-alsa wireplumber
    networkmanager
    bluez bluez-utils
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    polkit
    power-profiles-daemon
)

# ── utilities used by keybinds and scripts ──────────────────────────────────
UTILS=(
    wl-clipboard cliphist
    grim slurp satty
    brightnessctl
    libnotify
    imagemagick librsvg     # wallpaper generation
    python                  # screenshot geometry helpers
)

# ── appearance ──────────────────────────────────────────────────────────────
LOOK=(
    ttf-jetbrains-mono-nerd
    papirus-icon-theme
    adw-gtk-theme
    qt5ct qt6ct
    adwaita-cursors
)

# ── login screen ────────────────────────────────────────────────────────────
# Only used once ./install/deploy.sh --greeter is run; installing them changes
# nothing on its own, since greetd stays disabled until you activate it.
GREETER=(
    greetd            # the login daemon
    greetd-agreety    # text-mode fallback greeter — the rollback in RECOVERY
                      # depends on this existing, so it is listed explicitly
                      # rather than left to greetd's dependencies
    greetd-regreet    # the GTK4 greeter Neobrix themes
    cage              # the kiosk compositor regreet runs inside
)

# ── applications ────────────────────────────────────────────────────────────
APPS=(
    alacritty
    dolphin
    zen-browser-bin
    cursor-bin
)

ALL=("${CORE[@]}" "${SERVICES[@]}" "${UTILS[@]}" "${LOOK[@]}" "${GREETER[@]}" "${APPS[@]}")

if [[ "${1:-}" == "--list" ]]; then
    printf '%s\n' "${ALL[@]}"
    exit 0
fi

command -v pacman >/dev/null || { echo "this script targets Arch/CachyOS (pacman)" >&2; exit 1; }

missing=()
unavailable=()
for p in "${ALL[@]}"; do
    if pacman -Qq "$p" >/dev/null 2>&1; then continue; fi
    if pacman -Si "$p" >/dev/null 2>&1; then
        missing+=("$p")
    else
        unavailable+=("$p")
    fi
done

if (( ${#unavailable[@]} )); then
    printf '\033[33m==>\033[0m not in any configured repository: %s\n' "${unavailable[*]}"
    printf '    zen-browser-bin lives in the CachyOS repo; on plain Arch install it\n'
    printf '    from the AUR (paru -S zen-browser-bin) or use the upstream tarball.\n'
fi

if (( ${#missing[@]} == 0 )); then
    printf '\033[32m==>\033[0m all repository packages already installed\n'
    exit 0
fi

printf '\033[32m==>\033[0m missing: %s\n' "${missing[*]}"
[[ "${1:-}" == "--check" ]] && exit 1

sudo pacman -S --needed "${missing[@]}"

# mpv-mpris is optional but makes mpv show up in the shell's media controls.
if pacman -Qq mpv >/dev/null 2>&1 && ! pacman -Qq mpv-mpris >/dev/null 2>&1; then
    printf '\033[32m==>\033[0m mpv is installed; adding mpv-mpris for MPRIS support\n'
    sudo pacman -S --needed --noconfirm mpv-mpris || true
fi
