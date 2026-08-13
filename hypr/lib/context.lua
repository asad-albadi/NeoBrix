-- Shared context: the values every module needs, resolved once.
--
-- This is where "what is this machine" and "what are my apps" live, so the
-- modules stay declarative and the same tree runs unchanged on a laptop, a
-- desktop or this VM.

local helpers = require("lib.helpers")

local ctx = {}

-- ── applications ────────────────────────────────────────────────────────────
-- One definition each, referenced by binds and rules alike.
ctx.apps = {
    terminal     = "alacritty",
    file_manager = "dolphin",
    browser      = "zen-browser",
    editor       = "gnome-text-editor --new-window",
    calculator   = "gnome-calculator",
    monitor      = "alacritty -e btop",
}

-- UWSM manages the session, so graphical applications are launched into their
-- own systemd scope rather than as children of the compositor. Without this a
-- crashing Hyprland (or a restarted shell) would take the user's windows down
-- with it, and nothing would be accounted per-app in the cgroup tree.
ctx.launch_prefix = helpers.has_exec("uwsm") and "uwsm app -- " or ""

-- ── palette ─────────────────────────────────────────────────────────────────
-- The Neobrix "dawn" accents, kept in sync with quickshell/Theme/Theme.qml.
ctx.palette = {
    peach     = "rgba(f6a97eff)",
    pistachio = "rgba(afdca0ff)",
    lavender  = "rgba(c4aef2ff)",
    pink      = "rgba(f5a8bcff)",
    sky       = "rgba(9fc4e8ff)",
    butter    = "rgba(ebc963ff)",
    ink       = "rgba(171210ff)",
    ink_soft  = "rgba(17121080)",
    cream     = "rgba(f0e2d2ff)",
    error     = "rgba(e8776bff)",
}

-- ── machine capabilities ────────────────────────────────────────────────────
-- Probed, not assumed: the same config then behaves correctly on hardware that
-- has a touchpad/battery/backlight and on one that does not.
ctx.caps = {
    virtual_machine = helpers.is_virtual_machine(),
    touchpad        = helpers.has_touchpad(),
    battery         = helpers.has_battery(),
    backlight       = helpers.has_backlight(),
}

-- Number of persistent workspaces; also how many workspace binds are generated.
ctx.workspace_count = 5

-- ── shell integration ───────────────────────────────────────────────────────
-- Panels are driven with `hl.dsp.global`, which hands the press to the
-- GlobalShortcut Quickshell registered over the wayland global-shortcuts
-- protocol — no process spawn per keypress.
ctx.shell = {
    -- Quickshell config name (~/.config/quickshell/<config>/shell.qml) and the
    -- appid its GlobalShortcuts are registered under.
    config = "neobrix",
    appid  = "neobrix",
}

-- Escape hatch for scripting the shell from a command, e.g. from a Lua callback:
--   hl.exec_cmd(ctx.shell.ipc("panels", "toggle", "launcher"))
function ctx.shell.ipc(...)
    return "qs -c " .. ctx.shell.config .. " ipc call " .. table.concat({ ... }, " ")
end

return ctx
