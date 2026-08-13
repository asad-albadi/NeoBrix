-- Window and layer rules.
--
-- The Lua API takes a `match` table and the rule fields as siblings, which reads
-- far better than the legacy `windowrule[name] { match { ... } }` block form and
-- lets repetitive families be generated instead of repeated.
--
-- Class/title values were checked against real windows with `hyprctl clients`
-- and `hyprctl layers` rather than guessed.

return function(ctx)
    -- ── floating defaults ───────────────────────────────────────────────────
    hl.window_rule({
        name  = "float-center",
        match = { float = true },

        center          = true,
        persistent_size = true,
    })

    -- ── picture-in-picture ──────────────────────────────────────────────────
    hl.window_rule({
        name  = "picture-in-picture",
        match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },

        float             = true,
        pin               = true,
        keep_aspect_ratio = true,
        size              = { "min(monitor_w, monitor_h)*0.28", "min(monitor_w, monitor_h)*0.28" },
        move              = { "monitor_w-window_w-24", "24" },
    })

    -- ── dialogs, modals and pickers ─────────────────────────────────────────
    -- One table, one rule each: adding a floating utility is a one-line change.
    local float_by_class = {
        ["portal-dialogs"]  = "^([Xx]dg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\..*)$",
        ["share-picker"]    = "^(hyprland-share-picker)$",
        ["settings-utils"]  = "^(qt[56]ct|kvantummanager|nwg-look|org\\.pulseaudio\\.pavucontrol|blueman-manager|nm-connection-editor|nm-applet)$",
        ["colour-picker"]   = "^(hyprpicker)$",
    }
    for name, class in pairs(float_by_class) do
        hl.window_rule({ name = name, match = { class = class }, float = true })
    end

    hl.window_rule({
        name  = "common-dialogs",
        match = { title = "^(Open|Open File|Open Files|Open Folder|Save As|Save File|Choose Files|File Upload|Authentication Required|Confirm to replace files|File Operation Progress|Library)$" },
        float = true,
    })

    -- The polkit agent must keep focus until it is answered, or the password
    -- field silently loses keystrokes to whatever spawned it.
    hl.window_rule({
        name  = "polkit-agent",
        match = { class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org\\.kde\\.polkit-kde-authentication-agent-1)$" },

        float        = true,
        stay_focused = true,
    })

    hl.window_rule({
        name  = "network-editor-size",
        match = { class = "^(nm-connection-editor)$" },
        size  = { "60%", "60%" },
    })

    -- ── applications ────────────────────────────────────────────────────────
    -- Dolphin floats for quick file work, but its progress/config windows keep
    -- default behaviour.
    hl.window_rule({
        name  = "dolphin",
        match = {
            class = "^(org\\.kde\\.dolphin)$",
            title = "negative:^(Moving|Copying|Deleting|Extract|Compress|Progress|Configure|Properties|Create New).*$",
        },

        float = true,
        size  = { "55%", "62%" },
    })

    hl.window_rule({
        name  = "calculator",
        match = { class = "^(.*[Cc]alculator.*|gnome-calculator)$" },

        float = true,
        size  = { "max(monitor_w, monitor_h)*0.19", "min(monitor_w, monitor_h)*0.52" },
    })

    hl.window_rule({
        name  = "screenshot-editor",
        match = { class = "^(.*satty.*)$" },

        float = true,
        size  = { "72%", "72%" },
    })

    -- Media players and browsers stay fully opaque regardless of any global
    -- opacity setting.
    local opaque = {
        ["opaque-media"]    = "^(mpv|org\\.kde\\.haruna|.*vlc.*|org\\.kde\\.gwenview|imv)$",
        ["opaque-browsers"] = "^(zen|zen-browser|zen-alpha|chromium|google-chrome|brave-browser)$",
    }
    for name, class in pairs(opaque) do
        hl.window_rule({ name = name, match = { class = class }, opacity = "1.0 override" })
    end

    -- ── behaviour fixes ─────────────────────────────────────────────────────
    -- Most toolkits request maximize on launch, which is meaningless when tiling.
    hl.window_rule({
        name           = "suppress-maximize-events",
        match          = { class = ".*" },
        suppress_event = "maximize",
    })

    -- XWayland drag-and-drop surfaces are unmapped, titleless helpers that must
    -- not take focus, or drags break mid-gesture.
    hl.window_rule({
        name  = "fix-xwayland-drags",
        match = {
            class      = "^$",
            title      = "^$",
            xwayland   = true,
            float      = true,
            fullscreen = false,
        },
        no_focus = true,
    })

    -- ── games ───────────────────────────────────────────────────────────────
    hl.window_rule({
        name  = "games",
        match = { class = "^(steam_app.*|gamescope)$" },

        fullscreen_state = 2,
        immediate        = true,
        content          = "game",
    })

    hl.window_rule({
        name  = "steam-dialogs",
        match = { class = "^(steam)$", title = "^(Friends List|Steam Settings)$" },
        float = true,
    })

    -- ── layer rules (the Quickshell surfaces) ───────────────────────────────
    -- The shell draws its own hard shadows on opaque cards, so no blur anywhere.
    local layer_animations = {
        ["neobrix-bar"]           = "popin 92%",
        ["neobrix-popup"]         = "fade",
        ["neobrix-notifications"] = "slide right",
    }
    for namespace, style in pairs(layer_animations) do
        hl.layer_rule({
            name      = "anim-" .. namespace,
            match     = { namespace = "^(" .. namespace .. ")$" },
            animation = style,
        })
    end

    -- The OSD repeats on every volume keypress; animating it stutters. The
    -- colour picker must not be animated either or it samples the wrong pixel.
    hl.layer_rule({
        name    = "no-anim-osd",
        match   = { namespace = "^(neobrix-osd|hyprpicker|selection)$" },
        no_anim = true,
    })
end
