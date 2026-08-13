# The Hyprland Lua configuration

This project configures Hyprland in **Lua**, not hyprlang `.conf`.

## Why

Hyprland 0.56 looks for `~/.config/hypr/hyprland.lua` first and only falls back
to `hyprland.conf`. Its own log lines name the two formats:

```
[cfg] Using lua config found at {}
[cfg] Lua config not found, using legacy config at {}
[cfg] Config is lua, loading lua mgr
```

and the `.conf` stub Hyprland writes when it finds no configuration at all says:

```
# This config is a STUB! This should never be generated.
# Use the default lua config from https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua
```

So `.conf` is the legacy path and Lua is where upstream is pointing. Note that
the public wiki still documents `.conf` throughout — the reference used here is
[`example/hyprland.lua`](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua)
from the tag matching the installed version, plus the API introspected from the
running compositor (see *Discovering the API* below).

**Requires Hyprland ≥ 0.55.** `install/deploy.sh` refuses to deploy on anything
older rather than producing a session that silently ignores half its
configuration.

## Module structure

```
hypr/
├── hyprland.lua           entry point: sets package.path, composes the modules
├── lib/
│   ├── context.lua        apps, palette, probed capabilities, shell wiring
│   └── helpers.lua        capability probes, bind generators
├── config/
│   ├── monitors.lua       outputs
│   ├── environment.lua    intentionally empty — see "Environment" below
│   ├── appearance.lua     general / decoration / group / misc / cursor
│   ├── animations.lua     curves and the animation tree
│   ├── layouts.lua        dwindle + master
│   ├── input.lua          keyboard, pointer, touchpad, gestures
│   ├── workspaces.lua     persistent workspaces, scratchpad
│   ├── rules.lua          window and layer rules
│   ├── binds.lua          every keybinding
│   └── autostart.lua      hyprland.start event
└── machine/
    └── local.lua          per-host overrides — untracked, applied last
```

Each `config/*.lua` returns a function taking the shared context:

```lua
return function(ctx)
    hl.config({ general = { border_size = 3 } })
end
```

`hyprland.lua` requires them in order, so nothing leaks into globals except
Hyprland's own `hl` table. Lua's default `package.path` does not include the
config directory, so the entry point prepends it — that is why `require("config.binds")`
resolves at all.

## Machine-specific configuration

`hypr/machine/local.lua` is **not tracked in git** and is applied last, so it
wins over everything. `deploy.sh` seeds it from `machine/local.lua.example` once
and never overwrites it afterwards. Monitor layouts, per-host app choices and
hardware workarounds belong there:

```lua
return function(ctx)
    hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
    ctx.apps.browser = "firefox"
    hl.config({ decoration = { blur = { enabled = true, size = 4, passes = 2 } } })
end
```

## Environment variables

`config/environment.lua` is deliberately empty. Session-wide variables live in
`~/.config/uwsm/env`, because systemd user services — the shell, the portals, the
polkit agent — are **not** children of Hyprland and would never see anything set
with `hl.env()`. Hyprland/Aquamarine-specific variables would go in a sibling
`~/.config/uwsm/env-hyprland`; none are needed on this machine, so that file does
not exist rather than existing empty.

The `uwsm/env` file lists, at the bottom, every variable that was **removed** as
cargo cult and why (UWSM already exports the XDG identity vars; nothing here uses
Clutter or EFL; SDL and Firefox autodetect Wayland now; `NIXOS_OZONE_WL` is
NixOS-only).

## How bindings are generated

Repetitive families come from tables, with the key list at the call site so
nothing is hidden:

```lua
for i = 1, 10 do
    local key = i % 10                        -- 10 lands on the '0' key
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, silent = true }))
end
```

The same pattern covers directions (arrows *and* vim keys from one table),
resize steps, screenshot modes and media keys.

Hardware-dependent bindings are conditional rather than always present:
brightness keys are only bound when `ctx.caps.backlight` is true, and touchpad
settings and gestures only exist when a touchpad does. The probes are in
`lib/helpers.lua` and run once at load.

**Shell panels use `hl.dsp.global`**, which hands the keypress to the
`GlobalShortcut` that Quickshell registered over the wayland global-shortcuts
protocol — no process is spawned per press:

```lua
hl.bind("SUPER + SPACE", hl.dsp.global("neobrix:launcher"))
```

`ctx.shell.ipc(...)` is available for scripting the shell from a Lua callback
(`qs -c neobrix ipc call ...`), but it is not on the keybinding path.

## How rules are managed

Rules take a `match` table and the rule fields as siblings:

```lua
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    pin   = true,
    size  = { "min(monitor_w, monitor_h)*0.28", "min(monitor_w, monitor_h)*0.28" },
})
```

Families that differ only by class are generated from a table, so adding a
floating utility is a one-line change. Layer rules are the same shape with
`match = { namespace = ... }`.

Class and title values were checked against real windows with `hyprctl clients`
and `hyprctl layers` rather than guessed.

## Quickshell interaction

Hyprland evaluates the argument of a dispatch request **as Lua** when a Lua
config is loaded. That means the form every Hyprland example uses fails:

```
$ hyprctl dispatch "workspace 2"
error: [string "return hl.dispatch(workspace 2)"]:1: ')' expected near '2'
```

Quickshell exposes `Hyprland.usingLua` so a config can adapt.
`quickshell/Services/Hypr.qml` wraps every dispatch and emits the right syntax
for either format, and the shell calls that instead of `Hyprland.dispatch`
directly. Under Lua the bar sends, for example:

```lua
hl.dispatch(hl.dsp.focus({ workspace = 2 }))
```

Workspace state, window titles, the tray and everything else the bar reads still
come from Quickshell's native Hyprland IPC binding — only *dispatching* needed
adapting.

## Validating a change

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua      # parses + runs the config
hyprctl configerrors                                          # on the live session
```

`--verify-config` actually executes the Lua, so it catches undefined dispatchers
and Lua runtime errors, not just syntax:

```
/home/asad/.config/hypr/config/binds.lua:100: attempt to call a nil value (field 'move_to_monitor')
stack traceback:
	.../config/binds.lua:100: in function 'config.binds'
```

Always run it before logging out. A config that raises before registering any
bind leaves you with Hyprland's emergency binds only (`SUPER + Q`).

## Discovering the API

The Lua API is not fully documented on the wiki. The reliable way to find what
exists on *your* build is to introspect a running compositor — a nested instance
works and leaves your session alone:

```bash
# start a throwaway instance (needs AQ_NO_KMS_REQUIRED because the guest GPU
# will not hand a second compositor a DRM master)
env -u HYPRLAND_INSTANCE_SIGNATURE AQ_NO_KMS_REQUIRED=1 WAYLAND_DISPLAY=wayland-1 \
    Hyprland -c /path/to/test.lua &

SIG=$(ls -t /run/user/1000/hypr/ | head -1)

# dump a table (hyprctl reports the error text, so `error()` is the print channel)
hyprctl -i "$SIG" eval 'local t={} for k in pairs(hl.dsp) do t[#t+1]=k end
                        table.sort(t) error(table.concat(t, ", "))'

# try a dispatcher for real
hyprctl -i "$SIG" eval 'hl.dispatch(hl.dsp.global("neobrix:launcher"))'
```

This is how `hl.dsp.global` was found: grepping the binary's strings had missed
it, and the wiki does not mention it, but the table plainly contains it. On this
build:

```
hl.dsp            cursor dpms event exec_cmd exec_raw exit focus force_idle
                  force_renderer_reload global group layout no_op pass
                  release_input_capture send_key_state send_shortcut submap
                  window workspace
hl.dsp.window     alter_zorder bring_to_top center clear_tags close cycle_next
                  deny_from_group drag float fullscreen fullscreen_state kill
                  move pin pseudo resize set_prop signal swap tag toggle_swallow
hl.dsp.workspace  change_id move rename swap_monitors toggle_special
hl.on events      hyprland.start hyprland.shutdown config.reloaded
                  window.open window.close window.active window.title ...
                  workspace.active workspace.created workspace.removed
                  monitor.added monitor.removed monitor.focused ...
```

## Debugging a Lua config error

* `Hyprland --verify-config -c ...` prints the Lua stack traceback with file and
  line — use it first.
* On a live session, `hyprctl configerrors` shows what failed at load.
* If a config error prevented any bind from registering, Hyprland logs
  *"Emergency mode tripped"* and binds `SUPER + Q` only, so you can still open a
  terminal and fix it.
* `hyprctl eval '<lua>'` runs arbitrary Lua against the live compositor — the
  fastest way to check whether a call exists and what arguments it wants. Under a
  **`.conf`** session use `hyprctl keyword` instead; `eval` is the Lua-config
  equivalent.
* Errors that mention a nil field (`attempt to call a nil value (field 'x')`)
  mean the dispatcher does not exist on your version — introspect the table
  rather than trusting an example from a different release.

## What is intentionally still `.conf`

Only Hyprland itself moved. These components have no Lua support at all (their
binaries contain no Lua references), so converting them would be inventing a
format that upstream does not read:

| File | Program |
|---|---|
| `hypr/hyprlock.conf` | hyprlock |
| `hypr/hypridle.conf` | hypridle |
| `hypr/xdph.conf` | xdg-desktop-portal-hyprland |

Everything else in the project uses its own native format for the same reason:
`shell.qml`/QML for Quickshell, TOML for Alacritty, `kitty.conf` for kitty, INI
and CSS for GTK, INI for qt5ct/qt6ct and kdeglobals, unit files for systemd.
