#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Undo a Neobrix deployment.
#
#      ./install/uninstall.sh          ask before each step
#      ./install/uninstall.sh --yes    non-interactive; does the reversible parts
#
#  If this project offers to move somebody else's desktop out of the way, it owes
#  the same in reverse. What this does:
#
#    * stops and disables the Neobrix user units
#    * removes the symlinks deploy.sh made — only those that point into this
#      repository, so a file of your own that happens to share a name is left be
#    * offers to restore the newest ~/.config-backup/deploy-* snapshot
#    * offers to re-enable units that install/cleanup.sh disabled
#
#  What it deliberately does NOT do is listed at the end of the run, on screen,
#  because an uninstaller that quietly leaves things behind is worse than one
#  that says so.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ASSUME_YES=0
[[ ${1:-} == --yes || ${1:-} == -y ]] && ASSUME_YES=1
# shellcheck source=lib/ask.sh
source "$HERE/lib/ask.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
UNITS="$CFG/systemd/user"
BACKUP_ROOT="$HOME/.config-backup"

info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
step() { printf '  %s·%s %s\n' "$c_dim" "$c_off" "$*"; }

OUR_UNITS=(neobrix-shell.service neobrix-session.target neobrix-bt-agent.service)

# ── units ────────────────────────────────────────────────────────────────────
info "stopping and disabling the Neobrix units"
for u in "${OUR_UNITS[@]}"; do
    if systemctl --user list-unit-files "$u" >/dev/null 2>&1; then
        systemctl --user disable --now "$u" >/dev/null 2>&1 || true
        step "$u disabled"
    fi
    [[ -L $UNITS/$u ]] && { rm -f "$UNITS/$u"; step "unlinked $UNITS/$u"; }
done
systemctl --user daemon-reload 2>/dev/null || true

# hypridle, hyprpolkitagent and cliphist are packaged units this project only
# enabled; leaving them enabled is harmless and disabling them may not be what
# you want, so they are asked about rather than assumed.
for u in hypridle.service hyprpolkitagent.service cliphist.service; do
    if systemctl --user is-enabled --quiet "$u" 2>/dev/null; then
        if confirm no "Also disable $u? (deploy.sh enabled it; it is not Neobrix's own)"; then
            systemctl --user disable --now "$u" >/dev/null 2>&1 || true
            step "$u disabled"
        else
            step "$u left enabled"
        fi
    fi
done

# ── symlinks ─────────────────────────────────────────────────────────────────
# Only links that resolve into this repository are removed.
info "removing symlinks that point into $REPO"
removed=0
while IFS= read -r -d '' link; do
    target="$(readlink -f "$link" 2>/dev/null || true)"
    [[ $target == "$REPO"/* ]] || continue
    rm -f "$link"
    step "${link/#$HOME/~}"
    removed=$(( removed + 1 ))
done < <(find "$CFG" "$BIN" -maxdepth 3 -type l -print0 2>/dev/null)
(( removed )) || step "none found"

# ~/.config/hypr/machine/local.lua is yours and per-machine: never removed.
[[ -e $CFG/hypr/machine/local.lua ]] && step "kept $CFG/hypr/machine/local.lua (yours, per-machine)"

# ── restore ──────────────────────────────────────────────────────────────────
# || true for the same reason as in cleanup.sh: no ~/.config-backup yet means
# find exits non-zero, and set -e would end the run before it reports anything.
latest_deploy="$(find "$BACKUP_ROOT" -maxdepth 1 -name 'deploy-*' -type d 2>/dev/null | sort | tail -n1 || true)"
if [[ -n $latest_deploy ]]; then
    if confirm yes "Restore the configuration deploy.sh replaced, from ${latest_deploy/#$HOME/~}?"; then
        "$REPO/install/deploy.sh" --restore
    else
        step "left $latest_deploy in place, unused"
    fi
else
    step "no deploy-* backup found to restore"
fi

latest_cleanup="$(find "$BACKUP_ROOT" -maxdepth 1 -name 'cleanup-*' -type d 2>/dev/null | sort | tail -n1 || true)"
if [[ -n $latest_cleanup && -r $latest_cleanup/disabled-units.txt ]]; then
    echo
    warn "install/cleanup.sh previously disabled these units:"
    while read -r u; do step "$u"; done < "$latest_cleanup/disabled-units.txt"
    if confirm yes "Re-enable them?"; then
        while read -r u; do
            systemctl --user enable --now "$u" >/dev/null 2>&1 && step "re-enabled $u" || warn "could not re-enable $u"
        done < "$latest_cleanup/disabled-units.txt"
    fi
fi

# ── what is left ─────────────────────────────────────────────────────────────
echo
info "done. What this did NOT remove, on purpose:"
step "packages — nothing was uninstalled. ./install/packages.sh --list shows them."
step "$BACKUP_ROOT — every backup is kept, including pre-neobrix/."
step "$DATA/neobrix — generated wallpapers and state."
step "generated theme files in $CFG (gtk-3.0, gtk-4.0, qt5ct, qt6ct, kdeglobals,"
step "  alacritty/kitty palettes) — they were written, not linked, so they stay"
step "  until you replace them with your own."
if [[ -d $CFG/zen ]]; then
    step "the Zen profile's chrome/neobrix.css and the neobrix block in user.js"
fi
if [[ -r /etc/greetd/config.toml ]] && grep -q regreet /etc/greetd/config.toml 2>/dev/null; then
    echo
    warn "the login screen is still the Neobrix greeter. This script does not touch"
    warn "/etc — swapping a greeter blind is how people get locked out. To go back:"
    step "sudo cp /etc/greetd/config.toml.pre-regreet /etc/greetd/config.toml"
    step "see /etc/greetd/RECOVERY for the rest, including re-enabling your old display manager"
fi
step "this clone at $REPO — delete it yourself if you want it gone"
