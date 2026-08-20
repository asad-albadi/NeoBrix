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
    set -l c_time   brblack

    # ── line one: where, and when ───────────────────────────────────────────
    #
    # The pieces are built as plain strings first so their width can be measured
    # for the right-aligned time. Measuring the emitted text is not an option:
    # it carries colour escapes, which take columns in a string and none on a
    # screen.
    set -l host ''
    # The host is noise on the machine you are sitting at, and the first thing
    # you want to be certain of when you are not.
    if set -q SSH_TTY; or set -q SSH_CONNECTION
        set host $USER'@'(prompt_hostname)' '
    end

    # -d 0 defeats fish's abbreviation, which renders ~/Projects/neobrix as
    # ~/P/neobrix and leaves you guessing which P.
    set -l path (prompt_pwd -d 0)

    # symbolic-ref fails outside a repository and on a detached HEAD; the short
    # hash covers the second. Deliberately no dirty marker: that walks the work
    # tree, and a prompt that stalls in a large repository is worse than one
    # that says less.
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    set -l vcs ''
    test -n "$branch"; and set vcs '   '$branch

    # When the prompt was drawn, not the current time — a prompt sitting on
    # screen keeps the time it was printed at, which is what makes it useful for
    # reading back how long something took.
    set -l now (date '+%H:%M')

    # 2 for the '▌ ' rule. One space minimum, so a path wide enough to fill the
    # terminal pushes the time along instead of wrapping the line.
    set -l used (math 2 + (string length -- $host$path$vcs) + (string length -- $now))
    set -l pad (math max 1, $COLUMNS - $used)

    set_color $c_rule
    echo -n '▌ '
    if test -n "$host"
        set_color $c_host
        echo -n $host
    end
    set_color $c_path
    echo -n $path
    if test -n "$vcs"
        set_color $c_branch
        echo -n $vcs
    end
    set_color $c_time
    echo -n (string repeat -n $pad ' ')$now

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
