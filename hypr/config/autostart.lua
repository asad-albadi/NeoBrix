-- Autostart.
--
-- Almost nothing belongs here. The shell, idle daemon, polkit agent and
-- clipboard watcher are systemd user units bound to graphical-session.target
-- (see systemd/ in this repo), which UWSM reaches at login. That gives each one
-- a cgroup, journal logging and independent restart, and means Hyprland
-- reloading its config cannot start a second copy of anything.
--
-- `hl.on("hyprland.start", ...)` fires once when the compositor is up, which is
-- the right hook for the few things that genuinely need the compositor's own
-- environment.

return function(_ctx)
    hl.on("hyprland.start", function()
        -- Applications launched outside the systemd session (XWayland helpers,
        -- some portals) resolve the Wayland socket through the D-Bus activation
        -- environment, which UWSM does not populate with these three.
        hl.exec_cmd("dbus-update-activation-environment --systemd " ..
                    "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    end)
end
