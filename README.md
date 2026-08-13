<h1 align="center"><b>N E O B R I X</b></h1>

<p align="center"><i>A neo-brutalist desktop environment for Hyprland, powered by Quickshell.</i></p>

---

<p align="center">
  <img src="docs/identity/shapes-dawn.png" alt="The Neobrix component vocabulary in the dawn palette: card, button, chip, toggle, slider, progress meter, each with a chunky outline and a hard offset shadow">
</p>

<p align="center">
  <img src="docs/identity/shapes-dusk.png" alt="The same component vocabulary in the dusk palette">
</p>

<p align="center">
  <img src="docs/identity/palette.png" alt="The Neobrix palettes: dawn and dusk, fifteen roles each, with hex values">
</p>

---

## What this is

Neobrix combines bold geometry, strong borders, hard shadows and modular
interfaces into a cohesive Wayland desktop environment.

It is not a theme layered on top of somebody else's shell. The bar, launcher,
control center, notification center, calendar, media controls, system tray,
session menu, clipboard panel, level OSD and wallpaper are all implemented here
in QML, on top of Hyprland and Quickshell. The name is *neo* (neo-brutalism)
plus *brix* (bricks, blocks, modular construction — and the chunky geometry the
UI is built from).

The design language is deliberate:

* strong outlines and obvious boundaries
* modular blocks and card layouts
* flat surfaces, minimal transparency, no gratuitous blur
* hard offset shadows rather than soft glows
* bold, hierarchical typography
* restrained palettes with a few deliberate accents
* interactive states you can see from across the room
* chunky controls, sized to be hit rather than aimed at

Two palettes ship: **Neobrix Light** (`dawn`) and **Neobrix Dark** (`dusk`).
Neither is a naive inversion of the other — see [Theming](#theme-architecture).

### Built with AI assistance

Neobrix was implemented by an AI coding agent (Claude Code) working from written
briefs, with the direction, design decisions, review and testing done by the
author. **All documentation in this repository is written by the AI agent** —
this README, everything under `docs/`, the inline comments and the commit
messages.

Worth knowing before you deploy it: the configuration runs daily on the author's
machine and the behaviour described here was verified there, but the code has not
been reviewed by a second person. Read it before pointing it at your own setup —
`install/deploy.sh` in particular symlinks over existing configuration, and while
it backs up everything it replaces to `~/.config-backup/`, you should know that
going in.

### Requirements

CachyOS or Arch, Hyprland ≥ 0.55 (for the Lua configuration format), Quickshell,
and a Nerd Font. Everything is in the standard repositories; no AUR helper is
needed. See [Dependencies](#dependencies).

## Screenshots

In [`docs/screenshots/`](docs/screenshots). Regenerate with
`neobrix-screenshot screen` (writes to `~/Pictures/Screenshots`).

| | |
|---|---|
| ![desktop](docs/screenshots/desktop.png) | ![launcher](docs/screenshots/launcher.png) |
| **Desktop** — bar and generated wallpaper | **Launcher** — fuzzy search over `.desktop` entries |
| ![control center](docs/screenshots/control-center.png) | ![calendar](docs/screenshots/calendar.png) |
| **Control center** — audio, media, specs, resources, connectivity | **Calendar** — clock, date, month navigation |
| ![dusk](docs/screenshots/dusk.png) | ![lock](docs/screenshots/lock.png) |
| **Neobrix Dark** — the same panel in the `dusk` palette | **Lock screen** — hyprlock, themed from the same palette |

## Architecture

```
greetd
  └── uwsm  ──────────────────────────────► systemd --user
        └── Hyprland (hyprland.lua, Lua config)   │
              │  layer surfaces                   ├── neobrix-shell.service   (qs -c neobrix)
              │                                   ├── hypridle.service
              └── Quickshell ──────────────┐      ├── hyprpolkitagent.service
                    ├── Wallpaper          │      └── cliphist.service
                    ├── Bar (per monitor)  │
                    ├── Launcher           │   all WantedBy=graphical-session.target,
                    ├── Control center     │   grouped by neobrix-session.target
                    ├── Calendar           │
                    ├── Session menu       │
                    ├── Clipboard          │
                    ├── Notifications      │
                    └── Level OSD          │
                                           │
        native integrations ───────────────┘
        Hyprland IPC · PipeWire · MPRIS · NetworkManager · BlueZ ·
        StatusNotifier/DBusMenu · UPower · org.freedesktop.Notifications
```

Nothing polls a CLI tool in a loop. `hyprctl`, `pactl`, `nmcli` and `playerctl`
are never used for state; `/proc` is read via watched file views on a slow tick
and only while a panel is open.

### Quickshell layout

```
quickshell/
├── shell.qml            entry point; warms the service singletons
├── Theme/Theme.qml      the entire design system (palettes, metrics, motion)
├── Components/          BrixCard · BrixButton · BrixIconButton · BrixChip
│                        BrixSlider · BrixVSlider · BrixToggle · BrixProgress
│                        BrixPopup · BrixTooltip · SectionHeader
├── Services/            Hw · SysInfo · Audio · Net · Bt · Backlight · Media
│                        Notifs · Apps · Clip · Session · Wall · Panels
├── Bar/                 Bar · Workspaces · ActiveWindow · Tray · TrayMenu
│                        Indicators · MediaPill · ClockPill · NotifButton
├── Launcher/            Launcher · AppEntry
├── Panels/              ControlCenter · SystemTab · AudioCard · SpecsCard
│                        ResourcesCard · ConnectivityCard · MediaCard
│                        NotificationCenter · CalendarPanel · SessionPanel
│                        ClipboardPanel
├── Notifications/       NotificationLayer · NotificationItem · Osd
└── Wallpaper/           Wallpaper
```

### Hyprland configuration

Hyprland is configured in **Lua** (`~/.config/hypr/hyprland.lua`), not hyprlang
`.conf`. Hyprland 0.56 loads the Lua file in preference and calls the `.conf`
tree the *"legacy config"*; the stub it generates when it finds nothing points
users at the upstream Lua example. **Hyprland ≥ 0.55 is required** — the
installer refuses to deploy on older versions.

```
hypr/
├── hyprland.lua        composes the modules
├── lib/                context (apps, palette, probed capabilities) + helpers
├── config/             monitors · appearance · animations · layouts · input
│                       workspaces · rules · binds · autostart · environment
└── machine/local.lua   per-host overrides, untracked, applied last
```

Workspace/direction/media bindings are generated from tables, touchpad and
brightness settings only exist when that hardware does, and panel shortcuts use
`hl.dsp.global` so no process is spawned per keypress. Validate any edit with
`Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` before logging out.

Full details, the discovered Lua API, and how to debug a Lua config error:
**[docs/HYPRLAND-LUA.md](docs/HYPRLAND-LUA.md)**.

### Theme architecture

`Theme.qml` is the only place a colour or a pixel value is defined. Two palettes —
**Neobrix Light** (`dawn`) and **Neobrix Dark** (`dusk`) — expose an identical
set of roles, and every component reads flat aliases (`Theme.surface`,
`Theme.primary`, `Theme.radiusMd`, `Theme.shadowSm`, `Theme.durFast`…). Switching
mode re-colours the whole shell live; the choice is persisted under
`$XDG_STATE_HOME/quickshell/…/theme-mode`.

`Theme.textOn(accent)` returns a readable glyph colour for an arbitrary accent, so
badges stay legible when the neutral accents invert between palettes.

The mode is not shell-only: changing it runs **`neobrix-theme`**, which renders the
same palette into the terminals, GTK 3/4, qt5ct/qt6ct and kdeglobals. Alacritty
imports the generated file and watches it, so open terminals recolour live; kitty
reloads on SIGUSR1; GTK follows the gsettings `color-scheme`; Qt/KDE applications
read their palette at startup and so follow on next launch. Those files are
generated into `~/.config` rather than symlinked from this repo, because KDE apps
write to `kdeglobals` themselves.

Dark mode is a designed palette, not an inversion. `dusk` keeps the warm cast of
the light theme (surfaces run brown-black rather than neutral grey), flips the
outline to cream so the chunky borders stay the strongest line on screen, and
desaturates the accents just enough to sit on a dark ground without glowing.
`Theme.textOn()` exists precisely because the neutral accents swap luminance
between the two palettes, so a fixed "text on accent" colour would vanish in one
of them.

The neo-brutalist signature lives in **`BrixCard`**: a flat fill, a chunky outline,
and a hard offset shadow drawn as a negative-z child (Qt Quick paints those behind
the parent). Every surface in the shell — bar islands, panels, chips, buttons,
sliders, notification cards — is a `BrixCard`, which is why they all share the
same physics: press a button and it travels into its own shadow.

## Dependencies

Everything is in the CachyOS/Arch repositories — no AUR helper required.

```bash
./install/packages.sh --list     # see the full list
./install/packages.sh            # install what's missing
```

Core: `hyprland` `quickshell` `hyprlock` `hypridle` `hyprpolkitagent` `hyprpicker`
`uwsm`.
Services: `pipewire` `pipewire-pulse` `wireplumber` `networkmanager` `bluez`
`xdg-desktop-portal{,-hyprland,-gtk}` `polkit` `power-profiles-daemon`.
Utilities: `wl-clipboard` `cliphist` `grim` `slurp` `satty` `brightnessctl`
`libnotify` `imagemagick` `librsvg` `python`.
Look: `ttf-jetbrains-mono-nerd` `papirus-icon-theme` `adw-gtk-theme` `qt5ct`
`qt6ct` `adwaita-cursors`.
Apps: `alacritty` `dolphin` `zen-browser-bin`.

## Installation

```bash
git clone <this repo> ~/Projects/neobrix
cd ~/Projects/neobrix
./install/packages.sh
./install/deploy.sh --dry-run     # inspect first
./install/deploy.sh
```

`deploy.sh` symlinks the repo into `~/.config`, so editing the repo edits the live
configuration — there is never a divergent second copy. Anything it replaces is
copied to `~/.config-backup/deploy-<timestamp>/` first. It also links
`scripts/*` into `~/.local/bin`, installs and enables the systemd user units,
generates the wallpapers, and points the XDG browser handlers at Zen.

Then log out and back in. To apply most of it without logging out:

```bash
hyprctl reload
systemctl --user restart neobrix-session.target
```

## Updating

```bash
cd ~/Projects/neobrix && git pull
./install/deploy.sh                       # re-link anything new
systemctl --user restart neobrix-shell    # pick up QML changes
hyprctl reload                            # pick up hyprland.conf changes
```

Always validate compositor edits before logging out — a bad config means a
session that will not start:

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

`--verify-config` executes the Lua, so it catches undefined dispatchers and
runtime errors, not just syntax. If a config error stops any bind from
registering, Hyprland falls back to emergency binds (`SUPER + Q` only).

## Keybindings

Full list: [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md). The essentials:

| Keys | Action |
|---|---|
| `Super` + `Space` / `Super`+`D` | application launcher |
| `Super` + `X` | control center |
| `Super` + `A` | notification centre |
| `Super` + `C` | calendar |
| `Super` + `V` | clipboard history |
| `Super` + `Escape` | session menu (reboot/shutdown need a second click) |
| `Super` + `Return` | terminal |
| `Super` + `E` / `W` | file manager / browser |
| `Super` + `Q` / `F` | close / fullscreen |
| `Super` + `1…0` | workspace (`+Shift` moves the window) |
| `Super` + `S` | scratchpad |
| `Print` / `Shift`+`Print` / `Super`+`Print` | screenshot region / screen / window |
| `Super` + `Shift` + `T` | toggle light/dark |
| `Super` + `Backspace` | lock |

## Scripts

| Command | Purpose |
|---|---|
| `neobrix-screenshot region\|screen\|window\|edit` | capture → file + clipboard + notification |
| `neobrix-wallpaper apply\|next\|prev\|theme\|list\|generate` | wallpaper selection |
| `neobrix-generate-wallpapers [dir] [WxH]` | regenerate the built-in set |
| `neobrix-theme dawn\|dusk\|current` | apply the palette to terminals, GTK, Qt and KDE |

The shell is also scriptable:

```bash
qs -c neobrix ipc call panels toggle launcher
qs -c neobrix ipc call panels control notifications
qs -c neobrix ipc call theme set dusk
qs -c neobrix ipc call wallpaper next
```

## VM notes

Developed and validated on a Proxmox/KVM guest with virtio-gpu, which shaped a few
decisions:

* **No battery, backlight, Bluetooth adapter, Wi-Fi or temperature sensors.** Every
  such widget is gated on a probe in `Services/Hw.qml` and simply does not exist
  when the hardware does not. Nothing renders as a dead control.
* **No emulated sound card.** PipeWire exposes only a "Dummy Output"; the volume
  UI drives it correctly, and the microphone row is absent because there is no
  capture device.
* **Software rendering.** Mesa falls back to `kms_swrast`/llvmpipe, so the shell's
  ~360 MB PSS is mostly the software rasteriser (≈290 MB of it is anonymous
  llvmpipe/LLVM memory). Idle CPU is 0 %. Blur is disabled and animations are kept
  short for this reason.
* **No wallpaper daemon.** hyprpaper never registers a wallpaper target here, so
  the shell draws the wallpaper itself.
* **hyprlock cannot screenshot itself.** Screencopy needs a DRM dumb buffer the
  guest denies, so the lock background is a maintained copy of the wallpaper.

## Physical-machine notes

The dotfiles are written to run unchanged on real hardware:

* Battery, backlight, Bluetooth and Wi-Fi sections appear automatically once the
  devices exist — there is no VM-specific branch to remove.
* Put monitor layouts and per-host tweaks in `~/.config/hypr/machine/local.lua`
  (untracked, seeded by the installer). Example:
  ```lua
  return function(ctx)
      hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
      hl.config({ decoration = { blur = { enabled = true, size = 4, passes = 2 } } })
  end
  ```
* Touchpad settings, gestures and brightness keys appear automatically once that
  hardware exists — the config probes for it rather than assuming.
* `hypridle` never suspends by default; add a suspend listener locally if you want
  one.

## Troubleshooting

| Symptom | Check |
|---|---|
| No bar | `systemctl --user status neobrix-shell` · `journalctl --user -u neobrix-shell -n 50` |
| Bar but no panels | `qs -c neobrix ipc call panels state` — if that errors the shell isn't running |
| Keybinds do nothing | `hyprctl globalshortcuts` should list `neobrix:*`; if empty the shell isn't up |
| Session won't start after an edit | `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` |
| Only `SUPER+Q` works | a Lua error stopped binds registering — Hyprland's emergency mode; check `hyprctl configerrors` |
| `hyprctl dispatch "workspace 2"` errors | under a Lua config the argument is Lua: `hyprctl dispatch 'hl.dispatch(hl.dsp.focus({workspace=2}))'` |
| Stuck on "lockscreen app died" | `hyprctl eval 'hl.clear_crashed_lockscreen()'` (Lua config) or `hyprctl dispatch clearcrashedlockscreen` |
| Notifications not appearing | only one daemon may own the bus: `busctl --user list \| grep Notifications` |
| No wallpaper | `neobrix-wallpaper current` · `neobrix-wallpaper generate` |
| Qt apps unstyled | `QT_QPA_PLATFORMTHEME=qt6ct` in `~/.config/uwsm/env`, and `qt6ct` config linked |

## Restoring the previous configuration

Two independent safety nets:

```bash
# 1. everything deploy.sh replaced, newest backup first
./install/deploy.sh --restore

# 2. the working hyprlang config from just before the Lua migration
ls ~/.config-backup/pre-lua-migration/

# 3. the untouched pre-Neobrix CachyOS configuration
ls ~/.config-backup/pre-neobrix/
cp -a ~/.config-backup/pre-neobrix/hypr/hyprland.lua ~/.config/hypr/
cp -a ~/.config-backup/pre-neobrix/hypr/config      ~/.config/hypr/
systemctl --user disable --now neobrix-shell.service
```

`~/.config-backup/pre-neobrix/` also contains the original package list and
environment for reference. Neither backup is ever deleted by the installer.

## Project structure

```
neobrix/
├── hypr/                  Hyprland configuration (Lua)
│   ├── hyprland.lua       entry point
│   ├── config/            monitors, input, appearance, animations, layouts,
│   │                      workspaces, rules, binds, autostart, environment
│   ├── lib/               context + helpers shared by the config modules
│   ├── machine/           per-host overrides (untracked; seeded from .example)
│   ├── hyprlock.conf      hyprlock still uses hyprlang — see below
│   ├── hypridle.conf
│   └── xdph.conf
├── quickshell/            the shell itself
│   ├── shell.qml          entry point
│   ├── Theme/             the design system — single source of every value
│   ├── Components/        Brix* primitives
│   ├── Bar/               bar and its islands
│   ├── Launcher/
│   ├── Panels/            control center, calendar, session, clipboard
│   ├── Notifications/     toasts, history, level OSD
│   ├── Services/          singletons wrapping the native integrations
│   └── Wallpaper/
├── terminal/              alacritty, kitty
├── scripts/               neobrix-theme, -wallpaper, -screenshot, -generate-wallpapers
├── systemd/               user units
├── uwsm/env               session environment
├── install/               deploy.sh, packages.sh
└── docs/
```

QML directories are capitalised because that is how QML resolves module
imports (`import qs.Components`); the rest is lowercase. Only `hyprland.lua`
uses the Lua format — hyprlock, hypridle and xdg-desktop-portal-hyprland still
expect hyprlang `.conf`, and are left in their own supported formats rather
than converted for the sake of uniformity.

## Built on

* **[Quickshell](https://quickshell.org)** — the toolkit the entire shell is
  built on, and the reason none of this needs Waybar, Rofi, Mako or swaync.
* **[Hyprland](https://hypr.land)** — the compositor, and the Lua configuration
  format this project targets.

Neo-brutalism as an interface style is a broad movement rather than any one
project's invention; the palette, geometry and components here are original to
Neobrix. [docs/DEVIATIONS.md](docs/DEVIATIONS.md) records the design decisions
and why each was made.

## Licence

MIT — see [LICENSE](LICENSE).

The wallpapers are original artwork generated by
`scripts/neobrix-generate-wallpapers` from the theme palette, so the repository
carries no third-party image licensing. No code or assets from any other project
are redistributed here.
