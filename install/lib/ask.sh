# Shared prompting, sourced by bootstrap.sh, cleanup.sh and uninstall.sh.
#
# The one rule that matters: when the installer is run as `curl … | bash`, stdin
# *is* the script. Reading from stdin would consume the remaining source or hit
# EOF immediately, which is the classic way a piped installer either dies or
# silently takes an answer nobody gave. Every question is read from /dev/tty.
#
# With no terminal at all — CI, `podman run` without -t, a cron job — nothing is
# asked. The default applies and is printed, so the log says what was decided and
# by whom.

# Set by the caller to 1 to answer every question with its default.
: "${ASSUME_YES:=0}"

# Detect a terminal by *opening* /dev/tty, not by testing its permission bits.
# The device node exists with rw bits inside a container started without -t, so
# `[[ -r /dev/tty ]]` says yes and the first prompt then fails on ENXIO — which
# under set -e ends the run instead of falling back to the default. Opening it is
# the only honest test.
NB_TTY=""
if { exec 3<>/dev/tty; } 2>/dev/null; then
    NB_TTY=/dev/tty
    exec 3>&-
fi

if [[ -z ${c_ok:-} ]]; then
    c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
fi

# confirm <yes|no> <question>   → exit status 0 for yes
confirm() {
    local default="$1" question="$2" reply=""

    if (( ASSUME_YES )) || [[ -z $NB_TTY ]]; then
        local why="no terminal"
        (( ASSUME_YES )) && why="--yes"
        printf '  %s·%s %s %s[%s → %s]%s\n' \
            "$c_dim" "$c_off" "$question" "$c_dim" "$why" "$default" "$c_off"
        [[ $default == yes ]]
        return
    fi

    local hint="[y/N]"
    [[ $default == yes ]] && hint="[Y/n]"
    printf '%s?%s %s %s ' "$c_warn" "$c_off" "$question" "$hint" > "$NB_TTY"
    IFS= read -r reply < "$NB_TTY" || reply=""

    case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
        y|yes) return 0 ;;
        n|no)  return 1 ;;
        *)     [[ $default == yes ]] ;;
    esac
}
