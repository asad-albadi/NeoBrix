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

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '%s==>%s %s\n' "$c_err" "$c_off" "$*" >&2; }
# Pacman's own words, indented and unedited. Every wrong diagnosis this script
# has produced came from summarising them instead of printing them.
quote() { sed 's/^/      /' >&2; }

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

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
    exit 0
fi

info "missing: ${missing[*]}"
(( CHECK_ONLY )) && exit 1

# ── install ──────────────────────────────────────────────────────────────────
# The confirmation stays where anyone can answer it: this is the one moment the
# user should see what is about to be installed and be able to refuse, since
# repository packages can displace -git builds something else on the machine
# depends on. Pacman reads that answer from *stdin*, which is why bootstrap.sh
# hands its children a terminal and never its own stdin — piped, its stdin is the
# rest of the install script, and pacman would eat it.
#
# --noconfirm only where there is nobody to ask, because pacman treats EOF on
# stdin as a refusal rather than as the default its own prompt advertises: it
# prints "Proceed with installation? [Y/n]", exits 1, and installs nothing. So
# with no terminal — CI, `docker run` without -t, a cron job — the run cannot
# install anything at all unless it says so. That is the rule ask.sh already
# uses for its own questions: with nobody to ask, the default applies and the
# log says who decided.
confirm=()
if (( ${NB_ASSUME_YES:-0} )); then
    warn "--yes given: installing without pacman's confirmation"
    confirm=(--noconfirm)
elif ! { exec 3<>/dev/tty; } 2>/dev/null; then
    warn "no terminal to ask at: installing without pacman's confirmation"
    confirm=(--noconfirm)
else
    exec 3>&-
fi

sudo pacman -S --needed "${confirm[@]}" "${missing[@]}"

# mpv-mpris is optional but makes mpv show up in the shell's media controls.
if pacman -Qq mpv >/dev/null 2>&1 && ! pacman -Qq mpv-mpris >/dev/null 2>&1; then
    info "mpv is installed; adding mpv-mpris for MPRIS support"
    sudo pacman -S --needed --noconfirm mpv-mpris || true
fi
