#!/usr/bin/env bash
# Shared runtime ownership and process-identity checks for local desktop helpers.

neobrix_runtime_dir() {
    local dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}/neobrix-runtime-$UID}" mode
    if [[ -z ${XDG_RUNTIME_DIR:-} ]]; then
        mkdir -m 700 -- "$dir" 2>/dev/null || true
    fi
    if [[ $dir != /* || ! -d $dir || -L $dir || ! -O $dir ]]; then
        printf 'neobrix: runtime directory must be private and owned by this user\n' >&2
        return 1
    fi
    mode="$(stat -c '%a' -- "$dir")" || return 1
    if [[ ! $mode =~ ^[0-7]{3,4}$ ]] || (( (8#$mode & 077) != 0 || (8#$mode & 0700) != 0700 )); then
        printf 'neobrix: runtime directory must be private (mode 0700)\n' >&2
        return 1
    fi
    printf '%s\n' "$dir"
}

neobrix_process_stamp() {
    local pid="$1" record
    local -a fields
    [[ $pid =~ ^[0-9]+$ && ${#pid} -le 10 ]] && (( 10#$pid > 1 )) || return 1
    [[ -O /proc/$pid ]] || return 1
    IFS= read -r record < "/proc/$pid/stat" 2>/dev/null || return 1
    # comm can contain spaces or ')'; only the suffix after its final ')' has
    # stable field positions. Reject zombies as well as exited processes.
    read -r -a fields <<< "${record##*) }"
    [[ ${fields[0]:-Z} != Z && ${fields[0]:-X} != X && ${fields[19]:-} =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "${fields[19]}"
}

neobrix_process_matches() {
    local pid="$1" stamp="$2" command="$3" actual expected current
    [[ $stamp =~ ^[0-9]+$ ]] || return 1
    current="$(neobrix_process_stamp "$pid")" || return 1
    [[ $current == "$stamp" ]] || return 1
    expected="$(command -v "$command")" || return 1
    expected="$(readlink -f -- "$expected")" || return 1
    actual="$(readlink -- "/proc/$pid/exe")" || return 1
    # Package upgrades atomically replace executables. The original process is
    # still ours: its PID/start time remains the authority, even after unlink.
    [[ $actual == "$expected" || $actual == "$expected (deleted)" ]]
}
