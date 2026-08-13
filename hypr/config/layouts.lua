-- Layouts. dwindle is the default; master is configured so switching to it in
-- machine/local.lua needs no extra setup.

return function(_ctx)
    hl.config({
        dwindle = {
            preserve_split = true,
            smart_split    = false,
            force_split    = 2,   -- always split to the right/bottom
        },

        master = {
            new_status = "master",
            mfact      = 0.55,
        },
    })
end
