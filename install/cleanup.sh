#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Look for another Hyprland desktop already installed, and offer — one item at
#  a time — to get it out of the way.
#
#      ./install/cleanup.sh          detect, then ask about each item
#      ./install/cleanup.sh --yes    detect and report only; removes nothing
#
#  Rules this script follows, because getting them wrong destroys someone's
#  setup:
#
#    * Detection and action are separate. Everything found is listed first.
#    * Every removal is confirmed on its own. There is no "remove all?".
#    * The default answer is always keep.
#    * A run with no terminal, or with --yes, removes nothing at all.
#    * Anything removed is copied to ~/.config-backup/cleanup-<stamp>/ first,
#      the same place deploy.sh puts what it replaces.
#    * Disabling a systemd unit is reversible, so units are only ever disabled.
#      Package removal is a separate question, asked last, and uses `pacman -R`
#      rather than -Rs: on CachyOS, -Rs on the noctalia meta-package also sweeps
#      uwsm, the portals, grim, slurp and more (see docs/DEVIATIONS.md).
#    * Only paths named in this file are ever touched. Nothing under
#      ~/.local/share, ~/Documents or ~/Pictures is considered.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ASSUME_YES=0
[[ ${1:-} == --yes || ${1:-} == -y ]] && ASSUME_YES=1
# shellcheck source=lib/ask.sh
source "$HERE/lib/ask.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
UNITS="$CFG/systemd/user"
BACKUP_ROOT="$HOME/.config-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/cleanup-$STAMP"

info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
step() { printf '  %s·%s %s\n' "$c_dim" "$c_off" "$*"; }

# ── what to look for ─────────────────────────────────────────────────────────
# Config directories belonging to another shell. Only whole-desktop projects are
# listed: a stray waybar or mako config is not touched, because those are tools
# somebody may use deliberately. Their *units* are handled further down.
CONFIG_CANDIDATES=(
    "$CFG/noctalia:Noctalia shell (CachyOS default)"
    "$CFG/caelestia:Caelestia dotfiles"
    "$CFG/ags:ags shell (end-4/dots-hyprland and friends)"
    "$CFG/ml4w:ML4W dotfiles"
    "$CFG/ml4w-hyprland:ML4W dotfiles"
    "$CFG/dots-hyprland:end-4/dots-hyprland"
)

# Units that would fight this shell: a second bar, a second notification daemon,
# a second wallpaper setter, a second shell.
UNIT_CANDIDATES=(
    noctalia.service caelestia.service caelestia-shell.service
    ags.service eww.service ironbar.service waybar.service
    swaync.service mako.service dunst.service
    hyprpaper.service hyprpanel.service
)

# Whole-desktop packages, offered only as a last, separate question.
#
# Meta-packages first, deliberately: pacman refuses to remove a package that
# another installed package requires. Asking about `noctalia` before
# `cachyos-hypr-noctalia` produced exactly that — "removing noctalia breaks
# dependency 'noctalia' required by cachyos-hypr-noctalia" — and left the answer
# the user had already given unfulfilled. The retry pass below covers any
# ordering this list still gets wrong.
PKG_CANDIDATES=(
    cachyos-hypr-noctalia ml4w-hyprland-starter
    noctalia caelestia-shell ml4w-hyprland hyprpanel
)

backup_dir_made=0
ensure_backup() {
    (( backup_dir_made )) && return 0
    mkdir -p "$BACKUP"
    cat > "$BACKUP/README" <<EOF
Made by neobrix install/cleanup.sh on $STAMP.

config/         directories moved out of the way, as they were
disabled-units.txt   systemd --user units that were disabled (re-enable to undo)
removed-packages.txt packages removed with 'pacman -R' (no dependency sweep)

To undo a config directory:   cp -a config/<name> ~/.config/
To undo a unit:               systemctl --user enable --now <unit>
To undo a package:            sudo pacman -S <name>

install/bootstrap.sh --uninstall offers to replay the unit part of this for you.
EOF
    backup_dir_made=1
}

# ── detect ───────────────────────────────────────────────────────────────────
# One list, "path|label" — paths cannot contain a pipe, and a single shape
# means the ask loop below cannot mix the two up.
found_configs=()
for entry in "${CONFIG_CANDIDATES[@]}"; do
    path="${entry%%:*}"; label="${entry#*:}"
    [[ -e $path ]] && found_configs+=("$path|$label")
done

# Other Quickshell configs: ~/.config/quickshell/<name> that is not ours. These
# matter because `qs` can be pointed at any of them and a stale one is confusing,
# but they are cheap to keep, so they are listed like everything else.
found_qs=()
if [[ -d $CFG/quickshell ]]; then
    while IFS= read -r -d '' d; do
        name="$(basename "$d")"
        [[ $name == neobrix ]] && continue
        found_qs+=("$d|another Quickshell config")
    done < <(find "$CFG/quickshell" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
fi

found_units=()
if command -v systemctl >/dev/null 2>&1; then
    # `|| true` is load-bearing: with no user systemd session (a container, CI,
    # a machine where the bus is not up yet) systemctl exits non-zero, and under
    # set -e an assignment from a failing command substitution kills the script —
    # which showed up as this script producing no output at all.
    enabled="$(systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' || true)"
    active="$(systemctl --user list-units --state=active --no-legend 2>/dev/null | awk '{print $1}' || true)"
    for u in "${UNIT_CANDIDATES[@]}"; do
        if grep -qx -- "$u" <<<"$enabled" || grep -qx -- "$u" <<<"$active"; then
            found_units+=("$u")
        fi
    done
fi

found_pkgs=()
if command -v pacman >/dev/null 2>&1; then
    for p in "${PKG_CANDIDATES[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 && found_pkgs+=("$p")
    done
fi

# The login screen is reported, never touched here: swapping a greeter is
# deploy.sh --greeter's job, which writes a recovery file and an agreety
# fallback before anything changes.
greeter_note=""
if [[ -r /etc/greetd/config.toml ]]; then
    cmd="$(grep -E '^\s*command\s*=' /etc/greetd/config.toml | head -1 | cut -d= -f2- | tr -d ' "')"
    [[ -n $cmd && $cmd != *regreet* ]] && greeter_note="$cmd"
fi

total=$(( ${#found_configs[@]} + ${#found_qs[@]} + ${#found_units[@]} + ${#found_pkgs[@]} ))
if (( total == 0 )) && [[ -z $greeter_note ]]; then
    info "no competing desktop setup found"
    exit 0
fi

# ── list everything before touching anything ─────────────────────────────────
warn "found another desktop setup on this machine:"
for entry in "${found_configs[@]}" "${found_qs[@]}"; do
    step "config    ${entry%%|*}  ${c_dim}(${entry#*|})${c_off}"
done
for u in "${found_units[@]}"; do
    step "unit      $u  ${c_dim}(would compete with the Neobrix shell)${c_off}"
done
for p in "${found_pkgs[@]}"; do
    step "package   $p"
done
[[ -n $greeter_note ]] && step "greeter   /etc/greetd/config.toml runs: $greeter_note"

if (( ASSUME_YES )) || [[ -z $NB_TTY ]]; then
    echo
    warn "removing nothing: $( (( ASSUME_YES )) && echo '--yes was given' || echo 'no terminal to ask at' )"
    warn "re-run ./install/cleanup.sh from a terminal to decide item by item"
    exit 0
fi

echo
info "nothing has been changed yet — each item is asked separately, default is keep"

# ── config directories ───────────────────────────────────────────────────────
for entry in "${found_configs[@]}" "${found_qs[@]}"; do
    path="${entry%%|*}"; label="${entry#*|}"
    if confirm no "Move $path out of the way — $label? (copied to $BACKUP/config/ first)"; then
        ensure_backup
        mkdir -p "$BACKUP/config"
        cp -a "$path" "$BACKUP/config/"
        rm -rf "$path"
        step "moved $path -> $BACKUP/config/$(basename "$path")"
    else
        step "kept $path"
    fi
done

# ── units ────────────────────────────────────────────────────────────────────
for u in "${found_units[@]}"; do
    if confirm no "Disable $u? (reversible: systemctl --user enable --now $u)"; then
        ensure_backup
        systemctl --user disable --now "$u" >/dev/null 2>&1 || true
        printf '%s\n' "$u" >> "$BACKUP/disabled-units.txt"
        step "disabled $u"
    else
        step "kept $u enabled"
    fi
done

# ── packages, last and separately ────────────────────────────────────────────
if (( ${#found_pkgs[@]} )); then
    echo
    warn "package removal is not reversible the way disabling a unit is."
    warn "Disabling the units above is usually enough; you can skip this entirely."
    deferred=()
    for p in "${found_pkgs[@]}"; do
        if confirm no "Uninstall the package $p? (pacman -R, no dependency sweep)"; then
            ensure_backup
            if out="$(sudo pacman -R --noconfirm "$p" 2>&1)"; then
                printf '%s\n' "$p" >> "$BACKUP/removed-packages.txt"
                step "removed $p"
            else
                # Usually "breaks dependency": something else still needs it, and
                # that something may be removed later in this same loop. Keep the
                # answer and retry rather than making the user run this again.
                printf '%s\n' "$out" | grep -i 'breaks dependency' | head -1 | sed 's/^/      /'
                warn "could not remove $p yet — will retry once the rest are done"
                deferred+=("$p")
            fi
        else
            step "kept $p installed"
        fi
    done

    # Second pass: the consent was already given, so this asks nothing.
    if (( ${#deferred[@]} )); then
        echo
        info "retrying the packages that were blocked by a dependency"
        for p in "${deferred[@]}"; do
            pacman -Qq "$p" >/dev/null 2>&1 || { step "$p is already gone"; continue; }
            if out="$(sudo pacman -R --noconfirm "$p" 2>&1)"; then
                printf '%s\n' "$p" >> "$BACKUP/removed-packages.txt"
                step "removed $p"
            else
                warn "$p is still installed — something outside this list requires it:"
                printf '%s\n' "$out" | grep -iE 'breaks dependency|error' | head -2 | sed 's/^/      /'
                step "check with:  pacman -Qi $p   (Required By)"
            fi
        done
    fi
fi

if [[ -n $greeter_note ]]; then
    echo
    warn "the login screen is still $greeter_note and was not touched here."
    warn "'./install/deploy.sh --greeter' stages the Neobrix greeter with a"
    warn "recovery file and an agreety fallback, and never enables greetd itself."
fi

echo
(( backup_dir_made )) && info "backups: $BACKUP" || info "nothing was changed"
