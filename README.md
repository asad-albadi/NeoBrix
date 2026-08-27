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

## Install

On CachyOS or Arch:

```bash
curl -fsSL https://raw.githubusercontent.com/asad-albadi/NeoBrix/main/install/bootstrap.sh | bash
```

### Features

- Complete Quickshell desktop: bar, launcher, workspace previews, calendar,
  clipboard, session controls, notifications, media and level OSDs
- Unified control center for system resources, connectivity, displays and local
  Codex, Claude Code and Cursor account usage
- Two live palettes — `dawn` and `dusk` — with generated wallpapers and themes
- Hyprland workflow with scratchpad, window/workspace controls, lock, idle and
  suspend integration
- Styled `pacman` output and a NeoBrix package-update flow

**Themed applications:** Quickshell, Hyprland, hyprlock, ReGreet, GTK 3/4,
Qt 5/6, KDE apps, Kitty, Fish, Fastfetch, btop, Zen Browser, Dark Reader,
Cursor, VS Code and Zed.

Or read it first, which is the better habit with any `curl | bash`:

```bash
curl -fsSL https://raw.githubusercontent.com/asad-albadi/NeoBrix/main/install/bootstrap.sh -o neobrix-install.sh
less neobrix-install.sh
bash neobrix-install.sh
```

Both forms run the same file, and `bash` is required either way — the script is
bash, not POSIX `sh`.

That script is deliberately thin: it refuses to run as root, refuses a machine
without `pacman`, clones this repository to `~/Projects/neobrix`, and then hands
off to [`install/packages.sh`](install/packages.sh) and
[`install/deploy.sh`](install/deploy.sh), which do the real work and are worth
reading too. It installs the packages, links the configuration into `~/.config`,
installs and enables the systemd user units, generates the wallpapers and the
palette-derived themes, and themes Zen Browser if a profile exists.

| Flag | Effect |
|---|---|
| `--yes` | Non-interactive. Safe defaults, and **removes nothing**. |
| `--no-packages` | Skip `pacman`; only link configuration. |
| `--greeter` | Also stage the login screen. Asked about otherwise; never silent. |
| `--dir <path>` | Where to clone. Default `~/Projects/neobrix`, or `$NEOBRIX_DIR`. |
| `--uninstall` | Undo: restore backups, disable the units, report what it left. |
| `--help` | The list above. |

With the piped form, flags have to be handed past `bash` itself, or `bash` takes
them as its own:

```bash
curl -fsSL .../install/bootstrap.sh | bash -s -- --greeter --dir ~/src/neobrix
```

**Two things it will not do behind your back.**

*Another desktop already installed* — it looks for Noctalia, Caelestia,
end-4/dots-hyprland, ML4W, other Quickshell configs, and units that would fight
this shell (a second bar, a second notification daemon). It **lists** what it
finds and then asks about **each item separately**; the default answer is always
keep, a run with `--yes` or with no terminal removes nothing at all, and anything
it does move is copied to `~/.config-backup/` first. Units are disabled rather
than uninstalled, because that is reversible; package removal is a separate
question asked last.

*The login screen* — untouched unless you ask, and asked in two steps. It comes
last, after the desktop is in place. First `deploy.sh --greeter` **stages** it:
`/etc/greetd/RECOVERY`, an `agreety` fallback and the config are written
*beside* the live one, which is not replaced. Then, separately, you are asked
whether to **activate** it.

Activation is the strictest prompt in the project, because a greeter that will
not start means a machine you cannot log into:

* it only happens when a human answers at a terminal — **never** from a pipe,
  never under `--yes`, and there is no flag to bypass it;
* the default is no;
* it refuses outright unless the rollback already exists: `greetd`, `regreet` and
  `cage` installed, `RECOVERY` written, the `agreety` fallback staged, the
  replaced display manager recorded, and **a getty reachable on another VT** —
  if there is no Ctrl+Alt+F2 escape on your machine it will not activate at all;
* it takes effect at the **next boot**. Nothing is restarted, because restarting
  greetd would end the session you are sitting in.

Answer no and it tells you the one-liner for later. See
[Login screen](#login-screen).

To undo everything:

```bash
~/Projects/neobrix/install/bootstrap.sh --uninstall
```

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
and a Nerd Font.

Every package the desktop itself needs is in Arch's own `core`/`extra` — checked
against archlinux.org's package API, not assumed. Two **applications** are not:
`zen-browser-bin` and `cursor-bin` are in the `cachyos` repo, and on plain Arch
they are AUR packages. `install/packages.sh` treats those two as optional and
skips them with a note rather than failing, so a plain Arch install needs no AUR
helper to get a working desktop — you just supply your own browser and editor, or
install those two from the AUR yourself. See [Dependencies](#dependencies).

## Screenshots

Every view below is shown in both palettes. Network and account identifiers in
the public captures are intentionally obscured.

| Dawn | Dusk |
|:---:|:---:|
| ![ReGreet login screen in dawn](docs/screenshots/greeter-dawn.png) | ![ReGreet login screen in dusk](docs/screenshots/greeter-dusk.png) |
| **Login screen** | **Login screen** |
| ![hyprlock screen in dawn](docs/screenshots/lock-dawn.png) | ![hyprlock screen in dusk](docs/screenshots/lock-dusk.png) |
| **Lock screen** | **Lock screen** |
| ![NeoBrix dawn desktop](docs/screenshots/shell-desktop-dawn.png) | ![NeoBrix dusk desktop](docs/screenshots/shell-desktop-dusk.png) |
| **Desktop** | **Desktop** |
| ![Launcher in dawn](docs/screenshots/shell-launcher-dawn.png) | ![Launcher in dusk](docs/screenshots/shell-launcher-dusk.png) |
| **Launcher** | **Launcher** |
| ![Workspace preview in dawn](docs/screenshots/shell-workspaces-dawn.png) | ![Workspace preview in dusk](docs/screenshots/shell-workspaces-dusk.png) |
| **Workspace window previews** | **Workspace window previews** |
| ![System control center in dawn](docs/screenshots/control-system-dawn.png) | ![System control center in dusk](docs/screenshots/control-system-dusk.png) |
| **System and media** | **System and media** |
| ![Connectivity in dawn](docs/screenshots/control-connectivity-dawn.png) | ![Connectivity in dusk](docs/screenshots/control-connectivity-dusk.png) |
| **Wi-Fi, Ethernet and Bluetooth** | **Wi-Fi, Ethernet and Bluetooth** |
| ![Display controls in dawn](docs/screenshots/control-displays-dawn.png) | ![Display controls in dusk](docs/screenshots/control-displays-dusk.png) |
| **Displays** | **Displays** |
| ![AI account usage in dawn](docs/screenshots/control-ai-dawn.png) | ![AI account usage in dusk](docs/screenshots/control-ai-dusk.png) |
| **AI usage and subscriptions** | **AI usage and subscriptions** |
| ![Notification center in dawn](docs/screenshots/control-notifications-dawn.png) | ![Notification center in dusk](docs/screenshots/control-notifications-dusk.png) |
| **Notifications** | **Notifications** |
| ![Calendar in dawn](docs/screenshots/shell-calendar-dawn.png) | ![Calendar in dusk](docs/screenshots/shell-calendar-dusk.png) |
| **Calendar** | **Calendar** |
| ![Clipboard history in dawn](docs/screenshots/shell-clipboard-dawn.png) | ![Clipboard history in dusk](docs/screenshots/shell-clipboard-dusk.png) |
| **Clipboard history** | **Clipboard history** |
| ![Session menu in dawn](docs/screenshots/shell-session-dawn.png) | ![Session menu in dusk](docs/screenshots/shell-session-dusk.png) |
| **Session menu** | **Session menu** |
| ![Zen Browser in dawn](docs/screenshots/zen-dawn.png) | ![Zen Browser in dusk](docs/screenshots/zen-dusk.png) |
| **Zen Browser on the NeoBrix repository** | **Zen Browser on the NeoBrix repository** |
| ![Cursor in dawn](docs/screenshots/cursor-dawn.png) | ![Cursor in dusk](docs/screenshots/cursor-dusk.png) |
| **Cursor** | **Cursor** |
| ![Zed in dawn](docs/screenshots/zed-dawn.png) | ![Zed in dusk](docs/screenshots/zed-dusk.png) |
| **Zed** | **Zed** |
| ![Fish and Fastfetch in dawn](docs/screenshots/terminal-dawn.png) | ![Fish and Fastfetch in dusk](docs/screenshots/terminal-dusk.png) |
| **Fish greeting and Fastfetch** | **Fish greeting and Fastfetch** |

## Documentation

The long-form guides live in the [NeoBrix Wiki](https://github.com/asad-albadi/NeoBrix/wiki):

- [Reference](https://github.com/asad-albadi/NeoBrix/wiki/Reference) — architecture, installation, theming, greeter, applications, displays, AI accounts, power, scripts, troubleshooting, and project structure
- [Hyprland Lua](https://github.com/asad-albadi/NeoBrix/wiki/Hyprland-Lua)
- [Keybindings](https://github.com/asad-albadi/NeoBrix/wiki/Keybindings)
- [Design decisions](https://github.com/asad-albadi/NeoBrix/wiki/Design-Decisions)

## Licence

MIT — see [LICENSE](LICENSE).
