# Neobrix for Dark Reader

The Neobrix palette as a [Dark Reader](https://darkreader.org) configuration, so
websites match the rest of the desktop. Works in any browser Dark Reader supports
— Firefox, Zen, Chrome — and needs nothing else from this repository.

Both files are **generated** from `scripts/lib/palette.sh`, the same source the
shell, terminals, GTK, Qt, hyprlock and the editor theme read. Do not hand-edit
them; regenerate with:

```bash
./scripts/neobrix-generate-darkreader theming/darkreader
```

## Install

### 1. Import the settings — this is all you need

`darkreader-neobrix.json`

Dark Reader toolbar icon → **Settings** → **Manage Settings** → **Import
Settings**, then pick the file. It is a *file picker*, not a text box — don't
paste the contents anywhere.

That is the whole installation. It sets:

| | dawn (light) | dusk (dark) |
|---|---|---|
| page background | `#fcf6ee` | `#2e241c` |
| page text | `#1e1815` | `#f6ede2` |
| selection | `#f0a377` | `#f0a377` |
| scrollbar | `#100d0b` | `#100d0b` |

The file carries **both** schemes, so one import covers light and dark. It also
sets `automation.mode = "system"`, so Dark Reader follows the system colour
scheme rather than needing to be toggled by hand.

On a Neobrix desktop that means it tracks the palette: `neobrix-theme` sets the
desktop `color-scheme` through gsettings and the XDG portal, which is what
Firefox derives system dark mode from. Switch the desktop with `Super+Shift+T`
and Dark Reader switches with it.

Elsewhere it simply follows your OS light/dark setting, which is usually what you
want anyway.

### 2. Dynamic theme fixes — optional

`darkreader-dynamic-fixes.txt`

Only worth it if you want the peach accent inside native form controls. The
import above already looks like Neobrix without this.

Dark Reader → **Dev Tools** → **Edit dynamic theme fixes**. Paste the file's
contents at the **very top** of the box, add a line of `=` signs after it, and
leave everything already there untouched. Then **Apply**.

> Do not replace the whole box. It contains thousands of lines of built-in
> per-site fixes that Dark Reader ships, and replacing them breaks those sites.

It adds:

* `accent-color` — tints native checkboxes, radios, ranges and progress bars
* `::selection` — Neobrix selection colours
* `scrollbar-color`
* `:focus-visible` — a 2px accent focus ring

Colours in that file are wrapped in Dark Reader's `${...}` syntax, which means
"adapt this colour to the active theme". That is what makes a single block correct
in both schemes instead of pinning it to one.

The rules are deliberately conservative, because the block matches **every** site:
only properties that cannot break a layout. Notably it does *not* force
`html`/`body` backgrounds — Dark Reader's own colour engine does that properly,
and overriding it globally is how Dark Reader configs break image-heavy pages.

## Notes

Dark Reader stores its configuration in extension storage (IndexedDB inside the
browser profile) and supports no managed-storage manifest, so there is no way to
install this automatically — importing by hand is the only supported route.

The schemas here were taken from Dark Reader's own sources
(`src/defaults.ts` and `src/config/dynamic-theme-fixes.config`). Unknown keys are
dropped silently on import, and the fixes format is positional — a stray comment
line would be parsed as a URL pattern — which is why neither file has comments in
it.
