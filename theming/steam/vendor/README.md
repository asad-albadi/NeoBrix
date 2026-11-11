# Adwaita foundation

Source: https://github.com/tkashkin/Adwaita-for-Steam
Version: 4.4, commit `1e92107a51f6ed53c59c38646444c9eb3a52b030`.
Copyright (c) 2022 Anatoliy Kashkin; MIT license in `LICENSE.adwaita`.

`adwaita.css` flattens the recursive imports of `base.css`, `main.css`, and
`notes.css`, followed by `adwaita/windowcontrols/adwaita.css` and
`injectors/common/windowcontrols/windows.css`. Each source boundary is marked
with an upstream path comment. Trailing whitespace is removed. NeoBrix overrides
live in `../client.css`; the generator includes the foundation and license in
its output. When updating, retain the separate window-control styles and verify
both palettes against the running Steam client.
