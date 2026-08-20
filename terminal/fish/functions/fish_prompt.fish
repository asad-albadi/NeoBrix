# Neobrix prompt: where you are on one line, the line you type on below it.
#
# Autoloaded by fish from ~/.config/fish/functions, so it can be overridden by
# dropping a file of the same name earlier on $fish_function_path.

function fish_prompt --description 'Neobrix prompt'
    # First thing, before anything below runs a command and replaces it.
    set -l last_status $status

    # Named colours rather than hex. fish resolves these through the terminal's
    # 16-colour palette, which neobrix-theme regenerates for dawn and dusk, so
    # the prompt follows the desktop's mode and no colour is decided here.
    set -l c_rule   brblack
    set -l c_host   yellow
    set -l c_path   cyan
    set -l c_branch magenta

    # ── line one: where ─────────────────────────────────────────────────────
    set_color $c_rule
    echo -n '▌ '

    # The host is noise on the machine you are sitting at, and the first thing
    # you want to be certain of when you are not.
    if set -q SSH_TTY; or set -q SSH_CONNECTION
        set_color $c_host
        echo -n $USER'@'(prompt_hostname)' '
    end

    # -d 0 defeats fish's abbreviation, which renders ~/Projects/neobrix as
    # ~/P/neobrix and leaves you guessing which P.
    set_color $c_path
    echo -n (prompt_pwd -d 0)

    # symbolic-ref fails outside a repository and on a detached HEAD; the short
    # hash covers the second. Deliberately no dirty marker: that walks the work
    # tree, and a prompt that stalls in a large repository is worse than one
    # that says less.
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    if test -n "$branch"
        set_color $c_branch
        echo -n '   '$branch
    end

    # ── line two: the line you type on ──────────────────────────────────────
    echo
    if test $last_status -ne 0
        set_color red
        echo -n '▸ ✗ '$last_status' '
    else
        set_color green
        echo -n '▸ '
    end
    set_color normal
end
