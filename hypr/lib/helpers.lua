-- Small helpers shared by the config modules.
--
-- Everything here runs once, at config load. Keep it cheap: Hyprland blocks on
-- the config while this executes.

local M = {}

-- Read the first line of a file, or nil.
local function read_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("l")
    f:close()
    return line
end
M.read_line = read_line

-- True when a directory exists and contains at least one entry.
local function dir_has_entries(path)
    -- `ls -A` is cheaper than pulling in a filesystem library, and this runs a
    -- handful of times at startup only.
    local p = io.popen("ls -A '" .. path .. "' 2>/dev/null | head -n1")
    if not p then return false end
    local first = p:read("l")
    p:close()
    return first ~= nil and first ~= ""
end
M.dir_has_entries = dir_has_entries

-- True when `name` is on PATH.
function M.has_exec(name)
    local p = io.popen("command -v '" .. name .. "' 2>/dev/null")
    if not p then return false end
    local found = p:read("l")
    p:close()
    return found ~= nil and found ~= ""
end

-- ── capability probes ───────────────────────────────────────────────────────

function M.has_battery()
    -- A desktop or VM has an empty /sys/class/power_supply, or only an AC
    -- adapter; a real battery shows up as BAT*.
    local p = io.popen("ls /sys/class/power_supply 2>/dev/null")
    if not p then return false end
    local out = p:read("a") or ""
    p:close()
    return out:match("BAT") ~= nil
end

function M.has_backlight()
    return dir_has_entries("/sys/class/backlight")
end

function M.has_touchpad()
    local p = io.popen("grep -lis touchpad /sys/class/input/*/device/name 2>/dev/null | head -n1")
    if not p then return false end
    local found = p:read("l")
    p:close()
    return found ~= nil and found ~= ""
end

function M.is_virtual_machine()
    local p = io.popen("systemd-detect-virt 2>/dev/null")
    if not p then return false end
    local virt = (p:read("l") or "none"):gsub("%s+", "")
    p:close()
    return virt ~= "none" and virt ~= ""
end

-- ── binding helpers ─────────────────────────────────────────────────────────

-- Bind the same dispatcher to several key combinations.
-- Used for aliases such as Super+Space / Super+D both opening the launcher.
function M.bind_all(keys, dispatcher, opts)
    for _, key in ipairs(keys) do
        hl.bind(key, dispatcher, opts)
    end
end

-- Bind a set of {key, value} pairs through a dispatcher factory:
--
--   pairs_bind("SUPER", DIRECTIONS, function(dir)
--       return hl.dsp.focus({ direction = dir })
--   end)
--
-- The caller supplies the key list explicitly, so which keys exist stays
-- visible at the call site rather than hidden in here.
function M.pairs_bind(prefix, list, make, opts)
    for _, entry in ipairs(list) do
        hl.bind(prefix .. " + " .. entry[1], make(entry[2]), opts)
    end
end

return M
