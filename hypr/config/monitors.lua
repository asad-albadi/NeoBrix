-- Monitors.
--
-- The catch-all rule uses the preferred mode at automatic position and scale,
-- which is right for this VM's single virtio-gpu output and for most physical
-- machines. Per-output layouts belong in machine/local.lua, e.g.
--
--   hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })

return function(ctx)
    -- A saved layout, if there is one. neobrix-monitors writes it from the
    -- Displays tab; it is machine-local and gitignored, and it opens with the
    -- same catch-all below so an output it does not mention still comes up.
    local ok, saved = pcall(require, "machine.monitors")
    if ok and type(saved) == "function" then
        saved(ctx)
        return
    end

    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = "auto",
    })
end
