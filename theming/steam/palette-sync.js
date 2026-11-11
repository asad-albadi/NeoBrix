// Millennium loads this as a module. Only our generated color snapshot is read.
// Keep a selected NeoBrix theme in sync without restarting Steam or a game.
const key = "__neobrixPaletteSync";
if (!window[key]) {
    window[key] = true;
    const url = new URL("palette.json", import.meta.url);
    let previous = "";
    async function sync() {
        if (document.hidden) return;
        try {
            const response = await fetch(url, { cache: "no-store" });
            if (!response.ok) return;
            const palette = await response.json();
            const snapshot = JSON.stringify(palette);
            if (snapshot === previous) return;
            for (const [name, value] of Object.entries(palette)) {
                const color = /^--nb-[a-z-]+$/.test(name) && /^#[0-9a-f]{6}$/i.test(value);
                const scheme = name === "--nb-color-scheme" && ["light", "dark"].includes(value);
                if (color || scheme)
                    document.documentElement.style.setProperty(name, value);
            }
            previous = snapshot;
        } catch (_) { /* Keep the current palette if Millennium is unavailable. */ }
    }
    sync();
    const timer = setInterval(sync, 5000);
    document.addEventListener("visibilitychange", sync);
    window.addEventListener("pagehide", () => {
        clearInterval(timer);
        document.removeEventListener("visibilitychange", sync);
        delete window[key];
    }, { once: true });
}
