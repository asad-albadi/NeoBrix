#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Neobrix bootstrap — the one-liner target.
#
#      curl -fsSL https://raw.githubusercontent.com/asad-albadi/NeoBrix/main/install/bootstrap.sh | bash
#
#  This file is deliberately small: it checks the machine, fetches the
#  repository, and hands off to install/packages.sh and install/deploy.sh, which
#  are versioned, reviewable and already do the work. Nothing substantial happens
#  here — if you are reading this before running it, that is the point, and there
#  is a download-then-inspect form in the README.
#
#  Run with --help for the flags.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_URL="${NEOBRIX_REPO:-https://github.com/asad-albadi/NeoBrix.git}"
DIR="${NEOBRIX_DIR:-$HOME/Projects/neobrix}"
BRANCH="${NEOBRIX_BRANCH:-main}"

ASSUME_YES=0
DO_PACKAGES=1
DO_GREETER=0
DO_UNINSTALL=0

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s==>%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '%s==>%s %s\n' "$c_err" "$c_off" "$*" >&2; }
step() { printf '  %s·%s %s\n' "$c_dim" "$c_off" "$*"; }

# Embedded rather than sliced out of this file with sed: run as
# `curl … | bash`, $0 is "bash", so reading "$0" fails with "sed: can't read
# bash" and --help printed nothing at all in the one invocation the README leads
# with. Embedding also decouples the text from the header's line count, which is
# the other way this broke — a hardcoded range silently truncating as the header
# grew.
usage() {
    cat <<'USAGE'
Neobrix bootstrap — install a Neobrix desktop on CachyOS or Arch.

  curl -fsSL https://raw.githubusercontent.com/asad-albadi/NeoBrix/main/install/bootstrap.sh | bash

Checks the machine, clones the repository, and hands off to install/packages.sh
and install/deploy.sh, which do the real work and are worth reading first.

  --yes           non-interactive: safe defaults, and removes nothing
  --no-packages   skip pacman; only link configuration
  --greeter       also STAGE the login screen: writes /etc/greetd and a recovery
                  file, but never replaces config.toml and never enables greetd.
                  Activation is a separate, interactive-only step.
  --dir <path>    where to clone (default ~/Projects/neobrix, or $NEOBRIX_DIR)
  --uninstall     undo: restore backups, disable the units, report the rest
  --help          this text

Piped, flags must be handed past bash itself, or bash takes them as its own:

  curl -fsSL .../install/bootstrap.sh | bash -s -- --greeter --dir ~/src/neobrix

Environment: NEOBRIX_DIR, NEOBRIX_REPO, NEOBRIX_BRANCH
USAGE
}

# Which step we are on, so a failure says where rather than just exiting.
STEP="argument parsing"
on_exit() {
    local ec=$?
    (( ec == 0 )) && return 0
    err "failed during: $STEP (exit $ec)"
    err "nothing further was attempted; re-running this script is safe"
}
trap on_exit EXIT

while (( $# )); do
    case "$1" in
        -y|--yes)      ASSUME_YES=1 ;;
        --no-packages) DO_PACKAGES=0 ;;
        --greeter)     DO_GREETER=1 ;;
        --uninstall)   DO_UNINSTALL=1 ;;
        --dir)         shift; [[ ${1:-} ]] || { err "--dir needs a path"; exit 2; }; DIR="$1" ;;
        --dir=*)       DIR="${1#*=}" ;;
        -h|--help)     usage; exit 0 ;;
        *)             err "unknown option: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

# Prompting is deliberately not implemented here: install/lib/ask.sh is the one
# copy, and this script sources it once the repository exists. The rule it
# encodes matters for this file in particular — run as `curl … | bash`, stdin is
# the script itself, so anything reading stdin would eat the remaining source.
# That applies to every child process too, not just to questions asked here; see
# the `child` helper below, which is how the children are invoked.

# ── refuse the wrong machine ─────────────────────────────────────────────────
STEP="environment checks"

if (( EUID == 0 )); then
    err "do not run this as root."
    err "It installs a desktop for one user and calls sudo only where needed."
    err "Run it as your normal user."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    distro="unknown"
    [[ -r /etc/os-release ]] && distro="$(. /etc/os-release; echo "${PRETTY_NAME:-$ID}")"
    err "this installer targets Arch-based systems (CachyOS, Arch, EndeavourOS)."
    err "Found: $distro — no pacman here."
    err "Neobrix itself is not distro-specific; only install/packages.sh is."
    exit 1
fi

# git is the only hard requirement: this script clones and hands off, and it
# does not use curl itself — curl is how you fetched *it*. sudo is checked only
# where it is actually needed, so `--uninstall` still works on a machine without
# it (uninstalling touches nothing outside $HOME).
if ! command -v git >/dev/null 2>&1; then
    err "git is required to fetch the repository:  sudo pacman -S git"
    exit 1
fi

NO_SUDO=0
command -v sudo >/dev/null 2>&1 || NO_SUDO=1
if (( NO_SUDO )) && (( DO_PACKAGES )) && ! (( DO_UNINSTALL )); then
    err "sudo is required to install packages:  pacman -S sudo"
    err "or re-run with --no-packages if the packages are already there"
    exit 1
fi
if (( NO_SUDO )) && (( DO_GREETER )); then
    err "sudo is required to stage the login screen (it writes /etc/greetd)"
    exit 1
fi

# ── fetch ────────────────────────────────────────────────────────────────────
STEP="fetching the repository into $DIR"
if [[ -d $DIR/.git ]]; then
    info "updating $DIR"
    git -C "$DIR" remote set-url origin "$REPO_URL"
    # --ff-only: never invent a merge commit in someone's clone, and never
    # rewrite it. If it cannot fast-forward, say which of the two reasons it is
    # and how to resolve it — git's own output is a wall of hints.
    if ! git_out="$(git -C "$DIR" pull --ff-only origin "$BRANCH" 2>&1)"; then
        warn "$DIR could not be fast-forwarded, so it was left exactly as it is."
        local_commits="$(git -C "$DIR" log --oneline "origin/$BRANCH..HEAD" 2>/dev/null || true)"
        if [[ -n $local_commits ]]; then
            warn "It has commits that upstream does not:"
            printf '%s\n' "$local_commits" | head -5 | sed 's/^/      /'
            warn "Move them aside or rebase, then re-run:"
            step "cd $DIR && git rebase origin/$BRANCH"
            step "cd $DIR && git branch my-changes && git reset --hard origin/$BRANCH   # keep them on a branch"
        elif ! git -C "$DIR" diff --quiet 2>/dev/null || ! git -C "$DIR" diff --cached --quiet 2>/dev/null; then
            warn "It has uncommitted changes that the update would overwrite:"
            git -C "$DIR" diff --name-only HEAD 2>/dev/null | head -5 | sed 's/^/      /'
            warn "Commit or stash them, then re-run:"
            step "cd $DIR && git stash"
        else
            warn "git said:"
            printf '%s\n' "$git_out" | tail -3 | sed 's/^/      /'
        fi
        warn "Nothing here discards your work — that is why it stops instead."
        exit 1
    fi
else
    info "cloning into $DIR"
    mkdir -p "$(dirname "$DIR")"
    git clone --branch "$BRANCH" "$REPO_URL" "$DIR"
fi
step "$(git -C "$DIR" log -1 --format='%h %s')"

# Now that the repo is here, use its prompt helper rather than a second copy.
# shellcheck source=lib/ask.sh
source "$DIR/install/lib/ask.sh"

# ── stdin for the children ───────────────────────────────────────────────────
# Run as `curl … | bash`, this script's stdin is its own remaining source. A
# child that reads stdin therefore does not read the user, it reads the rest of
# the install and consumes it: `sudo pacman -S` asked "Proceed with
# installation? [Y/n]", swallowed everything below the packages step, and the
# run ended there having deployed nothing. Every fresh install hit it.
#
# So no child inherits our stdin. It gets the terminal when there is one, which
# keeps pacman's confirmation a real question the user can still answer no to —
# that prompt is worth keeping, since repository packages can displace -git
# builds someone else on the machine depends on. With no terminal it gets
# /dev/null, so a child that reads stdin sees EOF instead of source code.
#
# This is set here, at the call sites, rather than around the one pacman line:
# the next child to grow a prompt is then already covered.
NB_CHILD_STDIN=/dev/null
[[ -n ${NB_TTY:-} ]] && NB_CHILD_STDIN="$NB_TTY"
child() { "$@" < "$NB_CHILD_STDIN"; }

# And tell them whether anyone is there to answer, because /dev/null is not a
# "no terminal" a child can detect once it has been handed it: pacman would read
# EOF, take it for a refusal, and install nothing.
export NB_ASSUME_YES="$ASSUME_YES"

# ── uninstall short-circuit ──────────────────────────────────────────────────
if (( DO_UNINSTALL )); then
    STEP="uninstalling"
    exec "$DIR/install/uninstall.sh" $( (( ASSUME_YES )) && echo --yes ) < "$NB_CHILD_STDIN"
fi

# ── packages ─────────────────────────────────────────────────────────────────
if (( DO_PACKAGES )); then
    STEP="installing packages"
    info "installing packages (sudo pacman)"
    child "$DIR/install/packages.sh"
else
    warn "skipping packages (--no-packages)"
fi

# ── competing setups ─────────────────────────────────────────────────────────
# Detects only; every removal is confirmed one item at a time, defaults to
# keeping, and backs up to ~/.config-backup/ first.
STEP="checking for competing desktop setups"
child "$DIR/install/cleanup.sh" $( (( ASSUME_YES )) && echo --yes )

# ── deploy ───────────────────────────────────────────────────────────────────
STEP="deploying configuration"
child "$DIR/install/deploy.sh"

# ── login screen, last and opt-in ────────────────────────────────────────────
# The desktop is in place by now, so a greeter problem cannot also mean a broken
# desktop. deploy.sh --greeter stages /etc/greetd and prints its own recovery
# instructions; it never enables greetd on its own.
# --greeter with --yes is deliberately allowed: an explicit flag is consent, and
# what it does is bounded. deploy.sh --greeter refuses outright if regreet, cage
# or greetd are missing (before writing anything), writes RECOVERY and the agreety
# fallback before the Neobrix config, and leaves config.toml and greetd untouched.
# So the worst outcome of a non-interactive run is a staged greeter nobody
# activated — never a machine that cannot log in.
STEP="staging the login screen"
if (( DO_GREETER )); then
    child "$DIR/install/deploy.sh" --greeter-only
    # Staging succeeded; activation is a separate, stricter question that
    # neobrix-greeter asks itself — and only ever at a terminal.
    if (( ! ASSUME_YES )) && [[ -n ${NB_TTY:-} ]]; then
        child "$DIR/scripts/neobrix-greeter" enable || true
    else
        step "not activated: activation only happens when asked at a terminal"
        step "later, from a terminal:  neobrix greeter enable"
    fi
elif (( NO_SUDO )); then
    step "login screen untouched — no sudo on this machine to write /etc/greetd"
elif confirm no "Also stage the Neobrix login screen? Writes /etc/greetd (sudo); staging alone does not switch anything"; then
    child "$DIR/install/deploy.sh" --greeter-only
    if (( ! ASSUME_YES )) && [[ -n ${NB_TTY:-} ]]; then
        child "$DIR/scripts/neobrix-greeter" enable || true
    fi
else
    step "login screen untouched. Log into the Neobrix session first, then:"
    step "    neobrix greeter enable      # asks before changing anything"
fi

STEP="finishing"
info "done"
cat <<NEXT

Neobrix is deployed. To start it:
  · log out and back in, choosing "Hyprland (uwsm-managed)" at your login screen
  · or, in a running Hyprland session:
        hyprctl reload
        systemctl --user restart neobrix-session.target

  Read first          $DIR/README.md
  Undo everything     $DIR/install/bootstrap.sh --uninstall
  Backups of anything replaced   ~/.config-backup/
NEXT
