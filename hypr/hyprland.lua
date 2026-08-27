-- ─────────────────────────────────────────────────────────────────────────────
--  NEOBRIX — Hyprland configuration (native Lua)
--
--  Hyprland 0.56 loads ~/.config/hypr/hyprland.lua in preference to
--  hyprland.conf; internally it calls the hyprlang tree the "legacy config"
--  ("[cfg] Lua config not found, using legacy config at {}"). This project
--  therefore targets Lua as the primary format. See the NeoBrix wiki's
--  Hyprland-Lua page.
--
--  Modules are plain Lua files under config/, composed here. Each returns a
--  function taking the shared context (apps, palette, capabilities) so nothing
--  leaks through globals except Hyprland's own `hl`.
--
--  Validate any change before logging out:
--      Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- ─────────────────────────────────────────────────────────────────────────────

-- Lua's default search path does not include the config directory.
local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"
package.path = table.concat({
    config_dir .. "/?.lua",
    config_dir .. "/?/init.lua",
    package.path,
}, ";")

local ctx = require("lib.context")

require("config.monitors")(ctx)
require("config.environment")(ctx)
require("config.appearance")(ctx)
require("config.animations")(ctx)
require("config.layouts")(ctx)
require("config.input")(ctx)
require("config.workspaces")(ctx)
require("config.rules")(ctx)
require("config.binds")(ctx)
require("config.autostart")(ctx)

-- Machine-specific overrides, applied last so they win. Not tracked in git.
local ok, machine = pcall(require, "machine.local")
if ok and type(machine) == "function" then
    machine(ctx)
end
