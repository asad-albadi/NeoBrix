# Fish — the shell kitty opens.
#
# Interactive only: guarded on `status is-interactive`, so `fish -c` in a script
# pays none of it and cannot find a greeting in its output.

if status is-interactive
    # fastfetch as the greeting, configured by terminal/fastfetch/config.jsonc.
    #
    # Overriding the function, not setting $fish_greeting: fish's default
    # fish_greeting is what prints that variable, so replacing the function is
    # what replaces the greeting. Doing both would be one of them doing nothing.
    function fish_greeting
        if command -q fastfetch
            fastfetch
        end
    end

    # ls is eza, laid out like `ls -ltr`: long, oldest first, newest last, which
    # is the ordering worth having in a directory you are working in.
    #
    # --sort=modified is already oldest-first, so there is no --reverse here;
    # adding one would put the newest at the top, which is the opposite of -ltr.
    # Sizes are human-readable by default (3.1M, 1.5k), so nothing asks for it.
    #
    # --tree --level=2 shows one level inside each subdirectory, drawn in the
    # name column of the long listing — permissions, sizes and dates stay. A
    # depth is essential: --tree without one recurses without limit and floods
    # the terminal in any real project. Both stay overridable, since a later
    # value of a flag wins: `ls -L 4` goes deeper, and `ls -L 1` collapses back
    # to a listing with nothing expanded.
    #
    # Icons are decided here rather than with --icons=auto. eza's auto did not
    # emit them under a pty in testing, and a flag whose detection cannot be
    # observed working is not one to ship; `isatty stdout` is a question fish can
    # answer directly. Piped output therefore stays free of glyphs, so `ls | grep`
    # and `ls > file` behave.
    if command -q eza
        function ls --wraps eza --description 'eza, long and oldest-first'
            if isatty stdout
                command eza --long --icons=always --tree --level=2 --sort=modified $argv
            else
                command eza --long --tree --level=2 --sort=modified $argv
            end
        end
    end
end
