# NeoBrix for Steam

The desktop Steam client theme targets [Millennium 3.5+](https://github.com/SteamClientHomebrew/Millennium).
It styles the main window, library, dialogs, menus, and shared Friends controls.
Game artwork, Store/Community web pages, and Big Picture retain their own styling.

## Enable

1. Install Millennium using its [official Linux instructions](https://docs.steambrew.app/users/getting-started/installation).
   On Arch/CachyOS, the upstream AUR package is `millennium`:

   ```bash
   paru -S millennium
   ```

2. Restart Steam after installing Millennium. Generate the theme for your current palette:

   ```bash
   neobrix-generate-steam "$(qs -c neobrix ipc call theme get)"
   ```

3. Select **NeoBrix** in Steam's Millennium theme settings, or run:

   ```bash
   steam steam://millennium/settings/themes/enable/neobrix
   ```

Millennium supports native Linux Steam; Flatpak and Snap Steam are unsupported.
NeoBrix does not install Millennium automatically or change your selected Steam theme.

## Palette switching

`neobrix-theme` regenerates the selected palette. With Millennium's JavaScript
injection enabled, visible Steam windows read the generated colors every five
seconds and when brought back into view. This does not restart Steam or games.
With JavaScript injection disabled, restart Steam to load the updated CSS.

The generator detects `~/.steam/steam`, `~/.steam/root`, or
`${XDG_DATA_HOME:-~/.local/share}/Steam`. For a custom installation:

```bash
NEOBRIX_STEAM_DIR=/path/to/Steam neobrix-generate-steam dusk
```

Generated files live in `Steam/millennium/themes/neobrix`, matching Millennium
3.5's loader ([upstream source](https://github.com/SteamClientHomebrew/Millennium/blob/v3.5.0/src/bindings/theme_cfg.cc)).
The generator reads only
Steam's UI JavaScript bundles to resolve its hashed CSS classes; it does not
read account data, credentials, or game files. Run the generator again after
Steam updates if part of the library loses its styling.

## Disable

Select the default theme in Millennium, or run:

```bash
steam steam://millennium/settings/themes/disable
```

The source styles live in `client.css`, the loader metadata in `skin.json`,
and the live color reader in `palette-sync.js`. Colors come from
`scripts/lib/palette.sh`. Existing files outside the generator's named outputs
are preserved.
