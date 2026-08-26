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
#    ./install/packages.sh --yes      install without pacman's confirmation.
#                                     Read what that means at the bottom of
#                                     this file before reaching for it.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

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
    eza                     # ls in the shell's aliases; icons need the nerd font
    gpu-screen-recorder     # the control centre's Record action; encodes on the
                            # GPU, so a 1080p capture costs almost nothing
    grim slurp satty
    brightnessctl
    iw                      # wifi bitrate in the connectivity panel; the figure
                            # is omitted rather than wrong when it is missing
    libnotify
    btop                    # themed by neobrix-generate-btop
    imagemagick librsvg     # wallpaper generation
    python                  # screenshot geometry helpers, and the refresh-rate
                            # switch in neobrix-power
    pciutils                # GPU name in the specs card and on the lock screen;
                            # without it both fall back to the driver name
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
    kitty          # the terminal SUPER+RETURN opens
    fish           # the shell it opens; see terminal/fish/config.fish
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

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '%s==>%s %s\n' "$c_err" "$c_off" "$*" >&2; }
# Pacman's own words, indented and unedited. Every wrong diagnosis this script
# has produced came from summarising them instead of printing them.
quote() { sed 's/^/      /' >&2; }

CHECK_ONLY=0
ASSUME_YES=${NB_ASSUME_YES:-0}    # bootstrap.sh exports this from its own --yes
for a in "$@"; do
    case "$a" in
        --check)  CHECK_ONLY=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
    esac
done

configure_pacman_style() {
    # Pacman's visual options live in its system config. Preserve the original
    # once for rollback, then change only presentation keys in [options]; repo,
    # mirror and signature policy remain as the distribution set them.
    info "configuring Pacman's Neobrix CLI style"
    local styled
    styled="$(mktemp)"
    if ! "$HERE/configure-pacman.py" /etc/pacman.conf > "$styled"; then
        rm -f "$styled"
        return 1
    fi
    sudo cp -n /etc/pacman.conf /etc/pacman.conf.pre-neobrix
    sudo install -m644 "$styled" /etc/pacman.conf
    # CachyOS ships a later 01-options.conf which can override the main file.
    # This final fragment makes the effective value deterministic there while
    # the normalized main file covers Arch installations without the wildcard.
    sudo install -Dm644 "$HERE/../package/pacman-options.conf" \
        /etc/pacman.d/99-neobrix-options.conf
    rm -f "$styled"
}

# ── make sure pacman can answer before believing its answers ─────────────────
# The sync databases have to be current, or every -Si below fails and the whole
# package list gets classified as "not in your repositories" — 46 names blamed
# on the mirrors when the real fault was one stale or unreadable database.
refresh_failed=0
if (( CHECK_ONLY )); then
    warn "--check: leaving the package databases alone (refreshing them needs sudo)"
else
    info "refreshing package databases"
    if ! sy_err="$(sudo pacman -Sy 2>&1 >/dev/null)"; then
        refresh_failed=1
        warn "could not refresh the package databases; classifying against what is on disk"
        [[ -n $sy_err ]] && printf '%s\n' "$sy_err" | quote
    fi
fi

# One query with a known-good answer. `pacman` is in core on every Arch and
# CachyOS install, so if this fails the fault is pacman's, not the list's. The
# old code could not tell those two apart: a broken pacman looked exactly like
# 46 packages that do not exist, and it reported the second.
if ! probe_err="$(pacman -Si pacman 2>&1 >/dev/null)"; then
    err "pacman cannot query its package databases, so nothing was classified."
    err "pacman said:"
    printf '%s\n' "$probe_err" | quote
    (( refresh_failed )) && err "the refresh above failed too — check your mirrors."
    exit 1
fi

missing=()
unavailable=()
si_err=""
for p in "${ALL[@]}"; do
    # -Qq's stderr stays hidden: "package not found" is the ordinary answer here.
    # -Si's does not — that is the one that carried the real error and was thrown
    # away, and an evening went into rediscovering it in English.
    if pacman -Qq "$p" >/dev/null 2>&1; then continue; fi
    if p_err="$(pacman -Si "$p" 2>&1 >/dev/null)"; then
        missing+=("$p")
    else
        unavailable+=("$p")
        if [[ -z $si_err && -n $p_err ]]; then si_err="$p_err"; fi
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
        warn "skipping, not in your repositories: ${optional_missing[*]}"
        printf '    These are applications, not part of the desktop. On plain Arch they are\n'
        printf '    AUR packages (paru -S zen-browser-bin cursor-bin), or install Zen from\n'
        printf '    upstream. Neobrix runs without them; the browser keybind and the IDE\n'
        printf '    keybind simply point at whatever you do have.\n'
    fi
    if (( ${#required_missing[@]} )); then
        # Fatal. It used to fall through to "all repository packages already
        # installed" and exit 0, because a package that is unavailable is never
        # in `missing` — so the run continued and install/deploy.sh answered with
        # "run packages.sh first", pointing at the script that had just claimed
        # success.
        err "required packages not found in any repository: ${required_missing[*]}"
        if (( refresh_failed )); then
            err "the package databases could not be refreshed, which is the likely cause — check your mirrors."
        elif (( CHECK_ONLY )); then
            err "the databases were not refreshed in --check mode; re-run without --check to refresh first."
        else
            err "the databases refreshed cleanly, so this is not a mirror problem."
        fi
        if [[ -n $si_err ]]; then
            err "pacman said, for the first of them:"
            printf '%s\n' "$si_err" | quote
        fi
        err "stopping here: the desktop cannot be deployed without these."
        exit 1
    fi
fi

if (( ${#missing[@]} == 0 )); then
    info "all repository packages already installed"
    (( CHECK_ONLY )) || configure_pacman_style
    exit 0
fi

info "missing: ${missing[*]}"
(( CHECK_ONLY )) && exit 1

# ── install ──────────────────────────────────────────────────────────────────
# The confirmation is answered by a person or it is not answered at all.
#
# It has to be read from a terminal, not from stdin: piped — `curl … | bash` —
# this script's caller has the rest of the installer on its stdin, and pacman
# reads in blocks, so it swallowed everything below the packages step and the
# run ended there having deployed nothing. bootstrap.sh therefore hands its
# children the terminal and never its own stdin, and this script checks for a
# terminal itself rather than trusting whatever descriptor it was handed —
# /dev/null is not a "no terminal" that anything can recognise once it has been
# given it.
#
# With no terminal, this stops. It does not fall back to --noconfirm, because
# --noconfirm does not only answer "Proceed with installation?" — it also
# accepts package replacements and conflict resolutions. On a machine where
# another account's desktop depends on -git builds, an unattended run could
# replace hyprland-git with the repository hyprland and break a session
# belonging to someone who is not there to be asked. Failing is the smaller
# harm, and pacman agrees: given EOF on stdin it treats it as a refusal, prints
# the prompt, exits 1 and installs nothing.
confirm=()
if (( ASSUME_YES )); then
    warn "--yes: installing without pacman's confirmation."
    warn "That accepts package replacements and conflict resolutions too, not"
    warn "just the proceed prompt — repository packages may replace -git builds."
    confirm=(--noconfirm)
elif ! { exec 3<>/dev/tty; } 2>/dev/null; then
    err "no terminal to confirm at, so nothing was installed."
    err "pacman's confirmation needs a person; re-run with --yes to skip it:"
    printf '      %s\n' \
        "curl -fsSL https://raw.githubusercontent.com/asad-albadi/NeoBrix/main/install/bootstrap.sh | bash -s -- --yes" \
        "./install/packages.sh --yes" >&2
    err "--yes also accepts package replacements, so on a machine where another"
    err "account's setup depends on -git builds, read the list above first."
    exit 1
else
    exec 3>&-
fi

sudo pacman -S --needed "${confirm[@]}" "${missing[@]}"

# mpv-mpris is optional but makes mpv show up in the shell's media controls.
if pacman -Qq mpv >/dev/null 2>&1 && ! pacman -Qq mpv-mpris >/dev/null 2>&1; then
    info "mpv is installed; adding mpv-mpris for MPRIS support"
    sudo pacman -S --needed --noconfirm mpv-mpris || true
fi

configure_pacman_style
