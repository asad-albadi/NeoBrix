# ─────────────────────────────────────────────────────────────────────────────
#  Shared power-source detection.
#
#      source .../lib/power.sh
#      neobrix_on_battery && echo "running on the battery"
# ─────────────────────────────────────────────────────────────────────────────

# True only for a machine that has a battery and is not on mains. A desktop has
# no battery to save, so it is never "on battery" however its supplies report.
neobrix_on_battery() {
    local f battery=0 online=0
    for f in /sys/class/power_supply/*/type; do
        [[ -r $f ]] || continue
        [[ $(cat "$f") == Battery ]] && battery=1
    done
    for f in /sys/class/power_supply/*/online; do
        [[ -r $f ]] || continue
        [[ $(cat "$f") == 1 ]] && online=1
    done
    (( battery == 1 && online == 0 ))
}
