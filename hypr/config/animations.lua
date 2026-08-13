-- Animations — short, decisive, no float or glide.
--
-- Brutalism does not ease gently; everything snaps. These speeds are also cheap
-- enough for the software rasteriser this VM falls back to.

return function(ctx)
    hl.config({ animations = { enabled = true } })

    hl.curve("brix", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
    hl.curve("snap",   { type = "bezier", points = { { 0.2, 0 },  { 0, 1 } } })
    hl.curve("linear", { type = "bezier", points = { { 0, 0 },    { 1, 1 } } })

    -- leaf = the animation tree node; see `hyprctl animations`.
    local animations = {
        { leaf = "global",              speed = 3, bezier = "brix" },
        { leaf = "windowsIn",           speed = 3, bezier = "brix", style = "popin 92%" },
        { leaf = "windowsOut",          speed = 2, bezier = "snap",   style = "popin 94%" },
        { leaf = "windowsMove",         speed = 3, bezier = "brix" },
        { leaf = "border",              speed = 4, bezier = "linear" },
        { leaf = "fade",                speed = 3, bezier = "snap" },
        { leaf = "workspaces",          speed = 3, bezier = "brix", style = "slide" },
        { leaf = "specialWorkspaceIn",  speed = 3, bezier = "brix", style = "slidevert" },
        { leaf = "specialWorkspaceOut", speed = 3, bezier = "snap",   style = "slidevert" },
        { leaf = "layersIn",            speed = 3, bezier = "brix", style = "popin 94%" },
        { leaf = "layersOut",           speed = 2, bezier = "snap",   style = "popin 96%" },
    }

    for _, animation in ipairs(animations) do
        animation.enabled = true
        hl.animation(animation)
    end
end
