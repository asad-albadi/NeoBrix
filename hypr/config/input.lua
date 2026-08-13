-- Input.
--
-- Touchpad settings and gestures are only applied when a touchpad exists, so a
-- desktop or VM does not carry configuration for hardware it will never have.

return function(ctx)
    hl.config({
        input = {
            kb_layout    = "us",
            follow_mouse = 1,
            mouse_refocus = true,

            -- Flat acceleration behaves predictably under SPICE/virtio pointer
            -- input and matches what CachyOS set.
            accel_profile = "flat",
            sensitivity   = 0,

            numlock_by_default = true,
        },
    })

    if not ctx.caps.touchpad then
        return
    end

    hl.config({
        input = {
            touchpad = {
                natural_scroll       = true,
                disable_while_typing = true,
                ["tap-to-click"]     = true,
                clickfinger_behavior = true,
                scroll_factor        = 0.4,
            },
        },
    })

    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
    hl.gesture({ fingers = 3, direction = "down",       action = "close" })
end
