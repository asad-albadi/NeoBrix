-- Monitors.
--
-- The catch-all rule uses the preferred mode at automatic position and scale,
-- which is right for this VM's single virtio-gpu output and for most physical
-- machines. Per-output layouts belong in machine/local.lua, e.g.
--
--   hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })

return function(_ctx)
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = "auto",
    })
end
