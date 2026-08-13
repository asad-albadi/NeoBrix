-- Look and feel — neo-brutalist.
--
-- The defining choices:
--   · thick borders (3px), near-black on inactive windows, peach on the active
--   · hard offset shadows (sharp = true, no blur, no spread) so windows sit on
--     the desktop like the cards in the shell
--   · fully opaque windows and no background blur — brutalism is flat, and this
--     also keeps a virtio-gpu VM responsive
--   · modest rounding matching the shell's card radius

return function(ctx)
    local p = ctx.palette

    hl.config({
        general = {
            gaps_in     = 4,
            gaps_out    = 8,
            border_size = 3,

            col = {
                active_border   = p.peach,
                inactive_border = p.ink,
            },

            resize_on_border        = true,
            extend_border_grab_area = 10,
            hover_icon_on_border    = true,

            layout        = "dwindle",
            allow_tearing = false,

            snap = {
                enabled        = true,
                border_overlap = false,
            },
        },

        decoration = {
            rounding       = 10,
            rounding_power = 2.0,

            -- Opaque. Terminals set their own transparency if they want it.
            active_opacity     = 1.0,
            inactive_opacity   = 1.0,
            fullscreen_opacity = 1.0,
            dim_inactive       = false,
            dim_special        = 0.35,

            -- The signature: a solid offset slab behind every window, matching
            -- BrixCard in the shell.
            --
            -- Hyprland expands the shadow by `range` in every direction and then
            -- shifts it by `offset`, so the visible band is (range + offset) on
            -- the bottom/right and (range - offset) on the top/left. Keeping
            -- range <= offset leaves the top/left flush and range + offset sets
            -- the slab width. range 12 / offset 6 gave an 18px band pressed
            -- against the border, which read as a lopsided border rather than a
            -- shadow; 3/3 gives a clean 6px slab.
            shadow = {
                enabled        = true,
                sharp          = true,
                range          = 3,
                render_power   = 1,
                offset         = "3 3",
                scale          = 1.0,
                color          = p.ink,
                color_inactive = p.ink_soft,
            },

            -- Blur is the most expensive effect on a software rasteriser, and a
            -- flat design does not want it. Re-enable per machine if you have a
            -- real GPU and prefer it.
            blur = {
                enabled = false,
            },
        },

        group = {
            col = {
                border_active          = p.peach,
                border_inactive        = p.ink,
                border_locked_active   = p.lavender,
                border_locked_inactive = p.ink,
            },
            groupbar = {
                enabled     = true,
                font_family = "JetBrainsMono Nerd Font",
                font_size   = 10,
                height      = 18,
                rounding    = 6,
                gradients   = false,
                col = {
                    active          = p.peach,
                    inactive        = p.cream,
                    locked_active   = p.lavender,
                    locked_inactive = p.cream,
                },
                text_color          = p.ink,
                text_color_inactive = p.ink,
            },
        },

        misc = {
            disable_hyprland_logo    = true,
            disable_splash_rendering = true,
            force_default_wallpaper  = 0,
            font_family              = "JetBrainsMono Nerd Font",
            col = {
                splash = p.peach,
            },

            -- Terminals that spawn a GUI app get hidden until it exits.
            enable_swallow = true,
            swallow_regex  = "(?i)^(kitty|alacritty|foot|ghostty|konsole|gnome-terminal|xfce4?-terminal)$",

            middle_click_paste         = false,
            focus_on_activate          = true,
            vrr                        = 3,
            initial_workspace_tracking = 1,
        },

        cursor = {
            hide_on_key_press = false,
            inactive_timeout  = 0,
        },

        xwayland = {
            force_zero_scaling = true,
        },

        ecosystem = {
            no_update_news  = true,
            no_donation_nag = true,
        },

        render = {
            -- Direct scanout is pointless under a virtualised GPU and can cause
            -- blank frames; the shell's layer surfaces block it anyway.
            direct_scanout = 0,
        },
    })
end
