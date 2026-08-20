-- Keybindings.
--
-- Shell panels go through `hl.dsp.global`, which delivers the press straight to
-- the GlobalShortcut that Quickshell registered over the wayland
-- global-shortcuts protocol. No process is spawned per keypress.
--
-- Repetitive families (workspaces, directions, resize, media) are generated from
-- tables so adding a key is a one-line change; the key lists stay at the call
-- site so nothing is hidden.
--
-- Full list: docs/KEYBINDINGS.md

local helpers = require("lib.helpers")

return function(ctx)
    local mod  = "SUPER"
    local apps = ctx.apps

    local function run(cmd) return hl.dsp.exec_cmd(ctx.launch_prefix .. cmd) end
    local function shell(name) return hl.dsp.global(ctx.shell.appid .. ":" .. name) end

    -- ── shell panels ────────────────────────────────────────────────────────
    helpers.bind_all({ mod .. " + SPACE", mod .. " + D" }, shell("launcher"))
    hl.bind(mod .. " + X",              shell("control"))
    hl.bind(mod .. " + A",              shell("notifications"))
    hl.bind(mod .. " + C",              shell("calendar"))
    hl.bind(mod .. " + V",              shell("clipboard"))
    hl.bind(mod .. " + ESCAPE",         shell("session"))
    hl.bind("CONTROL + ALT + DELETE",   shell("session"))
    hl.bind(mod .. " + SHIFT + T",      shell("theme"))

    -- Restart the shell without touching the compositor.
    hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("systemctl --user restart neobrix-shell.service"))

    -- ── applications ────────────────────────────────────────────────────────
    hl.bind(mod .. " + RETURN",         run(apps.terminal))
    hl.bind(mod .. " + E",              run(apps.file_manager))
    hl.bind(mod .. " + W",              run(apps.browser))
    hl.bind(mod .. " + T",              run(apps.editor))
    if ctx.caps.ide then
        hl.bind(mod .. " + I",          run(apps.ide))
    end
    hl.bind(mod .. " + SHIFT + C",      run(apps.calculator))
    hl.bind("XF86Calculator",           run(apps.calculator))
    hl.bind("CONTROL + SHIFT + ESCAPE", run(apps.monitor))

    -- ── window management ───────────────────────────────────────────────────
    hl.bind(mod .. " + Q",              hl.dsp.window.close())
    hl.bind(mod .. " + F",              hl.dsp.window.fullscreen({ mode = 0 }))
    hl.bind(mod .. " + M",              hl.dsp.window.fullscreen({ mode = 1 }))
    hl.bind(mod .. " + ALT + SPACE",    hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + J",              hl.dsp.layout("togglesplit"))
    hl.bind(mod .. " + O",              hl.dsp.window.pseudo())
    hl.bind(mod .. " + P",              hl.dsp.window.pin())
    hl.bind(mod .. " + SHIFT + ESCAPE", hl.dsp.window.kill())

    -- Focus and movement share one direction table, bound for the arrow keys and
    -- the vim-style keys (';' is "down" because 'J' is togglesplit).
    local DIRECTIONS = {
        { "left", "l" }, { "right", "r" }, { "up", "u" }, { "down", "d" },
        { "H",    "l" }, { "L",     "r" }, { "K",  "u" }, { "semicolon", "d" },
    }
    helpers.pairs_bind(mod, DIRECTIONS, function(dir)
        return hl.dsp.focus({ direction = dir })
    end)
    helpers.pairs_bind(mod .. " + SHIFT", DIRECTIONS, function(dir)
        return hl.dsp.window.move({ direction = dir })
    end)

    hl.bind("ALT + TAB",         hl.dsp.window.cycle_next())
    hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ prev = true }))

    -- Resize with the arrows, repeating while held.
    --
    -- SUPER+CONTROL+SHIFT, because the two easier homes are taken: CONTROL+
    -- arrows now walks the workspaces below, and ALT+arrows is media and volume
    -- further down this file. Adding SHIFT is the only combination left that
    -- collides with nothing.
    local RESIZE = {
        { "left", { -40, 0 } }, { "right", { 40, 0 } },
        { "up",   { 0, -40 } }, { "down",  { 0, 40 } },
    }
    helpers.pairs_bind(mod .. " + CONTROL + SHIFT", RESIZE, function(delta)
        return hl.dsp.window.resize({ x = delta[1], y = delta[2] })
    end, { repeating = true })

    -- Mouse.
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- ── workspaces ──────────────────────────────────────────────────────────
    -- Generated: SUPER+N switches, SUPER+SHIFT+N moves the window there, for
    -- workspaces 1..10 with 10 on the '0' key.
    for i = 1, 10 do
        local key = i % 10
        hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, silent = true }))
    end

    -- e-1/e+1 rather than -1/+1, matching the wheel and CONTROL+TAB: it steps
    -- between workspaces that exist instead of walking into empty ones.
    hl.bind(mod .. " + CONTROL + left",  hl.dsp.focus({ workspace = "e-1" }))
    hl.bind(mod .. " + CONTROL + right", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mod .. " + CONTROL + TAB",   hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mod .. " + mouse_down",      hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mod .. " + mouse_up",        hl.dsp.focus({ workspace = "e-1" }))

    -- "Go back to where I was". Hyprland's Lua workspace parser has no
    -- "previous" token, so the last workspace is tracked from the event stream —
    -- which is more accurate than the legacy token anyway, because it also
    -- notices switches made by clicking the bar.
    local previous_workspace, current_workspace
    hl.on("workspace.active", function()
        local active = hl.get_active_workspace()
        if not active then return end
        if current_workspace and current_workspace ~= active.id then
            previous_workspace = current_workspace
        end
        current_workspace = active.id
    end)

    hl.bind(mod .. " + TAB", function()
        if previous_workspace then
            hl.dispatch(hl.dsp.focus({ workspace = previous_workspace }))
        end
    end)

    -- Scratchpad.
    hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"))
    hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch", silent = true }))

    -- Move the whole workspace between monitors.
    hl.bind(mod .. " + SHIFT + comma",  hl.dsp.workspace.move({ monitor = "-1" }))
    hl.bind(mod .. " + SHIFT + period", hl.dsp.workspace.move({ monitor = "+1" }))

    -- ── screenshots and picking ─────────────────────────────────────────────
    local SCREENSHOTS = {
        { "PRINT",                   "region" },
        { "SHIFT + PRINT",           "screen" },
        { mod .. " + PRINT",         "window" },
        { mod .. " + SHIFT + PRINT", "edit" },
    }
    for _, entry in ipairs(SCREENSHOTS) do
        hl.bind(entry[1], hl.dsp.exec_cmd("neobrix-screenshot " .. entry[2]))
    end
    hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -n"))

    -- ── session ─────────────────────────────────────────────────────────────
    hl.bind(mod .. " + BACKSPACE", hl.dsp.exec_cmd("loginctl lock-session"))

    -- ── hardware keys ───────────────────────────────────────────────────────
    -- Volume goes through wpctl so it behaves identically from a TTY; the shell
    -- notices the PipeWire change and shows the OSD either way.
    local VOLUME = {
        { "XF86AudioRaiseVolume", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+" },
        { "XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    }
    for _, entry in ipairs(VOLUME) do
        hl.bind(entry[1], hl.dsp.exec_cmd(entry[2]), { locked = true, repeating = true })
    end
    hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

    -- Brightness keys only exist where there is a backlight to change.
    if ctx.caps.backlight then
        hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true })
    end

    -- Media is handled by the shell over MPRIS — no playerctl dependency.
    local MEDIA = {
        { "XF86AudioPlay",  "media-toggle" },
        { "XF86AudioPause", "media-toggle" },
        { "XF86AudioNext",  "media-next" },
        { "XF86AudioPrev",  "media-previous" },
    }
    for _, entry in ipairs(MEDIA) do
        hl.bind(entry[1], shell(entry[2]), { locked = true })
    end

    -- Keyboard-only equivalents for machines without media keys.
    hl.bind(mod .. " + ALT + up",     hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
    hl.bind(mod .. " + ALT + down",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { repeating = true })
    hl.bind(mod .. " + ALT + M",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
    hl.bind(mod .. " + ALT + N",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
    hl.bind(mod .. " + ALT + right",  shell("media-next"))
    hl.bind(mod .. " + ALT + left",   shell("media-previous"))
    hl.bind(mod .. " + ALT + RETURN", shell("media-toggle"))
end
