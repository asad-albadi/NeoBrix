# Keybindings

`$mod` is **Super**. Source: [`hypr/config/binds.lua`](../hypr/config/binds.lua).

Panel bindings use `hl.dsp.global`, which delivers the keypress straight to the
shell's registered `GlobalShortcut`s — no process is spawned per press.
`hyprctl globalshortcuts` lists them.

Repetitive families (workspaces 1–10, directions, resize steps, screenshots,
media) are generated from tables in `binds.lua`; brightness keys are only bound
when the machine actually has a backlight.

## Shell

| Keys | Action |
|---|---|
| `Super` `Space` | Toggle application launcher |
| `Super` `D` | Toggle application launcher (alias) |
| `Super` `X` | Toggle control center (system tab) |
| `Super` `A` | Toggle control center (notifications tab) |
| `Super` `C` | Toggle calendar panel |
| `Super` `V` | Toggle clipboard history |
| `Super` `Escape` | Toggle session menu |
| `Ctrl` `Alt` `Delete` | Toggle session menu |
| `Super` `Shift` `T` | Toggle light (dawn) / dark (dusk) theme |
| `Super` `Shift` `R` | Restart the shell (`systemctl --user restart neobrix-shell`) |

## Applications

| Keys | Action |
|---|---|
| `Super` `Return` | Terminal (kitty) |
| `Super` `E` | File manager (dolphin) |
| `Super` `W` | Browser (Zen) |
| `Super` `T` | Text editor (quick edits) |
| `Super` `I` | Cursor — the IDE. Only bound when `cursor` is installed. |
| `Super` `Shift` `C` | Calculator |
| `XF86Calculator` | Calculator |
| `Ctrl` `Shift` `Escape` | btop in a terminal |

## Windows

| Keys | Action |
|---|---|
| `Super` `Q` | Close window |
| `Super` `F` | Fullscreen |
| `Super` `M` | Maximise (fullscreen state 1) |
| `Super` `Alt` `Space` | Toggle floating |
| `Super` `J` | Toggle split direction |
| `Super` `O` | Pseudo-tile |
| `Super` `P` | Pin (floating windows) |
| `Super` `Shift` `Escape` | Interactive kill |
| `Super` `←↑↓→` / `H` `K` `;` `L` | Move focus |
| `Super` `Shift` `←↑↓→` / `H` `K` `;` `L` | Move window |
| `Super` `Ctrl` `Shift` `←↑↓→` | Resize window (repeats) |
| `Alt` `Tab` / `Alt` `Shift` `Tab` | Cycle windows |
| `Super` + left-drag | Move window |
| `Super` + right-drag | Resize window |

## Workspaces

| Keys | Action |
|---|---|
| `Super` `1`…`0` | Switch to workspace 1–10 |
| `Super` `Shift` `1`…`0` | Move window to workspace (silently) |
| `Super` `Tab` | Previous workspace (tracked from the `workspace.active` event, so it follows bar clicks too) |
| `Super` `Ctrl` `←` / `→` | Previous / next existing workspace |
| `Super` `Ctrl` `Tab` | Next existing workspace |
| `Super` + scroll | Previous / next workspace |
| `Super` `S` | Toggle scratchpad |
| `Super` `Shift` `S` | Move window to scratchpad |
| `Super` `Shift` `,` / `.` | Move workspace to previous / next monitor |

## Screenshots and picking

| Keys | Action |
|---|---|
| `Print` | Region → file + clipboard |
| `Shift` `Print` | Focused monitor |
| `Super` `Print` | Focused window |
| `Super` `Shift` `Print` | Region, then annotate in satty |
| `Super` `Shift` `P` | Colour picker (hyprpicker, copies hex) |

## Session

| Keys | Action |
|---|---|
| `Super` `Backspace` | Lock (`loginctl lock-session` → hyprlock) |
| `Super` `Escape` | Session menu — lock/logout/suspend one click; hibernate/reboot/shutdown require a confirming second click |

## Hardware

| Keys | Action |
|---|---|
| `XF86AudioRaiseVolume` / `LowerVolume` | Volume ±5 % (works from a TTY too) |
| `XF86AudioMute` / `MicMute` | Mute output / input |
| `XF86MonBrightnessUp` / `Down` | Backlight ±5 % (only bound when a backlight exists) |
| `XF86AudioPlay` / `Pause` / `Next` / `Prev` | Media control over MPRIS |
| `Super` `Alt` `↑` / `↓` | Volume ±5 % (keyboards without media keys) |
| `Super` `Alt` `M` / `N` | Mute output / input |
| `Super` `Alt` `←` / `→` / `Return` | Previous / next / play-pause |

## Mouse, in the shell

| Where | Action |
|---|---|
| Workspace chip | Click switches; scroll anywhere on the group changes workspace |
| Active window title | Click focuses, middle-click closes |
| Volume glyph | Click mutes, scroll changes volume, right-click opens the control center |
| Bluetooth glyph | Click toggles the adapter |
| Clock chip | Click opens the calendar |
| Notification bell | Click opens the centre, right-click toggles do-not-disturb, middle-click clears all |
| Tray icon | Click activates, right-click opens the menu, middle-click secondary-activates |
| Launcher button | Click opens the launcher, right-click opens the session menu |
| Notification card | Middle-click dismisses |
