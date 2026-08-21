pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Hardware capability probe.
//
//  Everything the shell can conditionally show is gated on a flag from here, so
//  the same dotfiles produce a full laptop UI on real hardware and a trimmed one
//  inside a VM without any per-machine configuration.
//
//  Probes run once at startup (hardware of this kind does not hot-plug on a
//  timescale that matters) except Bluetooth/network, which are event-driven via
//  their own native Quickshell services.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower

Singleton {
    id: root

    // ── battery ─────────────────────────────────────────────────────────────
    // UPower always exposes a display device; on a desktop/VM it is not a real
    // laptop battery, which is what isLaptopBattery distinguishes.
    readonly property bool hasBattery: UPower.displayDevice
                                       && UPower.displayDevice.isLaptopBattery
                                       && UPower.displayDevice.isPresent

    // ── bluetooth ───────────────────────────────────────────────────────────
    readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null

    // ── backlight ───────────────────────────────────────────────────────────
    property bool hasBacklight: false
    property string backlightDevice: ""
    property int backlightMax: 0

    // ── sensors ─────────────────────────────────────────────────────────────
    property bool hasTemperature: false
    property string temperaturePath: ""

    Process {
        id: backlightProbe
        // Pick the first backlight device and read its maximum, if any exists.
        command: ["sh", "-c",
            "d=$(ls -1 /sys/class/backlight 2>/dev/null | head -n1); " +
            "[ -n \"$d\" ] && printf '%s %s' \"$d\" \"$(cat /sys/class/backlight/$d/max_brightness)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length === 2 && parts[0] !== "") {
                    root.backlightDevice = parts[0];
                    root.backlightMax = parseInt(parts[1]) || 0;
                    root.hasBacklight = root.backlightMax > 0;
                }
            }
        }
    }

    Process {
        id: tempProbe
        // Prefer a package/CPU temperature; fall back to any hwmon temp1_input.
        command: ["sh", "-c",
            "for f in /sys/class/hwmon/hwmon*/temp1_input; do " +
            "  [ -r \"$f\" ] || continue; " +
            "  n=$(cat \"$(dirname $f)/name\" 2>/dev/null); " +
            "  case \"$n\" in k10temp|coretemp|zenpower|cpu_thermal|acpitz) printf '%s' \"$f\"; exit 0;; esac; " +
            "done; " +
            "f=$(ls -1 /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); " +
            "[ -n \"$f\" ] && printf '%s' \"$f\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "") {
                    root.temperaturePath = p;
                    root.hasTemperature = true;
                }
            }
        }
    }

    // ── power policy follows the cable ───────────────────────────────────────
    // Unplugging drops the CPU package by 0.7 W and the internal panel to
    // 60 Hz, which halves Hyprland's idle CPU; plugging back in restores both.
    // The work is done by neobrix-power so it can also be run by hand.
    readonly property bool onBattery: UPower.onBattery

    // Deliberately not applied at startup. The policy is a *reaction* to the
    // cable moving; running it on every shell start would quietly overwrite a
    // profile the user had chosen on purpose, every login and every reload.
    property bool policyReady: false
    Component.onCompleted: root.policyReady = true

    onOnBatteryChanged: if (root.policyReady) policyDebounce.restart()

    // UPower reports a couple of transitions in quick succession around a
    // charger being connected, and each profile change writes platform_profile
    // and can wake a suspended dGPU, so settle before acting.
    Timer {
        id: policyDebounce
        interval: 3000
        onTriggered: policyProc.running = true
    }

    Process {
        id: policyProc
        command: ["neobrix-power", root.onBattery ? "battery" : "mains"]
        running: false
    }
}
