# Design decisions

Why Neobrix does a few things differently from the CachyOS defaults, and from
the obvious first choice. Each entry records what was actually observed on the
machine, not a preference.

## Interface

**No pinned-app dock in the bar.** A static dock duplicates the launcher, which
is one keystroke away. The left island carries the launcher button and the
focused window instead; the power controls live in the session menu, reachable
by right-clicking the launcher button.

**Workspaces occupy the centre island.** The media island appears beside it, in
the same floating-island idiom, and only while a player actually exists — so the
bar's geometry does not depend on whether music is playing.

**No desktop widgets.** A to-do list, a pomodoro timer and a weather readout are
applications, not desktop plumbing; weather in particular needs a third-party API
key. That space goes to the control center, which is one keystroke away and does
not occupy the desktop permanently.

**No window title bars.** Title bars with close buttons come from the `hyprbars`
plugin, which must be compiled against the exact Hyprland ABI with `hyprpm`. On a
rolling distribution that breaks on every Hyprland update and takes the session
down with it. `decoration:shadow:sharp` plus a 3 px border gives the same visual
weight with zero ABI risk.

**Horizontal sliders in the Audio card, vertical only in the OSD.** At 1280x800 a
74 px-tall vertical column left the slider about 30 px of travel, which read as a
cramped artefact rather than a control. `BrixVSlider` still drives the
volume/mic/brightness OSD, where a tall column has room.

**No audio visualiser.** One needs a live capture loop (cava, or a PipeWire peak
monitor) running the whole time media plays — a permanent CPU cost for
decoration. The media card uses a seek bar instead.

## Relative to the CachyOS defaults

**Lua, not hyprlang.** The Hyprland configuration is native Lua
(`hypr/hyprland.lua` + modules). Hyprland 0.56 checks for the Lua file first and
logs the `.conf` tree as the *"legacy config"*; the stub it autogenerates when no
config exists says *"This config is a STUB! This should never be generated. Use
the default lua config from …example/hyprland.lua"*. Note the public wiki still
documents `.conf` only and does not call it deprecated — the evidence above comes
from the binary and from upstream's own example file.

An earlier iteration of this project deliberately used `.conf`, for two reasons
that turned out to be wrong on closer inspection:

* *"Lua has no `global` dispatcher, so shell panels would need a process spawn
  per keypress."* It does. `strings` on the binary only surfaces names that appear
  in error messages, which missed most of the dispatcher table. Introspecting the
  live table (`hyprctl -i <sig> eval "for k in pairs(hl.dsp) …"`) shows `global`
  plainly, and `hl.dispatch(hl.dsp.global("neobrix:launcher"))` returns `ok`. The
  binds keep the zero-spawn path.
* *"`hyprctl dispatch \"workspace 2\"` fails under Lua, which breaks Quickshell's
  Hyprland integration."* True — the argument is evaluated as Lua — but the fix is
  to emit the right syntax, not to avoid Lua. Quickshell exposes
  `Hyprland.usingLua` for exactly this; `quickshell/Services/Hypr.qml` wraps every
  dispatch and works under either format.

`hyprctl keyword` is unavailable while a Lua config is loaded ("keyword can't work
with non-legacy parsers") — `hyprctl eval '<lua>'` is the equivalent, and is what
this migration used to verify every dispatcher and rule form against a live
Lua-configured compositor before writing it down.

A copy of the previous hyprlang configuration is kept on the machine under
`~/.config-backup/`, so a rollback does not depend on this repository.

**Rule syntax.** In Lua a rule is a single table, which is both clearer than the
hyprlang block form and lets rule families be generated:

```lua
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^([Pp]icture…)(.*)$" },
    float = true,
    pin   = true,
})
```

(For reference, the hyprlang form this replaced needed a named block whose `match`
sub-block had to span lines — `match { class = x }` on one line parsed as an
option literally named `"match { class"`.)
Valid matchers: `class` `title` `initial_class` `initial_title` `xdg_tag` `content`
`workspace` `float` `fullscreen` `xwayland` `focus` `tag` `monitor` `group`.
Rules include `float` `center` `size` `move` `opacity` `pin` `keep_aspect_ratio`
`persistent_size` `fullscreen_state` `decorate` `rounding` `no_focus`
`suppress_event` `immediate` `tag` `min_size` `max_size` `group` `idle_inhibit`
`no_screen_share` `opaque` `dim_around` `animation` `stay_focused` `no_anim`
`no_blur` `no_shadow` `no_dim`.

Also renamed/removed in 0.56: `togglesplit` and `pseudo` are `layoutmsg`
arguments, not dispatchers; `misc:vfr`, `misc:new_window_takes_over_fullscreen` and
`decoration:shadow:ignore_window` no longer exist.

**Noctalia removed.** CachyOS ships Noctalia (a self-contained shell binary) as the
desktop. It owns `org.freedesktop.Notifications` and draws its own bar, so it cannot
coexist with this shell. `noctalia` and the `cachyos-hypr-noctalia` meta-package are
uninstalled.

Two cautions if you repeat this on another CachyOS install:

* `pacman -Rs` on that meta-package also sweeps **uwsm, xdg-desktop-portal-hyprland,
  grim, slurp, satty, qt6ct, brightnessctl, adw-gtk-theme, hyprpicker,
  gnome-calculator, gnome-text-editor** and more — they are only orphans because the
  meta-package was the thing that pulled them in. Mark everything you actually use as
  explicit first (`pacman -D --asexplicit $(install/packages.sh --list)`), then check
  `pacman -Rs --print` before committing to it.
* **`noctalia-greeter` is a different package and is kept.** `/etc/greetd/config.toml`
  runs `/usr/bin/noctalia-greeter-session`, so removing it leaves greetd pointing at a
  missing binary and no way to log in. Swap the greeter in `/etc/greetd/config.toml`
  first if you want it gone.

**Alacritty config rewritten.** The shipped `alacritty.toml` defined `bindings`
under `[keyboard]` *and* a `[[keyboard.bindings]]` table array. That is a duplicate
key, so alacritty rejected the whole file and every new terminal opened with a red
config-error banner. It also imported a Noctalia-generated theme.

**Leftover Noctalia GTK CSS.** `~/.config/gtk-{3,4}.0/gtk.css` contained
`@import url("noctalia.css")`, a generated dark palette. libadwaita ignores
`gtk-theme-name` and derives everything from named colours, so *every* GTK4 app
stayed dark regardless of `settings.ini` or `color-scheme` — the portal correctly
reported prefer-light the whole time. Replaced with Neobrix named colours; the
Noctalia files are in `~/.config-backup/pre-neobrix/gtk-leftovers/`.

**KDE apps need kdeglobals — and they write to it.** Dolphin and friends read
`kdeglobals` in preference to the qt6ct palette. Shipping it as a symlink into
this repo was a mistake: KDE applications *write* their own keys back, so Dolphin
put `ColorScheme=Noctalia` and a set of dark `[Colors:Header]`/`[WM]` values
straight into the tracked file, a `git add -A` swept it into a commit, and every
KDE app went dark again. `kdeglobals` is now **generated** by `neobrix-theme`
into `~/.config` and is not tracked. The same applies to the GTK and qt5ct/qt6ct
colour files, which must change with the light/dark mode anyway.

**Application theming follows the shell's mode.** `scripts/neobrix-theme` renders
the active palette into the terminals, GTK 3/4, qt5ct/qt6ct and kdeglobals, and
`Theme.qml` runs it whenever the mode changes. Alacritty imports the generated
file and watches it, so open terminals recolour live; kitty is reloaded with
SIGUSR1; GTK apps follow the gsettings `color-scheme`; Qt/KDE apps read their
palette at startup, so those pick it up when next launched.

**Cursor theme.** `XCURSOR_THEME=Bibata-Modern-Ice` was set but Bibata was not
installed and is not in any configured repository, so the cursor silently fell back.
Switched to `Adwaita`, which is installed.

**`BROWSER=firefox`** was in the login environment on an image that deliberately
excludes Firefox. Set to `zen-browser` in `uwsm/env`, and the XDG handlers point at
`zen.desktop`.

## Wallpaper: no daemon

`hyprpaper` 0.8.4 on this machine logs `Monitor Virtual-1 has no target: no wp will
be created` for every configuration form tried (inline `preload`+`wallpaper`, a
sourced fragment, explicit monitor name, `,`-prefixed all-monitors form), with or
without software-EGL overrides. Its IPC is also partly incompatible with this
`hyprctl` build — `preload`, `unload` and `listactive` return *"invalid hyprpaper
request"* / *"wire handshake failed"*, and sending `wallpaper` without a successful
preload crashed the daemon.

The shell draws the wallpaper instead (`Wallpaper/Wallpaper.qml`): a background
layer per monitor, two `Image` layers crossfading, reading a watched state file. That
removes a daemon, an IPC protocol and a failure mode, and the transition comes free.
`neobrix-wallpaper` only has to write a path.

## hyprlock

Three bugs found by looking at the screen rather than at the config:

1. `path = screenshot` requires a screencopy DRM buffer. The guest GPU returns
   `DRM_IOCTL_MODE_CREATE_DUMB failed: Permission denied`, hyprlock exits, and the
   session is left on Hyprland's *"lockscreen app died"* screen. The background is
   now a normalised PNG copy of the current wallpaper, refreshed by
   `neobrix-wallpaper`, so the path in the config stays machine-independent.
2. `fade_on_empty` defaults to **true**, which fades the password field out
   entirely while the buffer is empty — the box was invisible until you typed.
3. `numlock_color = -1` with numlock enabled by default made hyprlock draw the
   field outline in an unset colour, i.e. no border at all. Those overrides are
   removed.

Also: `input-field` colour options do not resolve the `$variables` declared at the
top of the file (`shape` and `label` do), so that block uses literal colours; and
`shape` widgets paint over `input-field` regardless of `zindex`, so the field gets
its own outline rather than a shadow slab behind it.

## Other choices

* **Blur off, opacity 1.0.** Neo-brutalism is flat and high-contrast; blur would
  also be the single most expensive effect on a software rasteriser.
* **Reference-counted sampling.** `SysInfo` reads `/proc` only while a panel is
  open, `Media` ticks MPRIS position only while a seek bar is visible, and Wi-Fi
  scanning runs only while a network list is on screen.
* **`playerctl` not installed.** Media keys are bound to the shell's own MPRIS
  `GlobalShortcut`s, so there is no extra package and no process spawn per press.
* **Shipped systemd units reused.** `hypridle`, `hyprpolkitagent` and `cliphist`
  all ship correct `WantedBy=graphical-session.target` units; duplicating them in
  this repo would only create two sources of truth. Only `neobrix-shell.service`
  and `neobrix-session.target` are ours.
* **Never assign to a bound property.** `BrixPopup` used to expose a writable
  `open` that each panel bound to `Panels.isOpen(name)`, and `close()` assigned
  `open = false`. In QML that assignment replaces the binding, so after the first
  Escape or click-outside the window no longer followed the singleton and could
  never reopen — while the X button, which mutated the singleton instead, kept
  working. Panels now set `panel: "<name>"`, `open` is `readonly`, and every
  close path goes through `Panels`.
* **Panel windows are mapped imperatively, not by a derived binding.** Binding a
  layer surface's `visible` to `open || closeTimer.running` looks equivalent but
  glitches: QML re-evaluates it before the change handler starts the timer, so the
  surface unmaps and remaps on every close. Repeat that enough times and the
  surface stops mapping altogether until the shell restarts. Anything that keeps a
  window alive for an exit animation should set the flag explicitly.
* **Applications launch into their own systemd scope.** `DesktopEntry.execute()`
  forks from the shell, so anything started from the launcher lived inside
  `neobrix-shell.service`'s cgroup and would be killed by a shell restart. Under uwsm
  the launcher now hands the desktop id to `uwsm app --`, matching what the Hyprland
  exec binds do; apps land in `app-Hyprland-<id>-<hash>.scope`.
* **Reboot/shutdown need two clicks.** The session menu arms a destructive action
  on the first click and executes on the second, because it is one keystroke away
  from the launcher.
