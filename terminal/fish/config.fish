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
end
