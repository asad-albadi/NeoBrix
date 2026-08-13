-- Workspaces.
--
-- Five persistent workspaces so the bar's workspace group has a stable width and
-- empty slots stay clickable. The shell renders any further workspaces that
-- appear beyond these.

return function(ctx)
    for i = 1, ctx.workspace_count do
        hl.workspace_rule({ workspace = tostring(i), persistent = true, default = i == 1 })
    end

    -- Scratchpad: a terminal is created on first use, with generous gaps so it
    -- reads as an overlay rather than a tiled window.
    hl.workspace_rule({
        workspace          = "special:scratch",
        on_created_empty   = ctx.launch_prefix .. ctx.apps.terminal,
        gaps_out           = 60,
    })
end
