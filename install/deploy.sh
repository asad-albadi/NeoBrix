#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Neobrix deploy — link this repo's configuration into place.
#
#  Everything is symlinked, so editing the repo edits the live configuration and
#  there is never a second divergent copy. Anything already present that is not
#  already our symlink is moved to a timestamped backup first.
#
#    ./install/deploy.sh              link config, install units, generate walls
#    ./install/deploy.sh --dry-run    print what would happen
#    ./install/deploy.sh --no-enable  link only, don't touch systemd
#    ./install/deploy.sh --greeter    also stage the login screen in /etc (sudo)
#    ./install/deploy.sh --greeter-only   stage only that, skip everything else
#    ./install/deploy.sh --restore    undo: put the newest backup back
#
#  --greeter stages only: it themes the greeter and writes both greetd configs
#  beside the active one, but never replaces config.toml and never enables
#  greetd. Activation stays manual, after a `regreet --demo` preview — see
#  greeter/RECOVERY.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# One recurring hazard in this file, because of the line above:
#
#     x=$(cmd | filter)        # cmd fails, or the filter matches nothing
#     [[ -n $x ]] || { … }     # never runs: set -e ended the script one line up
#
# An assignment from a pipeline is itself a command, so a failing pipeline takes
# the script with it *before* the guard written to handle it. Two guards in here
# were unreachable for exactly that reason — the Hyprland version probe and the
# restore-mode backup lookup — and the fc-list note further down is the same
# hazard wearing `grep -q`. Run the command inside the `if`, then filter what it
# returned; do not assign straight from a pipeline you expect to fail.

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
UNITS="$CFG/systemd/user"
BACKUP_ROOT="$HOME/.config-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/deploy-$STAMP"

DRY=0
ENABLE=1
RESTORE=0
GREETER=0
GREETER_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY=1 ;;
        --no-enable) ENABLE=0 ;;
        --greeter)   GREETER=1 ;;
        # For callers that have already deployed — the installer asks about the
        # login screen after the desktop is in place, and re-running the whole
        # deploy just to stage /etc/greetd repeated sixty lines of output.
        --greeter-only) GREETER=1; GREETER_ONLY=1 ;;
        --restore)   RESTORE=1 ;;
        -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
        *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '%s==>%s %s\n' "$c_err" "$c_off" "$*" >&2; }
step() { printf '  %s·%s %s\n' "$c_dim" "$c_off" "$*"; }
run()  { if (( DRY )); then printf '  %s[dry]%s %s\n' "$c_dim" "$c_off" "$*"; else "$@"; fi; }

# A private snapshot must exist before any source bytes are copied. A config
# may rely on its parent directory for privacy while its files are mode 0644.
ensure_backup() {
    run mkdir -p -m 700 "$BACKUP"
    run chmod 700 "$BACKUP"
}

# ── restore mode ─────────────────────────────────────────────────────────────
if (( RESTORE )); then
    latest=""
    if found="$(find "$BACKUP_ROOT" -maxdepth 1 -name 'deploy-*' -type d 2>/dev/null)"; then
        latest="$(printf '%s\n' "$found" | sort | tail -n1)"
    fi
    [[ -n "$latest" ]] || { err "no deploy backup found under $BACKUP_ROOT"; exit 1; }
    info "restoring from $latest"
    # Deploy backups contain only replaced paths, not complete config trees.
    # Merge their leaves, saving current replacements separately. In particular,
    # never descend into a live repo/external symlink while restoring children.
    python3 - "$latest" "$CFG" "$BACKUP_ROOT" "$STAMP" "$DRY" "$BIN" <<'PYRESTORE'
import os
from pathlib import Path
import shutil
import sys
import tempfile

source, config, backups = map(Path, sys.argv[1:4])
stamp, dry = sys.argv[4], sys.argv[5] == "1"
binary = Path(sys.argv[6])
undo = None
covered = []


def present(path):
    return path.exists() or path.is_symlink()


def preserve(path, root, namespace):
    global undo
    if not present(path) or any(parent == path or parent in path.parents for parent in covered):
        return
    relative = Path(namespace) / path.relative_to(root)
    if dry:
        print(f"  [dry] save current {path}")
    else:
        if undo is None:
            backups.mkdir(parents=True, exist_ok=True)
            undo = Path(tempfile.mkdtemp(prefix=f"restore-{stamp}-", dir=backups))
        saved = undo / relative
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(saved))
    # When an ancestor itself was saved, there was no independent child at its
    # original path. Do not write through its saved symlink into the repository.
    covered.append(path)


def directory(path, root, namespace):
    if path == root:
        if not dry:
            path.mkdir(parents=True, exist_ok=True)
        return
    directory(path.parent, root, namespace)
    if path.is_symlink() or (path.exists() and not path.is_dir()):
        if dry:
            print(f"  [dry] detach {path} before restoring children")
            preserve(path, root, namespace)
            return
        # Materialize a linked directory while retaining its unrelated children.
        # copytree follows only the root link; nested links remain links.
        staging = Path(tempfile.mkdtemp(prefix=".neobrix-restore-", dir=path.parent))
        try:
            if path.is_dir():
                shutil.copytree(path, staging, symlinks=True, dirs_exist_ok=True)
            preserve(path, root, namespace)
            # An already-saved ancestor covers this materialized child, so
            # preserve() intentionally leaves its copied link/file in place.
            # Unlink that local copy before installing the real directory.
            if present(path):
                path.unlink()
            os.replace(staging, path)
        finally:
            if staging.exists():
                shutil.rmtree(staging)
    elif not dry:
        path.mkdir(exist_ok=True)


def restore(item, tree=source, root=config, namespace=""):
    relative = item.relative_to(tree)
    target = root / relative
    if item.is_dir() and not item.is_symlink():
        directory(target, root, namespace)
        for child in sorted(item.iterdir()):
            restore(child, tree, root, namespace)
    else:
        directory(target.parent, root, namespace)
        print(f"  {'[dry] ' if dry else ''}restore {relative}")
        preserve(target, root, namespace)
        if not dry:
            # A detached ancestor already saved the previous subtree. Its
            # materialized child can now be replaced without another backup.
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            elif present(target):
                target.unlink()
            shutil.copy2(item, target, follow_symlinks=False)


# Config backups retain their historic relative layout. The reserved namespace
# has exactly one fixed destination; no backup can supply an absolute path.
bin_backup = source / ".local-bin"
if bin_backup.is_symlink() or (bin_backup.exists() and not bin_backup.is_dir()):
    raise ValueError("Invalid .local-bin backup namespace")
for item in sorted(source.iterdir()):
    if item.name != ".local-bin":
        restore(item)
if bin_backup.is_dir():
    for item in sorted(bin_backup.iterdir()):
        restore(item, bin_backup, binary, ".local-bin")
if undo is not None:
    print(f"  current files saved to {undo}")
PYRESTORE
    if [[ -d "$latest/systemd/user" ]] && command -v systemctl >/dev/null; then
        run systemctl --user daemon-reload || warn "could not reload user units; run systemctl --user daemon-reload in your session"
    fi
    info "restored. Log out and back in, or: systemctl --user restart neobrix-session.target"
    exit 0
fi

# ── dependency check ─────────────────────────────────────────────────────────
REQUIRED=(qs hyprctl hyprlock hypridle grim slurp wl-copy cliphist
          notify-send wpctl magick)
OPTIONAL=(satty hyprpicker brightnessctl zen-browser dolphin kitty fish)

info "checking dependencies"
missing=()
for cmd in "${REQUIRED[@]}"; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if (( ${#missing[@]} )); then
    err "missing required commands: ${missing[*]}"
    err "run install/packages.sh first (it installs everything from the repos)"
    exit 1
fi
for cmd in "${OPTIONAL[@]}"; do
    command -v "$cmd" >/dev/null || warn "optional command not found: $cmd"
done

# Fonts the shell and terminals name explicitly.
# Note: no `grep -q` here — it exits early, which SIGPIPEs fc-list and trips
# `set -o pipefail` into reporting a missing font that is actually installed.
if ! fc-list : family | grep -i 'JetBrainsMono Nerd Font' >/dev/null; then
    err "JetBrainsMono Nerd Font is not installed (pacman -S ttf-jetbrains-mono-nerd)"
    exit 1
fi

# ── linking ──────────────────────────────────────────────────────────────────
# link <source-in-repo> <destination>
link() {
    local src="$REPO/$1" dst="$2" rel
    case "$dst" in
        "$CFG"/*) rel="${dst#"$CFG"/}" ;;
        "$BIN"/*) rel=".local-bin/${dst#"$BIN"/}" ;;
        *) err "unsupported deployment destination: $dst"; return 1 ;;
    esac
    [[ -e "$src" ]] || { err "missing in repo: $1"; return 1; }

    if [[ -L "$dst" ]]; then
        local cur; cur="$(readlink -f "$dst" || true)"
        if [[ "$cur" == "$(readlink -f "$src")" ]]; then
            step "$dst ${c_dim}(already linked)${c_off}"
            return 0
        fi
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        local bdir="$BACKUP/$(dirname "$rel")"
        warn "backing up existing $dst"
        ensure_backup
        run mkdir -p "$bdir"
        run cp -a "$dst" "$bdir/"
        run rm -rf "$dst"
    fi

    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$src" "$dst"
    step "$dst -> $1"
}

# Hyprland 0.56+ loads hyprland.lua in preference to hyprland.conf and calls the
# hyprlang tree the "legacy config". This project ships Lua; a leftover .conf tree
# from an older deploy is retired so nothing is half-migrated.
retire_legacy_conf() {
    local conf="$CFG/hypr/hyprland.conf"
    [[ -e "$conf" || -d "$CFG/hypr/conf.d" ]] || return 0

    # If a Hyprland session is running *from* that .conf, deleting it drops the
    # live session onto Hyprland's autogenerated stub — it rewrites the file and
    # reloads. `eval` is only available under the Lua config manager, so it tells
    # us which format the running compositor actually loaded.
    if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
        # hyprctl exits 0 even for this refusal, so match the message, not $?.
        if hyprctl eval 'return 1' 2>&1 | grep -qi 'only supported with the lua'; then
            warn "the running session is using the legacy hyprland.conf — leaving it in place"
            step "log out and back in (Hyprland will pick hyprland.lua), then re-run this script"
            return 0
        fi
    fi

    warn "retiring the legacy hyprlang configuration (this project is Lua now)"
    ensure_backup
    run mkdir -p "$BACKUP/hypr"
    [[ -e "$conf" ]] && { run cp -aL "$conf" "$BACKUP/hypr/"; run rm -f "$conf"; }
    if [[ -d "$CFG/hypr/conf.d" ]]; then
        run cp -aL "$CFG/hypr/conf.d" "$BACKUP/hypr/"
        # 99-local.conf is the user's own; carry it forward as machine/local.lua
        # is the Lua equivalent, but never silently delete it.
        run rm -rf "$CFG/hypr/conf.d"
    fi
    step "backed up to $BACKUP/hypr/"
}

# Hyprland must be new enough to load a Lua config at all.
require_lua_capable_hyprland() {
    local version="" raw first
    # hyprctl exits 1 with no compositor running, and the version match then
    # finds nothing either. Assigned straight from the pipeline, both of those
    # ended the script here — so this ran on no first install, which is the one
    # case the guard below exists for.
    if raw="$(hyprctl version 2>/dev/null)"; then
        first="${raw%%$'\n'*}"
        if [[ $first =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then version="${BASH_REMATCH[1]}"; fi
    fi
    [[ -n "$version" ]] || { warn "could not determine the Hyprland version; assuming Lua support"; return 0; }

    local major minor
    major=${version%%.*}
    minor=$(printf '%s' "$version" | cut -d. -f2)
    if (( major == 0 && minor < 55 )); then
        err "Hyprland $version does not support the Lua configuration format."
        err "Neobrix targets Hyprland >= 0.55. Upgrade Hyprland, or pin an older"
        err "release of this repository that still used the hyprlang (.conf) format."
        exit 1
    fi
    step "Hyprland $version supports the Lua configuration"
}

# ── login screen ─────────────────────────────────────────────────────────────
# The one part of this repo that lives outside $HOME, needs root, and can leave a
# machine with no way to log in. So it is opt-in, and even then it only *stages*:
# the greeter is themed and both greetd configs are written beside the active one,
# but config.toml is never replaced and greetd is never enabled. Swapping the
# active config is a single copy you run yourself, from a TTY, after previewing
# the result with `regreet --demo` — greeter/RECOVERY has the commands and the
# rollback.
stage_greeter() {
    local etc=/etc/greetd dm

    for cmd in greetd regreet cage; do
        command -v "$cmd" >/dev/null || {
            err "the greeter needs $cmd (pacman -S greetd regreet cage)"; return 1; }
    done
    command -v sudo >/dev/null || { err "staging the greeter needs sudo to write $etc"; return 1; }

    info "staging the login screen into $etc"
    warn "this part needs sudo; everything above was user-level"

    # A verbatim copy of whatever was in /etc/greetd before Neobrix, kept in /etc
    # rather than under $HOME so it is reachable from a TTY as root. Written once:
    # a second run must not capture the staged state and call it the original.
    if [[ -d "$etc" ]] && [[ ! -e /etc/greetd.pre-neobrix ]]; then
        run sudo cp -a "$etc" /etc/greetd.pre-neobrix
        step "/etc/greetd.pre-neobrix ${c_dim}(verbatim copy of the previous /etc/greetd)${c_off}"
    elif [[ -e /etc/greetd.pre-neobrix ]]; then
        step "/etc/greetd.pre-neobrix ${c_dim}(kept)${c_off}"
    fi

    # Which display manager was enabled, so it can be put back exactly. Also
    # written once, for the same reason.
    if [[ ! -e "$etc/PREVIOUS-DISPLAY-MANAGER" ]]; then
        local prev_dm="none"
        [[ -L /etc/systemd/system/display-manager.service ]] && \
            prev_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
        if (( DRY )); then
            printf '  %s[dry]%s write %s containing: %s\n' \
                "$c_dim" "$c_off" "$etc/PREVIOUS-DISPLAY-MANAGER" "$prev_dm"
        else
            printf '%s\n' "$prev_dm" | sudo tee "$etc/PREVIOUS-DISPLAY-MANAGER" >/dev/null
        fi
        step "$etc/PREVIOUS-DISPLAY-MANAGER ${c_dim}($prev_dm)${c_off}"
    else
        step "$etc/PREVIOUS-DISPLAY-MANAGER ${c_dim}(kept — $(cat "$etc/PREVIOUS-DISPLAY-MANAGER" 2>/dev/null))${c_off}"
    fi

    run sudo install -Dm644 "$REPO/greeter/RECOVERY" "$etc/RECOVERY"

    # The rollback target has to be a config known to work. Whatever is live now
    # qualifies; if there is nothing there, use the repo's agreety fallback, which
    # points at a binary greetd itself ships and so cannot go missing. Written
    # once and then left alone — re-copying it later would overwrite the true
    # original with the Neobrix config it is meant to roll back from.
    if [[ -e "$etc/config.toml.pre-regreet" ]]; then
        step "$etc/config.toml.pre-regreet ${c_dim}(kept — the original)${c_off}"
    elif [[ -e "$etc/config.toml" ]]; then
        run sudo cp -a "$etc/config.toml" "$etc/config.toml.pre-regreet"
        step "rollback: $etc/config.toml.pre-regreet ${c_dim}(your current config)${c_off}"
    else
        run sudo install -Dm644 "$REPO/greeter/greetd-config-fallback.toml" \
            "$etc/config.toml.pre-regreet"
        step "rollback: $etc/config.toml.pre-regreet ${c_dim}(agreety)${c_off}"
    fi

    run sudo install -Dm644 "$REPO/greeter/greetd-config.toml" "$etc/config.toml.neobrix-greeter"
    step "$etc/config.toml.neobrix-greeter ${c_dim}(staged, NOT active)${c_off}"

    # Palette, wallpaper and regreet.toml/css. Root, because /etc and
    # /usr/share/backgrounds are not writable by the user, and the greeter runs as
    # the `greeter` user which cannot read $HOME.
    run sudo "$REPO/scripts/neobrix-generate-greeter"

    if [[ -L /etc/systemd/system/display-manager.service ]]; then
        dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
        [[ "$dm" == greetd.service ]] || \
            warn "$dm is the enabled display manager — activating greetd means disabling it first"
    fi

    cat <<GREETER

  Staged, not active. Preview it without touching greetd — this renders the real
  UI with no login path involved:
        regreet --demo -c $etc/regreet.toml -s $etc/regreet.css

  When you are ready to make it the login screen:
        neobrix greeter enable

  That asks first, refuses unless the rollback is in place (RECOVERY, the agreety
  fallback, a recorded display manager and a reachable getty), records what it
  replaces, and takes effect at the next boot without restarting anything. To
  reverse it: neobrix greeter disable

  Rollback if the greeter ever fails to appear: $etc/RECOVERY
GREETER
}

# Staging the greeter and nothing else: everything below is skipped.
if (( GREETER_ONLY )); then
    if stage_greeter; then exit 0; fi
    warn "login screen not staged"
    exit 1
fi

info "linking configuration"
require_lua_capable_hyprland
retire_legacy_conf
link quickshell            "$CFG/quickshell/neobrix"
link hypr/hyprland.lua     "$CFG/hypr/hyprland.lua"
link hypr/config           "$CFG/hypr/config"
link hypr/lib              "$CFG/hypr/lib"
link hypr/hyprlock.conf    "$CFG/hypr/hyprlock.conf"
link hypr/hypridle.conf    "$CFG/hypr/hypridle.conf"
link hypr/xdph.conf        "$CFG/hypr/xdph.conf"
link uwsm/env              "$CFG/uwsm/env"
link terminal/alacritty/alacritty.toml "$CFG/alacritty/alacritty.toml"
link terminal/kitty/kitty.conf         "$CFG/kitty/kitty.conf"
link terminal/fastfetch/config.jsonc   "$CFG/fastfetch/config.jsonc"
link terminal/fish/config.fish         "$CFG/fish/config.fish"
link terminal/fish/functions/fish_prompt.fish "$CFG/fish/functions/fish_prompt.fish"
link package/paru.conf                 "$CFG/paru/paru.conf"
# GTK, Qt and KDE colours are *generated* by neobrix-theme rather than linked:
# they must follow the shell's light/dark mode, and KDE applications write to
# kdeglobals themselves — a symlink there gets rewritten and the theme drifts
# (that is how a stale "ColorScheme=Noctalia" ended up back in this repo).

# machine/ holds the untracked per-host override module. It is seeded from the
# example once and then left alone.
info "seeding hypr/machine/local.lua"
run mkdir -p "$CFG/hypr/machine"
if [[ ! -e "$CFG/hypr/machine/local.lua" ]]; then
    run cp "$REPO/hypr/machine/local.lua.example" "$CFG/hypr/machine/local.lua"
    step "$CFG/hypr/machine/local.lua (edit for per-machine settings)"
else
    step "$CFG/hypr/machine/local.lua ${c_dim}(kept)${c_off}"
fi

# ── scripts on PATH ──────────────────────────────────────────────────────────
info "linking scripts into $BIN"
run mkdir -p "$BIN"
for s in "$REPO"/scripts/*; do
    [[ -f "$s" && -x "$s" ]] || continue
    link "scripts/$(basename "$s")" "$BIN/$(basename "$s")"
done
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) warn "$BIN is not on your PATH — Hyprland's exec binds need it. Add it to your shell profile." ;;
esac

# ── wallpapers ───────────────────────────────────────────────────────────────
WALLS="$DATA/neobrix/wallpapers"
if [[ -z "$(find "$WALLS" -maxdepth 1 -name '*.png' 2>/dev/null)" ]]; then
    info "generating wallpapers into $WALLS"
    run "$REPO/scripts/neobrix-generate-wallpapers" "$WALLS"
else
    step "wallpapers already present in $WALLS"
fi

# ── systemd units ────────────────────────────────────────────────────────────
if (( ENABLE )); then
    info "installing systemd user units"
    run mkdir -p "$UNITS"
    for u in "$REPO"/systemd/*; do
        link "systemd/$(basename "$u")" "$UNITS/$(basename "$u")"
    done

    run systemctl --user daemon-reload

    # Our units plus the ones shipped by the hypr* / cliphist packages. All are
    # WantedBy=graphical-session.target, so UWSM starts them at login.
    info "enabling session units"
    run systemctl --user enable neobrix-shell.service neobrix-session.target \
        neobrix-bt-agent.service \
        hypridle.service hyprpolkitagent.service cliphist.service

    # hyprpaper is deliberately not used — the shell draws the wallpaper. Disable it
    # if a previous install (or the distro default) enabled it.
    if systemctl --user --quiet is-enabled hyprpaper.service 2>/dev/null; then
        warn "disabling hyprpaper.service (the shell renders the wallpaper)"
        run systemctl --user disable --now hyprpaper.service
    fi

    # Nothing else may own the notification bus or draw a second bar.
    if systemctl --user --quiet is-enabled noctalia.service 2>/dev/null; then
        warn "disabling noctalia.service (it would compete for the notification bus)"
        run systemctl --user disable --now noctalia.service
    fi
else
    warn "skipping systemd (--no-enable)"
fi

# ── initial application palette ─────────────────────────────────────────────
# Main terminal configs and hyprlock already reference generated includes. Make
# them available before the first session, even if the default Dawn never changes.
# Prefer the running shell, then the last applied palette, then the fresh default.
info "generating the application palette"
palette_mode="$(qs -c neobrix ipc call theme get 2>/dev/null || true)"
if [[ $palette_mode != dawn && $palette_mode != dusk ]]; then
    palette_mode="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/neobrix/theme" 2>/dev/null || true)"
fi
[[ $palette_mode == dawn || $palette_mode == dusk ]] || palette_mode=dawn
run "$REPO/scripts/neobrix-theme" "$palette_mode"
if command -v gsettings >/dev/null; then
    run gsettings set org.gnome.desktop.interface cursor-size 24
    run gsettings set org.gnome.desktop.interface document-font-name 'JetBrainsMono Nerd Font 10'
fi

# ── default applications ─────────────────────────────────────────────────────
if command -v zen-browser >/dev/null && [[ -f /usr/share/applications/zen.desktop ]]; then
    info "setting Zen Browser as the default browser"
    # xdg-settings refuses to act while $BROWSER is set (CachyOS leaves it at
    # firefox, which is not installed here), so clear it for this call only and
    # write the mime defaults regardless — those are what xdg-open actually reads.
    run env -u BROWSER xdg-settings set default-web-browser zen.desktop || \
        warn "xdg-settings declined; relying on the mime defaults below"
    for mime in x-scheme-handler/http x-scheme-handler/https text/html \
                application/xhtml+xml application/x-extension-html; do
        run xdg-mime default zen.desktop "$mime"
    done
    step "$(xdg-mime query default x-scheme-handler/https) handles https"
fi

# ── Zen Browser theming ──────────────────────────────────────────────────────
# Generated into the profile rather than linked from the repo: the profile
# directory name is machine-specific and Zen rewrites prefs.js itself. Both
# palettes go into one stylesheet gated on prefers-color-scheme, so this is not
# mode-specific and a dawn/dusk switch needs no re-run (neobrix-theme calls it
# again regardless). The generator splices a marked block, so it is safe to run
# repeatedly and never clobbers stylesheet rules of your own.
if command -v zen-browser >/dev/null; then
    if ! command -v python3 >/dev/null; then
        warn "python3 not found — skipping Zen theming (the generator needs it)"
    elif [[ -z "$(find "$CFG/zen" -maxdepth 2 -name prefs.js -print -quit 2>/dev/null)" ]]; then
        # A profile only exists after Zen's first run, and there is nothing to
        # write into until it does.
        warn "no Zen profile yet — start Zen once, then: neobrix-generate-zen-theme"
    else
        info "theming Zen Browser"
        run "$REPO/scripts/neobrix-generate-zen-theme"
    fi
fi

if (( GREETER )); then
    stage_greeter || warn "login screen not staged"
else
    info "login screen"
    step "not touched ${c_dim}(opt in with --greeter; it stages only, never activates)${c_off}"
fi

info "done"
cat <<'NEXT'

Next steps
  · log out and back in (greetd → Hyprland) for the full session, or
  · reload in place:
        hyprctl reload
        systemctl --user restart neobrix-session.target

Handy commands
  systemctl --user restart neobrix-shell.service   restart just the shell
  journalctl --user -u neobrix-shell -f            follow shell logs
  qs -c neobrix ipc call panels toggle launcher     drive panels from a script
  install/deploy.sh --restore                       put the previous config back
NEXT
