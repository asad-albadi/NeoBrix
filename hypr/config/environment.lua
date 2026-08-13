-- Hyprland-scoped environment.
--
-- Deliberately almost empty: session-wide variables (toolkit, cursor, theming,
-- Wayland compatibility) belong to UWSM in ~/.config/uwsm/env, because systemd
-- user services — the shell, the portals, the polkit agent — are not children of
-- Hyprland and would never see anything exported here.
--
-- Only variables that are meaningless outside the compositor process belong in
-- this file. There are currently none, and an empty list is the correct answer
-- rather than a copied block of cargo-culted exports.

return function(_ctx)
    -- Intentionally empty. See ~/.config/uwsm/env and docs/HYPRLAND-LUA.md.
end
