#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Neobrix packages.
#
#  Everything the desktop itself needs is in Arch's own core/extra — checked
#  against archlinux.org's package API, 42 of 44 names resolve there. The two
#  that do not are applications, not desktop plumbing:
#
#      zen-browser-bin   CachyOS repo; AUR on plain Arch
#      cursor-bin        CachyOS repo; AUR on plain Arch
#
#  They live in OPTIONAL below and are skipped with a note when unavailable, so a
#  plain Arch install is not blocked by them.
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
    bluez-tools            # bt-agent: BlueZ will not bond without a registered
                           # agent, so without this a device pairs temporarily
                           # and is forgotten seconds later
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
)

# Not in Arch's official repositories. Skipped without failing the run: the shell
# does not depend on either, and hypr/lib/context.lua probes for the editor
# before binding a key to it.
OPTIONAL=(
    zen-browser-bin   # CachyOS repo, or AUR/upstream tarball on plain Arch
    cursor-bin        # CachyOS repo, or AUR on plain Arch
)

REQUIRED_ALL=("${CORE[@]}" "${SERVICES[@]}" "${UTILS[@]}" "${LOOK[@]}" "${GREETER[@]}" "${APPS[@]}")
ALL=("${REQUIRED_ALL[@]}" "${OPTIONAL[@]}")

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
    # Optional names missing is expected on plain Arch and is not an error.
    optional_missing=(); required_missing=()
    for u in "${unavailable[@]}"; do
        if printf '%s\n' "${OPTIONAL[@]}" | grep -qx -- "$u"; then
            optional_missing+=("$u")
        else
            required_missing+=("$u")
        fi
    done
    if (( ${#optional_missing[@]} )); then
        printf '\033[33m==>\033[0m skipping, not in your repositories: %s\n' "${optional_missing[*]}"
        printf '    These are applications, not part of the desktop. On plain Arch they are\n'
        printf '    AUR packages (paru -S zen-browser-bin cursor-bin), or install Zen from\n'
        printf '    upstream. Neobrix runs without them; the browser keybind and the IDE\n'
        printf '    keybind simply point at whatever you do have.\n'
    fi
    if (( ${#required_missing[@]} )); then
        printf '\033[31m==>\033[0m required packages not found in any repository: %s\n' "${required_missing[*]}"
        printf '    This is unexpected on Arch or CachyOS — check your mirrors.\n'
    fi
fi

if (( ${#missing[@]} == 0 )); then
    printf '\033[32m==>\033[0m all repository packages already installed\n'
    exit 0
fi

printf '\033[32m==>\033[0m missing: %s\n' "${missing[*]}"
[[ "${1:-}" == "--check" ]] && exit 1

# No --noconfirm: this is the one moment the user should see what is about to be
# installed and be able to refuse, since repository packages can displace -git
# builds something else on the machine depends on. Pacman reads that answer from
# *stdin*, which is why bootstrap.sh hands its children a terminal (or /dev/null)
# and never its own stdin — piped, its stdin is the rest of the install script,
# and pacman would eat it. If you add a caller, give this script a real stdin.
sudo pacman -S --needed "${missing[@]}"

# mpv-mpris is optional but makes mpv show up in the shell's media controls.
if pacman -Qq mpv >/dev/null 2>&1 && ! pacman -Qq mpv-mpris >/dev/null 2>&1; then
    printf '\033[32m==>\033[0m mpv is installed; adding mpv-mpris for MPRIS support\n'
    sudo pacman -S --needed --noconfirm mpv-mpris || true
fi
