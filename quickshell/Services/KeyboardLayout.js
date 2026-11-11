// Derive the bar state from Hyprland's device snapshot. A layout event's
// keyboard wins over `main`, which may still point at another input device.
function describe(keyboards, preferred) {
    const keyboard = keyboards.find(k => k.name === preferred)
                  || keyboards.find(k => k.main) || keyboards[0];
    if (!keyboard)
        return { keyboard: "", label: "", name: "", count: 0, selectedIndex: -1, layouts: [] };

    const layouts = String(keyboard.layout || "").split(",").map(s => s.trim()).filter(s => s);
    const index = Math.max(0, Math.min(layouts.length - 1, keyboard.active_layout_index || 0));
    const code = layouts[index] || "";
    const name = keyboard.active_keymap || code;
    const label = /^English\b/.test(name) ? "EN"
                : code === "ara" ? "AR" : code.slice(0, 2).toUpperCase();
    const names = { us: "English (US)", gb: "English (UK)", ara: "Arabic", de: "German" };
    const options = layouts.map((layout, i) => ({
        index: i,
        name: i === index ? name : names[layout] || layout.toUpperCase(),
        label: layout === "us" || layout === "gb" ? "EN"
             : layout === "ara" ? "AR" : layout.slice(0, 2).toUpperCase(),
        current: i === index
    }));
    return {
        keyboard: keyboard.name, label: label, name: name, count: layouts.length,
        selectedIndex: index, layouts: options
    };
}

function selectionCommand(state, index) {
    if (!Number.isInteger(index) || index < 0 || index >= state.count
        || index === state.selectedIndex) return [];
    return ["hyprctl", "switchxkblayout", "all", String(index)];
}
