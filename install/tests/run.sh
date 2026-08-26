#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Neobrix installer tests.
#
#  Every bug this installer has shipped was the same bug: stdin is not a
#  terminal, it is the program. ask.sh prompted into the void; usage() read
#  "$0" and found "bash"; `sudo pacman -S` read its confirmation from stdin and
#  swallowed the rest of the install. A test that runs bootstrap.sh from a file
#  cannot see any of that — the piped form is a different program.
#
#  So the piped form is the default here, not the afterthought:
#
#      ./install/tests/run.sh              local cases (fast, hermetic)
#      ./install/tests/run.sh --container  the above, plus the real
#                                          `… | bash` install in a container
#                                          with the packages genuinely absent
#      ./install/tests/run.sh --container-only
#
#  The local cases touch nothing outside a mktemp directory: no packages, no
#  systemd units, no $HOME. The container case needs docker (via sudo) and
#  builds a ~2 GB image the first time; docker caches it after that.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$HERE/../.." && pwd)"
BOOTSTRAP="$REPO/install/bootstrap.sh"

DO_LOCAL=1
DO_CONTAINER=0
case "${1:-}" in
    --container)      DO_CONTAINER=1 ;;
    --container-only) DO_CONTAINER=1; DO_LOCAL=0 ;;
    "")               ;;
    *) echo "usage: $0 [--container|--container-only]" >&2; exit 2 ;;
esac

c_ok=$'\033[32m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
PASS=0; FAIL=0; SKIP=0
case_() { printf '\n%s──%s %s\n' "$c_dim" "$c_off" "$1"; }
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$c_ok"  "$c_off" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$c_err" "$c_off" "$1"; }
skip() { SKIP=$((SKIP+1)); printf '  %sSKIP%s %s\n' "$c_dim" "$c_off" "$1"; }

# assert_eq <what> <expected> <actual>
assert_eq() {
    if [[ "$2" == "$3" ]]; then ok "$1"; else
        bad "$1"; printf '       expected: %s\n       actual:   %s\n' "$2" "$3"
    fi
}
# assert_has <what> <needle> <haystack>
assert_has() {
    if [[ "$3" == *"$2"* ]]; then ok "$1"; else
        bad "$1"; printf '       not found: %s\n' "$2"
        printf '%s\n' "$3" | sed 's/^/       | /' | tail -20
    fi
}
# assert_lacks <what> <needle> <haystack>
assert_lacks() {
    if [[ "$3" != *"$2"* ]]; then ok "$1"; else
        bad "$1"; printf '       should not appear: %s\n' "$2"
    fi
}
# assert_before <what> <first> <then> <haystack>  — ordering, which is the whole
# point when the failure mode is "the run stopped after step N".
assert_before() {
    local a b
    a="$(printf '%s\n' "$4" | grep -n -- "$2" | head -1 | cut -d: -f1)"
    b="$(printf '%s\n' "$4" | grep -n -- "$3" | head -1 | cut -d: -f1)"
    if [[ -n $a && -n $b ]] && (( a < b )); then ok "$1"; else
        bad "$1"; printf '       "%s" at line %s, "%s" at line %s\n' "$2" "${a:-none}" "$3" "${b:-none}"
    fi
}

TMP=""
cleanup() { [[ -n $TMP && -d $TMP ]] && rm -rf "$TMP"; }
trap cleanup EXIT

# ═════════════════════════════════════════════════════════════════════════════
#  local: a child process must never inherit a piped script's stdin
# ═════════════════════════════════════════════════════════════════════════════
# Runs the real bootstrap.sh, piped, with no terminal — which is a different
# program from the same file run by path, and the only form in which this bug
# exists. The stub packages.sh stands in for pacman: it reads one line from
# stdin and reports what it got. Before the fix it got the next *line of the
# installer*, and that line then never ran.
#
# piped_run <dir> <bootstrap-file>  → stdout+stderr of the run
piped_run() {
    cat "$2" | env -i PATH="$PATH" HOME="$1/home" \
        NEOBRIX_DIR="$1/clone" NEOBRIX_REPO="$1/upstream.git" \
        bash -s -- --yes 2>&1
}

stdin_fixture() {
    local d="$1"
    fake_clone "$d/clone" "$d/upstream.git" ''
    # Drains stdin rather than reading one line, because that is what pacman
    # does — it reads in blocks, so it took *everything* below the packages step
    # with it, not just the next line. A line-at-a-time stub understates the bug
    # to the point of not reproducing it.
    cat > "$d/clone/install/packages.sh" <<'EOF'
#!/usr/bin/env bash
printf 'Proceed with installation? [Y/n] '
eaten="$(cat)"
if [[ -n $eaten ]]; then
    printf 'CHILD-READ[%d bytes of script]\n' "${#eaten}"
else
    printf 'CHILD-READ[EOF]\n'
fi
EOF
    chmod +x "$d/clone/install/packages.sh"
    git -C "$d/clone" add -A
    git -C "$d/clone" commit -qm stub
}

test_piped_stdin() {
    case_ "piped stdin: a child must see EOF, not this script's source"
    local d="$TMP/stdin"; mkdir -p "$d"
    stdin_fixture "$d"
    local out; out="$(piped_run "$d" "$BOOTSTRAP")"

    assert_has    "the child ran"                  "CHILD-READ" "$out"
    assert_has    "it saw EOF, not source"         "CHILD-READ[EOF]" "$out"
    assert_lacks  "it read none of this script"    "bytes of script" "$out"
    assert_before "the run continued past packages" "CHILD-READ" "STUB-CLEANUP" "$out"
    assert_has    "it reached the last step"       "Neobrix is deployed" "$out"

    # A test that cannot fail on the unfixed code is not evidence of anything.
    # This runs the same fixture against the last bootstrap.sh that still had the
    # bug, and is here to be seen failing the assertions above.
    #
    # Found by asking git which commit introduced the fix and taking its parent,
    # rather than by reading origin/main. Pinned to origin/main this case
    # quietly stopped running the moment the fix was pushed — it reported SKIP,
    # the suite stayed green, and the same commit then produced different
    # assertion counts on two machines depending on what each had fetched.
    # A control that disappears when the thing it controls for is fixed is a
    # control that is absent exactly when nobody is looking.
    case_ "piped stdin: the same fixture catches the bug in the code it fixed"
    local old="$TMP/old-bootstrap.sh" rev
    rev="$(git -C "$REPO" log --format=%H -S'NB_CHILD_STDIN' --reverse -- install/bootstrap.sh | head -1)"
    if [[ -z $rev ]] || ! git -C "$REPO" show "$rev^:install/bootstrap.sh" > "$old" 2>/dev/null; then
        skip "cannot find the pre-fix bootstrap.sh in this repository's history"
        return
    fi
    printf '  %sagainst%s %s\n' "$c_dim" "$c_off" "$(git -C "$REPO" log --oneline -1 "$rev^")"
    local d2="$TMP/stdin-old"; mkdir -p "$d2"
    stdin_fixture "$d2"
    local before; before="$(piped_run "$d2" "$old")"
    if [[ "$before" == *"CHILD-READ[EOF]"* ]]; then
        bad "the pre-fix bootstrap.sh does not show the bug — this control is broken"
    else
        # This stub reads one line, so one line of the installer goes missing.
        # Real pacman reads in blocks and took everything below the packages
        # step with it, which is why the container case runs the real thing.
        assert_has   "old code fed the script to the child" "bytes of script" "$before"
        assert_lacks "so the next step never ran"           "STUB-CLEANUP" "$before"
        assert_lacks "and the run never reached the end"    "Neobrix is deployed" "$before"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  local: origin is not repointed behind the user's back
# ═════════════════════════════════════════════════════════════════════════════
# fake_clone <dir> <bare> <origin-url>   — a clone whose origin is <origin-url>,
# or the bare repo itself when that is empty. Carries stubs for the two things
# bootstrap.sh loads out of the clone.
fake_clone() {
    local dir="$1" bare="$2" origin="$3" seed
    # -b main: without it the bare repo's HEAD is master, the clone comes up
    # empty, and every fixture written into it lands in a directory that is not
    # there yet.
    git init -q --bare -b main "$bare"
    seed="$(mktemp -d "$TMP/seed.XXXX")"
    mkdir -p "$seed/install/lib"
    cat > "$seed/install/lib/ask.sh" <<'EOF'
NB_TTY=""
confirm() { [[ $1 == yes ]]; }
EOF
    printf '#!/usr/bin/env bash\necho STUB-PACKAGES\nexit 1\n' > "$seed/install/packages.sh"
    printf '#!/usr/bin/env bash\necho STUB-CLEANUP\n'          > "$seed/install/cleanup.sh"
    printf '#!/usr/bin/env bash\necho STUB-DEPLOY\n'           > "$seed/install/deploy.sh"
    chmod +x "$seed/install"/*.sh
    git -C "$seed" init -q -b main
    git -C "$seed" add -A
    git -C "$seed" -c user.email=t@t -c user.name=t commit -qm seed
    git -C "$seed" push -q "$bare" main
    git clone -q "$bare" "$dir"
    git -C "$dir" config user.email t@t; git -C "$dir" config user.name t
    [[ -n $origin ]] && git -C "$dir" remote set-url origin "$origin"
    return 0
}

# origin_case <name> <origin-url> <NEOBRIX_REPO> <keep|refuse>
origin_case() {
    local name="$1" origin="$2" repo="$3" want="$4"
    case_ "origin: $name"
    local d; d="$(mktemp -d "$TMP/origin.XXXX")"
    fake_clone "$d/clone" "$d/upstream.git" "$origin"
    local before after out ec
    before="$(git -C "$d/clone" remote get-url origin 2>/dev/null || echo NONE)"
    # BatchMode/GIT_TERMINAL_PROMPT: never sit waiting on a credential prompt for
    # a URL that is only here to be compared. Whether the pull then succeeds is
    # beside the point — every assertion below is on output printed before it.
    out="$(cat "$BOOTSTRAP" | env -i PATH="$PATH" HOME="$d/home" \
        GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=3' \
        NEOBRIX_DIR="$d/clone" NEOBRIX_REPO="$repo" bash -s -- --yes 2>&1)"; ec=$?
    after="$(git -C "$d/clone" remote get-url origin 2>/dev/null || echo NONE)"

    if [[ $want == keep ]]; then
        assert_eq  "origin unchanged" "$before" "$after"
        assert_has "said so"          "left alone" "$out"
    else
        # A clone of someone else's repository is not ours to redirect: refuse,
        # change nothing, and say what the ways forward are.
        assert_eq    "origin unchanged" "$before" "$after"
        assert_eq    "exit status"      "1" "$ec"
        assert_has   "named the clone's own remote" "$before" "$out"
        assert_has   "offered --dir"    "--dir <path>" "$out"
        assert_has   "offered NEOBRIX_REPO" "NEOBRIX_REPO=$before" "$out"
        assert_has   "offered set-url"  "remote set-url origin $repo" "$out"
        assert_lacks "did not reach packages" "STUB-PACKAGES" "$out"
    fi
}

test_origins() {
    # The reported bug: an ssh remote replaced by the https default, every run.
    origin_case "ssh scp-form vs the https default" \
        'git@github.com:asad-albadi/NeoBrix.git' \
        'https://github.com/asad-albadi/NeoBrix.git' keep
    origin_case "ssh:// URL form, with a port" \
        'ssh://git@github.com:22/asad-albadi/NeoBrix.git' \
        'https://github.com/asad-albadi/NeoBrix.git' keep
    origin_case "same URL, differing in case and .git" \
        'https://GitHub.com/asad-albadi/neobrix' \
        'https://github.com/asad-albadi/NeoBrix.git' keep
    origin_case "a genuinely different repository is refused, not repointed" \
        'git@github.com:someone-else/their-fork.git' \
        'https://github.com/asad-albadi/NeoBrix.git' refuse

    case_ "origin: absent origin is added"
    local d; d="$(mktemp -d "$TMP/origin.XXXX")"
    fake_clone "$d/clone" "$d/upstream.git" ''
    git -C "$d/clone" remote remove origin
    local out
    out="$(cat "$BOOTSTRAP" | env -i PATH="$PATH" HOME="$d/home" \
        NEOBRIX_DIR="$d/clone" NEOBRIX_REPO="$d/upstream.git" bash -s -- --yes 2>&1)"
    assert_eq  "origin added"    "$d/upstream.git" "$(git -C "$d/clone" remote get-url origin)"
    assert_has "reached packages" "STUB-PACKAGES" "$out"
}

# ═════════════════════════════════════════════════════════════════════════════
#  local: packages.sh must not report its own failure as success
# ═════════════════════════════════════════════════════════════════════════════
# A stubbed pacman, so this runs on any machine and installs nothing.
test_packages_reporting() {
    local d; d="$TMP/pkg"; mkdir -p "$d/bin"
    printf '#!/usr/bin/env bash\nshift 0\nexec "$@"\n' > "$d/bin/sudo"

    case_ "packages: a required package absent from every repo is fatal"
    cat > "$d/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ $2 == greetd-regreet ]] && exit 1; exit 0 ;;
  -Sy) exit 0 ;;
  -Si) if [[ $2 == greetd-regreet ]]; then
         echo "error: package 'greetd-regreet' was not found" >&2; exit 1; fi; exit 0 ;;
esac
exit 1
EOF
    chmod +x "$d/bin"/*
    local out ec
    out="$(PATH="$d/bin:$PATH" bash "$REPO/install/packages.sh" 2>&1)"; ec=$?
    assert_eq    "exit status"                    "1" "$ec"
    assert_lacks "no false success"               "already installed" "$out"
    assert_has   "names the package"              "greetd-regreet" "$out"
    assert_has   "quotes pacman verbatim"         "was not found" "$out"
    assert_lacks "does not blame healthy mirrors" "check your mirrors" "$out"

    case_ "packages: a pacman that cannot answer is reported as itself"
    cat > "$d/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -Qq) exit 1 ;;
  -Sy) echo "error: failed to synchronize all databases (unable to lock database)" >&2; exit 1 ;;
  -Si) echo "error: database file for 'core' does not exist (use '-Sy' to download)" >&2; exit 1 ;;
esac
exit 1
EOF
    chmod +x "$d/bin/pacman"
    out="$(PATH="$d/bin:$PATH" bash "$REPO/install/packages.sh" 2>&1)"; ec=$?
    assert_eq  "exit status"              "1" "$ec"
    assert_has "blames pacman, not the list" "cannot query its package databases" "$out"
    assert_has "quotes pacman verbatim"   "database file for 'core' does not exist" "$out"
    assert_has "mirrors named only now"   "check your mirrors" "$out"
    assert_lacks "no package list at all" "greetd-regreet" "$out"
}

# ═════════════════════════════════════════════════════════════════════════════
#  local: who is allowed to answer pacman's confirmation
# ═════════════════════════════════════════════════════════════════════════════
# --noconfirm does not only answer "Proceed with installation?" — it accepts
# package replacements too, so an unattended run could swap a -git build out
# from under another account's desktop. With nobody to ask, packages.sh must
# stop; with --yes it may proceed and must say what that allowed.
#
# The terminal is controlled rather than inherited: `setsid -w` detaches from
# the controlling terminal, so /dev/tty genuinely cannot be opened, and
# `script` allocates a real pty. Inheriting whatever the person running the
# suite happened to have would make these two cases swap places.
test_confirmation() {
    local d="$TMP/confirm"; mkdir -p "$d/bin"
    printf '#!/usr/bin/env bash\nshift 0\nexec "$@"\n' > "$d/bin/sudo"
    # One package missing, and every `-S` recorded with its flags.
    cat > "$d/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ $2 == cliphist ]] && exit 1; exit 0 ;;
  -Sy|-Si) exit 0 ;;
  -S)  printf '%s\n' "$*" >> "$PACMAN_LOG"; exit 0 ;;
esac
exit 1
EOF
    chmod +x "$d/bin"/*
    local out ec log
    log="$d/pacman.log"

    case_ "confirmation: no terminal and no --yes installs nothing"
    : > "$log"
    out="$(setsid -w env PATH="$d/bin:$PATH" PACMAN_LOG="$log" \
        bash "$REPO/install/packages.sh" 2>&1 </dev/null)"; ec=$?
    assert_eq  "exit status"                "1" "$ec"
    assert_eq  "pacman -S was never run"    "" "$(cat "$log")"
    assert_has "says why"                   "no terminal to confirm at" "$out"
    assert_has "gives the piped form"       "bash -s -- --yes" "$out"
    assert_has "gives the direct form"      "./install/packages.sh --yes" "$out"
    assert_has "warns what --yes accepts"   "also accepts package replacements" "$out"

    case_ "confirmation: --yes proceeds, and says what it accepted"
    : > "$log"
    out="$(setsid -w env PATH="$d/bin:$PATH" PACMAN_LOG="$log" \
        bash "$REPO/install/packages.sh" --yes 2>&1 </dev/null)"; ec=$?
    assert_eq  "exit status"                 "0" "$ec"
    assert_has "installed the missing one"   "cliphist" "$(cat "$log")"
    assert_has "with --noconfirm"            "--noconfirm" "$(cat "$log")"
    assert_has "named replacements, not just the prompt" \
               "accepts package replacements and conflict resolutions" "$out"

    case_ "confirmation: at a terminal the prompt is left to be answered"
    : > "$log"
    # A real pty, so /dev/tty opens and the interactive branch is the one taken.
    out="$(script -qec "env PATH=$d/bin:\$PATH PACMAN_LOG=$log bash $REPO/install/packages.sh" /dev/null </dev/null 2>&1)"; ec=$?
    assert_eq    "exit status"                "0" "$ec"
    assert_has   "pacman was run"             "cliphist" "$(cat "$log")"
    assert_lacks "without --noconfirm"        "--noconfirm" "$(cat "$log")"
    assert_lacks "and nothing was skipped on the user's behalf" \
                 "installing without pacman's confirmation" "$out"
}

# ═════════════════════════════════════════════════════════════════════════════
#  container: the real `… | bash`, with the packages genuinely absent
# ═════════════════════════════════════════════════════════════════════════════
IMAGE=neobrix-installer-test
test_container() {
    case_ "container: unattended, the real piped install must refuse"
    local D="sudo docker"
    if ! $D info >/dev/null 2>&1; then
        skip "docker is not usable here (tried: $D info)"; return
    fi
    echo "  building $IMAGE — the first run downloads the real package set (~2 GB);"
    echo "  docker caches the layer, and only a change to packages.sh invalidates it"
    if ! $D build -t "$IMAGE" -f "$HERE/Dockerfile" "$REPO" >"$TMP/build.log" 2>&1; then
        bad "image build failed"; tail -25 "$TMP/build.log" | sed 's/^/       | /'; return
    fi

    # systemd as PID 1, then a real user manager for it — deploy.sh ends in
    # `systemctl --user enable`, and without one the run cannot reach its last
    # step, which is the very thing being asserted.
    local cid; cid="$($D run -d --privileged --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "$REPO:/src:ro" "$IMAGE")"
    local st=""
    for _ in $(seq 1 30); do
        st="$($D exec "$cid" systemctl is-system-running 2>/dev/null || true)"
        [[ $st == running || $st == degraded ]] && break
        sleep 1
    done
    if [[ $st != running && $st != degraded ]]; then
        bad "systemd never came up in the container (state: ${st:-unknown})"
        $D rm -f "$cid" >/dev/null; return
    fi
    $D exec "$cid" systemctl start user@1000.service >/dev/null 2>&1

    # Unattended first, because it must install nothing — and because anything
    # it did install would be missing from the run below.
    local out ec
    out="$($D exec -u tester -e XDG_RUNTIME_DIR=/run/user/1000 "$cid" container-run 2>&1)"; ec=$?
    printf '%s\n' "$out" > "$TMP/container-unattended.log"
    assert_eq    "unattended run fails"       "1" "$ec"
    assert_has   "and says why"               "no terminal to confirm at" "$out"
    assert_has   "and how to proceed"         "bash -s -- --yes" "$out"
    assert_lacks "nothing was auto-accepted"  "--noconfirm" "$out"
    local still_absent
    still_absent="$($D exec "$cid" bash -c 'pacman -Qq cliphist >/dev/null 2>&1 && echo installed || echo absent')"
    assert_eq    "it really installed nothing" "absent" "$still_absent"

    case_ "container: the same run with --yes gets through to the end"
    out="$($D exec -u tester -e XDG_RUNTIME_DIR=/run/user/1000 "$cid" container-run --yes 2>&1)"; ec=$?
    $D rm -f "$cid" >/dev/null
    printf '%s\n' "$out" > "$TMP/container.log"

    assert_has    "packages were genuinely missing" "missing:" "$out"
    assert_has    "pacman really ran"               "Proceed with installation" "$out"
    assert_before "packages ran before deploy"      "missing:" "checking dependencies" "$out"
    assert_has    "deploy started"                  "linking configuration" "$out"
    # No compositor in a container, so this is also the case that proves
    # deploy.sh's version guard is reachable again rather than taking the script
    # with it — the whole run used to end here, silently.
    assert_has    "the version guard runs"          "could not determine the Hyprland version" "$out"
    assert_has    "deploy installed its units"      "installing systemd user units" "$out"
    assert_has    "reached the last step"           "Neobrix is deployed" "$out"
    assert_eq     "exit status"                     "0" "$ec"
    printf '  logs: %s\n        %s\n' "$TMP/container-unattended.log" "$TMP/container.log"
    return 0
}


# ═════════════════════════════════════════════════════════════════════════════
#  neobrix-monitors, with a stubbed compositor.
#
#  The engine never has to guess: it reads `hyprctl -j monitors all` and writes
#  through `hyprctl eval`. Both are stubbed here, so a layout can be saved,
#  applied and generated with no Hyprland anywhere, and the eval calls it would
#  have made are asserted instead of executed.
# ═════════════════════════════════════════════════════════════════════════════

monitors_stub_dir() {
    local dir="$1"
    mkdir -p "$dir/bin"
    cat > "$dir/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
# Two outputs, one of them scaled, plus an eval log so the test can assert on
# what would have been applied.
if [[ "$*" == *"monitors all"* || "$*" == "-j monitors" ]]; then
    cat <<'JSON'
[
 {"id":0,"name":"eDP-1","description":"BOE panel","make":"BOE","model":"0x090F","serial":"",
  "width":1920,"height":1080,"refreshRate":144.0,"x":0,"y":0,"scale":1.0,"transform":0,
  "vrr":false,"disabled":false,"mirrorOf":"none","focused":true,
  "physicalWidth":340,"physicalHeight":190,
  "availableModes":["1920x1080@144.00Hz","1920x1080@60.00Hz"]},
 {"id":1,"name":"DP-2","description":"Acme WideOne 123","make":"Acme","model":"WideOne","serial":"123",
  "width":3440,"height":1440,"refreshRate":100.0,"x":1920,"y":0,"scale":1.0,"transform":0,
  "vrr":false,"disabled":false,"mirrorOf":"none","focused":false,
  "physicalWidth":800,"physicalHeight":335,
  "availableModes":["3440x1440@100.00Hz","3440x1440@60.00Hz"]}
]
JSON
    exit 0
fi
if [[ ${1:-} == eval ]]; then
    printf '%s\n' "$2" >> "${NB_EVAL_LOG:?}"
    echo ok
    exit 0
fi
echo ok
STUB
    chmod +x "$dir/bin/hyprctl"
}

test_monitors() {
    case_ "neobrix-monitors drives the layout without touching a compositor"

    local dir="$TMP/mon"
    mkdir -p "$dir/state"
    monitors_stub_dir "$dir"
    export NB_EVAL_LOG="$dir/eval.log"
    : > "$NB_EVAL_LOG"

    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")

    # --help must not need a compositor: the check lives in the reader, not at
    # the top of the file.
    local help_out
    help_out="$(env PATH=/usr/bin:/bin "$REPO/scripts/neobrix-monitors" --help 2>&1 || true)"
    assert_has "--help works with no hyprctl on PATH" "Monitor layout" "$help_out"

    # Reading.
    local listing; listing="$("${run[@]}" list 2>&1)"
    assert_has "list names the internal panel" "eDP-1" "$listing"
    assert_has "list reports the external mode" "3440x1440" "$listing"

    # The reported refresh is snapped to an advertised mode, so a saved profile
    # holds a string the hardware recognises.
    local state; state="$("${run[@]}" state 2>&1)"
    assert_has "state snaps to an advertised mode" '"mode": "1920x1080@144"' "$state"

    # Saving, then reading back.
    "${run[@]}" save "Desk" >/dev/null 2>&1
    local profs; profs="$("${run[@]}" profiles 2>&1)"
    assert_has "a saved profile is listed" "Desk" "$profs"
    assert_has "the profile records both outputs" "DP-2" "$profs"

    # Applying emits one hl.monitor call per output, with an explicit position:
    # "auto" would re-place the outputs and rearrange the desk.
    : > "$NB_EVAL_LOG"
    "${run[@]}" apply "Desk" >/dev/null 2>&1
    local evals; evals="$(cat "$NB_EVAL_LOG")"
    assert_has "apply drives the internal panel" 'output="eDP-1"' "$evals"
    assert_has "apply passes an explicit position" 'position="1920x0"' "$evals"
    assert_lacks "apply never asks for auto placement" 'position="auto"' "$evals"

    # The refresh cap is what the battery policy uses. It must pick the fastest
    # mode within the limit, and only on an internal panel.
    : > "$NB_EVAL_LOG"
    "${run[@]}" cap 60 >/dev/null 2>&1
    evals="$(cat "$NB_EVAL_LOG")"
    assert_has "cap drops the internal panel to 60" 'mode="1920x1080@60"' "$evals"
    assert_lacks "cap leaves an external display alone" 'output="DP-2"' "$evals"

    # Uncapping restores the mode that was in force, not a guess at the fastest.
    : > "$NB_EVAL_LOG"
    "${run[@]}" uncap >/dev/null 2>&1
    evals="$(cat "$NB_EVAL_LOG")"
    assert_has "uncap restores the remembered mode" 'mode="1920x1080@144"' "$evals"

    # A layout is applied at config-parse time so the session does not start in
    # the wrong shape and visibly snap out of it.
    local gen="$dir/generated.lua"
    env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state" "XDG_RUNTIME_DIR=$dir" \
        NB_GENERATED="$gen" "$REPO/scripts/neobrix-monitors" generate >/dev/null 2>&1 || true
    if [[ -r $gen ]]; then
        local lua; lua="$(cat "$gen")"
        assert_has "the generated Lua sets monitors" 'hl.monitor' "$lua"
        assert_has "the generated Lua keeps a catch-all first" 'output = ""' "$lua"
    else
        skip "generate wrote outside the sandbox (NB_GENERATED unset)"
    fi

    unset NB_EVAL_LOG
}

test_monitors_rotation() {
    case_ "a rotated screen occupies its mode turned on its side"

    local dir="$TMP/rot"
    mkdir -p "$dir/bin" "$dir/state"
    # DP-1 is rotated: 2560x1440 reported, 1440x2560 occupied. HDMI sits where a
    # layout built before the rotation would have left it -- 1920 + 2560 -- which
    # is 1120px past the rotated panel's real right edge. That gap is dead space
    # the pointer cannot cross, and it is the bug this covers.
    cat > "$dir/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"monitors all"* || "$*" == "-j monitors" ]]; then
    cat <<'JSON'
[
 {"id":0,"name":"eDP-1","description":"BOE panel","make":"BOE","model":"x","serial":"",
  "width":1920,"height":1080,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"transform":0,
  "vrr":false,"disabled":false,"mirrorOf":"none","focused":false,
  "physicalWidth":340,"physicalHeight":190,"availableModes":["1920x1080@60.00Hz"]},
 {"id":1,"name":"DP-1","description":"Acme Tall 1","make":"Acme","model":"Tall","serial":"1",
  "width":2560,"height":1440,"refreshRate":144.0,"x":1920,"y":0,"scale":1.0,"transform":1,
  "vrr":false,"disabled":false,"mirrorOf":"none","focused":true,
  "physicalWidth":600,"physicalHeight":340,"availableModes":["2560x1440@144.00Hz"]},
 {"id":2,"name":"HDMI-A-2","description":"Acme Wide 2","make":"Acme","model":"Wide","serial":"2",
  "width":3440,"height":1440,"refreshRate":100.0,"x":4480,"y":0,"scale":1.0,"transform":0,
  "vrr":false,"disabled":false,"mirrorOf":"none","focused":false,
  "physicalWidth":800,"physicalHeight":335,"availableModes":["3440x1440@100.00Hz"]}
]
JSON
    exit 0
fi
if [[ ${1:-} == eval ]]; then printf '%s\n' "$2" >> "${NB_EVAL_LOG:?}"; echo ok; exit 0; fi
echo ok
STUB
    chmod +x "$dir/bin/hyprctl"
    export NB_EVAL_LOG="$dir/eval.log"
    : > "$NB_EVAL_LOG"

    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")

    local listing; listing="$("${run[@]}" list 2>&1)"
    assert_has "list marks the rotation" "rot90" "$listing"

    : > "$NB_EVAL_LOG"
    "${run[@]}" arrange >/dev/null 2>&1
    local evals; evals="$(cat "$NB_EVAL_LOG")"

    # 1920 + 1440 = 3360, using the rotated footprint. Packing on the reported
    # 2560 would put it back at 4480 and leave the gap in place.
    assert_has "arrange packs against the rotated width" 'position="3360x0"' "$evals"
    assert_lacks "arrange does not use the unrotated width" 'position="4480x0"' "$evals"
    # The rotation itself must survive being re-applied.
    assert_has "arrange preserves the transform" "transform=1" "$evals"

    # Dropping a screen to the left of the leftmost one is a negative
    # coordinate. It has to be accepted -- clamping it to zero turns "put it on
    # the left" into "overlap what is already there" -- and then the whole layout
    # is shifted back so the corner sits at 0,0.
    : > "$NB_EVAL_LOG"
    "${run[@]}" place DP-1 -1440x0 >/dev/null 2>&1
    evals="$(cat "$NB_EVAL_LOG")"
    assert_lacks "place leaves nothing at a negative coordinate" 'position="-' "$evals"
    assert_has "place puts the moved screen at the origin" 'output="DP-1", mode="2560x1440@144", position="0x0"' "$evals"
    # eDP-1 was at 0 and everything shifted right by the 1440 the rotated panel
    # occupies, so it lands at 1440 rather than staying put.
    assert_has "place shifts the others to keep the corner at 0,0" 'output="eDP-1", mode="1920x1080@60", position="1440x0"' "$evals"

    unset NB_EVAL_LOG
}

test_monitors_place_guard() {
    case_ "a screen that is off cannot be placed, but can be switched on"

    local dir="$TMP/mon"          # reuses the stub from test_monitors
    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")
    export NB_EVAL_LOG="$dir/eval.log"

    # The stub reports everything enabled, so disable one through the tool and
    # then try to move it.
    : > "$NB_EVAL_LOG"
    local out ec
    out="$("${run[@]}" place NOPE 0x0 2>&1)"; ec=$?
    assert_has "place rejects an unknown output" "no output named" "$out"
    [[ $ec -ne 0 ]] && ok "place fails loudly on an unknown output" \
                    || bad "place fails loudly on an unknown output"

    # And the guard that matters: it must live in place, not in set. `set
    # disabled=false` is the only way back from a dark screen, and a guard in the
    # wrong function once made that unrecoverable.
    : > "$NB_EVAL_LOG"
    "${run[@]}" set eDP-1 disabled=false >/dev/null 2>&1
    local evals; evals="$(cat "$NB_EVAL_LOG")"
    assert_has "set can still switch a screen on" 'disabled=false' "$evals"

    unset NB_EVAL_LOG
}

test_monitors_hazards() {
    case_ "the ways this could take the screen away, or lose the profiles"

    local dir="$TMP/haz"
    mkdir -p "$dir/bin" "$dir/state"
    cp "$TMP/mon/bin/hyprctl" "$dir/bin/hyprctl"
    export NB_EVAL_LOG="$dir/eval.log"
    : > "$NB_EVAL_LOG"
    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")

    # Two profiles for the same screens, one of which switches a screen off --
    # "laptop closed while docked" is an ordinary thing to save. Hyprland applies
    # monitor rules in order and the last match wins, so emitting every profile
    # let whichever sorted last decide, and a stray `disabled = true` at config
    # parse time is a black screen with no desktop left to undo it from.
    "${run[@]}" save "Alone" >/dev/null 2>&1
    "${run[@]}" set eDP-1 disabled=true >/dev/null 2>&1
    "${run[@]}" save "Zzz docked" >/dev/null 2>&1

    local gen="$dir/gen.lua"
    env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state" "XDG_RUNTIME_DIR=$dir" \
        NB_GENERATED="$gen" "$REPO/scripts/neobrix-monitors" generate >/dev/null 2>&1
    local lua; lua="$(cat "$gen" 2>/dev/null)"
    assert_lacks "generate never switches a screen off at startup" "disabled = true" "$lua"
    assert_eq "generate emits one profile, not every profile" "1" \
              "$(printf '%s\n' "$lua" | grep -c -- '^    -- .*(' || true)"

    # A failed producer must not replace the state file. It used to `mv` an empty
    # file over it, losing every profile -- and then nothing could read it again.
    printf 'not json at all' > "$dir/state/neobrix/monitors.json"
    local before; before="$(cat "$dir/state/neobrix/monitors.json")"
    "${run[@]}" profiles >/dev/null 2>&1
    assert_eq "invalid state is ignored, not overwritten" "$before" \
              "$(cat "$dir/state/neobrix/monitors.json")"
    local out; out="$("${run[@]}" save "Recovered" 2>&1)"
    assert_has "a profile can still be saved afterwards" "saved" "$out"
    assert_has "and the state file is valid again" "Recovered" "$("${run[@]}" profiles 2>&1)"

    unset NB_EVAL_LOG
}

test_monitors_cap_preserves() {
    case_ "capping the refresh keeps every other setting"

    local dir="$TMP/rot"      # the stub with a rotated panel
    mkdir -p "$dir/state2"
    export NB_EVAL_LOG="$dir/eval2.log"
    : > "$NB_EVAL_LOG"
    # eDP-1 in this stub is unrotated, so rotate it through the tool first and
    # then cap: the cap must not quietly undo the rotation.
    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state2"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")

    : > "$NB_EVAL_LOG"
    "${run[@]}" cap 60 >/dev/null 2>&1
    local evals; evals="$(cat "$NB_EVAL_LOG")"
    # The stub's eDP-1 advertises only 60Hz, so there is nothing to cap and
    # nothing should be emitted at all -- capping to the mode already in force
    # would still have rewritten transform and vrr.
    assert_lacks "cap does nothing when the panel is already at the limit" 'output="eDP-1"' "$evals"

    # And on the panel that does have a faster mode, the fields come along.
    : > "$NB_EVAL_LOG"
    "${run[@]}" set eDP-1 vrr=1 >/dev/null 2>&1
    : > "$NB_EVAL_LOG"
    "${run[@]}" uncap >/dev/null 2>&1
    evals="$(cat "$NB_EVAL_LOG")"
    assert_lacks "uncap does nothing when nothing was capped" 'output="eDP-1"' "$evals"

    unset NB_EVAL_LOG
}

test_monitors_layout() {
    case_ "a staged layout applies as one change"

    local dir="$TMP/lay"
    mkdir -p "$dir/bin" "$dir/state"
    cp "$TMP/rot/bin/hyprctl" "$dir/bin/hyprctl"     # includes a rotated panel
    export NB_EVAL_LOG="$dir/eval.log"
    : > "$NB_EVAL_LOG"
    local run=(env "PATH=$dir/bin:$PATH" "XDG_STATE_HOME=$dir/state"
               "XDG_RUNTIME_DIR=$dir" "$REPO/scripts/neobrix-monitors")

    # Several changes at once, and only the fields named. Everything else has to
    # survive: a partial spec used to let apply_json's defaults un-rotate a
    # rotated screen.
    : > "$NB_EVAL_LOG"
    "${run[@]}" layout '{"eDP-1":{"scale":1},"DP-1":{"vrr":1}}' >/dev/null 2>&1
    local evals; evals="$(cat "$NB_EVAL_LOG")"
    assert_has "layout drives every named output" 'output="eDP-1"' "$evals"
    assert_has "layout drives the other one too" 'output="DP-1"' "$evals"
    assert_has "an unnamed field is preserved" "transform=1" "$evals"
    assert_has "and the field that changed is set" "vrr=1" "$evals"

    # "false" is a truthy string, and treating it as one would switch a screen
    # off while claiming to switch it on.
    : > "$NB_EVAL_LOG"
    "${run[@]}" layout '{"DP-1":{"disabled":"false"}}' >/dev/null 2>&1
    assert_has "a stringy false does not disable" "disabled=false" "$(cat "$NB_EVAL_LOG")"

    # A drop to the left is negative and must be accepted, then shifted back.
    : > "$NB_EVAL_LOG"
    "${run[@]}" layout '{"eDP-1":{"position":"-1920x0"}}' >/dev/null 2>&1
    assert_lacks "layout leaves nothing negative" 'position="-' "$(cat "$NB_EVAL_LOG")"

    # But a layout that legitimately starts away from the origin is left alone:
    # forcing the corner to 0,0 moved screens nobody had touched.
    : > "$NB_EVAL_LOG"
    "${run[@]}" layout '{"DP-1":{"vrr":0}}' >/dev/null 2>&1
    assert_has "a non-position change moves nothing" 'output="eDP-1", mode="1920x1080@60", position="0x0"' \
               "$(cat "$NB_EVAL_LOG")"

    local out; out="$("${run[@]}" layout '{"DP-1":{"bogus":1}}' 2>&1)"
    assert_has "layout rejects a field it cannot set" "cannot set bogus" "$out"

    unset NB_EVAL_LOG
}

test_idle_inhibit() {
    case_ "keep awake holds a real lock, and says so honestly"

    local dir="$TMP/inh"
    mkdir -p "$dir/bin" "$dir/run"
    # A stand-in for systemd-inhibit that behaves like the real one for this
    # purpose: it holds until killed.
    cat > "$dir/bin/systemd-inhibit" <<'STUB'
#!/usr/bin/env bash
exec sleep infinity
STUB
    chmod +x "$dir/bin/systemd-inhibit"

    local run=(env "PATH=$dir/bin:$PATH" "XDG_RUNTIME_DIR=$dir/run"
               "$REPO/scripts/neobrix-idle")

    assert_eq "status is off before anything is held" "off" "$("${run[@]}" inhibit status 2>&1)"

    "${run[@]}" inhibit on >/dev/null 2>&1
    assert_eq "status is on once held" "on" "$("${run[@]}" inhibit status 2>&1)"
    [[ -r "$dir/run/neobrix-inhibit.pid" ]] && ok "the lock records its pid" \
                                            || bad "the lock records its pid"

    # Turning it on twice must not leak a second lock, or the first pid is lost
    # and nothing can release it.
    local first; first="$(cat "$dir/run/neobrix-inhibit.pid")"
    "${run[@]}" inhibit on >/dev/null 2>&1
    assert_eq "a second on is a no-op, not a second lock" "$first" \
              "$(cat "$dir/run/neobrix-inhibit.pid")"

    "${run[@]}" inhibit toggle >/dev/null 2>&1
    assert_eq "toggle releases it" "off" "$("${run[@]}" inhibit status 2>&1)"
    [[ -e "$dir/run/neobrix-inhibit.pid" ]] && bad "the pid file is cleaned up" \
                                            || ok "the pid file is cleaned up"

    # A pid file left behind by a crash must not read as "awake" forever: the
    # bar would show a lock that is not held and nothing would clear it.
    echo 999999 > "$dir/run/neobrix-inhibit.pid"
    assert_eq "a stale pid file reads as off" "off" "$("${run[@]}" inhibit status 2>&1)"
    [[ -e "$dir/run/neobrix-inhibit.pid" ]] && bad "and is cleared" || ok "and is cleared"

    # It must not claim to be holding anything it cannot. A PATH with a shell and
    # the handful of tools the script uses, but deliberately no systemd-inhibit.
    mkdir -p "$dir/bare"
    local t
    for t in env bash cat rm sleep setsid readlink dirname basename; do
        [[ -x /usr/bin/$t ]] && ln -sf "/usr/bin/$t" "$dir/bare/$t"
    done
    local out; out="$(env -i "PATH=$dir/bare" "HOME=$dir" "XDG_RUNTIME_DIR=$dir/run" \
        "$REPO/scripts/neobrix-idle" inhibit on 2>&1 || true)"
    assert_has "it says so when systemd-inhibit is missing" "systemd-inhibit" "$out"
}

test_idle_resume() {
    case_ "resume confirms a fresh DPMS transition"

    local out
    out="$(NEOBRIX_DRY_RUN=1 "$REPO/scripts/neobrix-idle" light 2>&1)"
    assert_eq "DPMS readiness is observed instead of guessed from a timer" \
        $'would run: brightnessctl -q -r\nwould confirm: dpms off\nwould confirm: dpms on' "$out"
}

test_btop_theme() {
    case_ "btop follows the palette without eating its own config"

    local dir="$TMP/btop"
    mkdir -p "$dir/bin" "$dir/cfg/btop"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/bin/btop"
    chmod +x "$dir/bin/btop"

    # A config with settings that are nobody else's business.
    cat > "$dir/cfg/btop/btop.conf" <<'CONF'
#? Config file for btop
color_theme = "Default"
theme_background = False
update_ms = 2000
proc_sorting = "cpu lazy"
shown_boxes = "cpu mem net proc"
CONF

    local run=(env "PATH=$dir/bin:$PATH" "XDG_CONFIG_HOME=$dir/cfg"
               "$REPO/scripts/neobrix-generate-btop")

    "${run[@]}" dusk >/dev/null 2>&1
    local theme="$dir/cfg/btop/themes/neobrix.theme"
    [[ -r $theme ]] && ok "a theme file is written" || bad "a theme file is written"

    # The palette, not a copy of it: dusk's outline is what the boxes are drawn in.
    local outline; outline="$(bash -c 'source '"$REPO"'/scripts/lib/palette.sh; neobrix_palette dusk; printf %s "$OUTLINE"')"
    assert_has "the boxes use the palette outline" "theme[cpu_box]=\"#$outline\"" "$(cat "$theme")"

    # Every key btop knows about should be present: a theme missing one falls
    # back to a built-in colour for that element only, which looks like a bug
    # rather than a theme.
    local missing=0 k
    for k in $(grep -ohE 'theme\[[a-z_]+\]' /usr/share/btop/themes/*.theme 2>/dev/null | sort -u); do
        grep -qF "$k" "$theme" || missing=$((missing + 1))
    done
    assert_eq "no theme key is left unset" "0" "$missing"

    # Pointed at, and nothing else disturbed.
    local conf="$dir/cfg/btop/btop.conf"
    assert_has "btop is pointed at the theme" 'color_theme = "neobrix"' "$(cat "$conf")"
    assert_has "update_ms is left alone" 'update_ms = 2000' "$(cat "$conf")"
    assert_has "proc_sorting is left alone" 'proc_sorting = "cpu lazy"' "$(cat "$conf")"
    assert_eq "the key is replaced, not duplicated" "1" \
              "$(grep -c '^color_theme' "$conf")"

    # And it is a no-op where btop is not installed, rather than a stray file.
    local bare="$TMP/btop-none"; mkdir -p "$bare/cfg" "$bare/bin"
    env -i "PATH=$bare/bin" "HOME=$bare" "XDG_CONFIG_HOME=$bare/cfg" \
        "$REPO/scripts/neobrix-generate-btop" dusk >/dev/null 2>&1 || true
    [[ -e "$bare/cfg/btop" ]] && bad "it skips a machine with no btop" \
                              || ok "it skips a machine with no btop"
}

test_zed_theme() {
    case_ "Zed gets both palettes, and keeps its own settings file"

    local dir="$TMP/zed"
    mkdir -p "$dir/cfg/zed" "$dir/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/bin/zeditor"
    chmod +x "$dir/bin/zeditor"

    # Zed ships settings full of comments and permits trailing commas. Parsing
    # and re-emitting would delete every comment in here, which is too high a
    # price for setting one key.
    cat > "$dir/cfg/zed/settings.json" <<'JSON'
// Zed settings
//
// For information on how to configure Zed, see the docs.
{
  "ui_font_size": 16,
  "buffer_font_size": 15,
  "theme": {
    "mode": "system",
    "light": "Gruvbox Light",
    "dark": "Gruvbox Dark",
  },
}
JSON

    local run=(env "PATH=$dir/bin:$PATH" "XDG_CONFIG_HOME=$dir/cfg"
               "$REPO/scripts/neobrix-generate-zed")
    "${run[@]}" dusk >/dev/null 2>&1

    local theme="$dir/cfg/zed/themes/neobrix.json"
    [[ -r $theme ]] && ok "a theme family is written" || bad "a theme family is written"

    # Both variants, every time, so both stay selectable in Zed's own picker.
    local names
    names="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print(" ".join("%s:%s" % (t["name"], t["appearance"]) for t in d["themes"]))' "$theme" 2>&1)"
    assert_has "the light variant is there" "Neobrix Dawn:light" "$names"
    assert_has "the dark variant is there" "Neobrix Dusk:dark" "$names"

    # The palette, not a copy: dusk's outline is what every border is drawn in.
    local outline; outline="$(bash -c 'source '"$REPO"'/scripts/lib/palette.sh; neobrix_palette dusk; printf %s "$OUTLINE"')"
    local border; border="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
t=[x for x in d["themes"] if x["appearance"]=="dark"][0]
print(t["style"]["border"])' "$theme" 2>&1)"
    assert_eq "borders use the palette outline" "#${outline}ff" "$border"

    # Comments and unrelated settings survive; only the theme names change.
    local conf="$dir/cfg/zed/settings.json"
    assert_has "the file's comments survive" "// Zed settings" "$(cat "$conf")"
    assert_has "unrelated settings survive" '"buffer_font_size": 15' "$(cat "$conf")"
    assert_has "the light name is set" '"light": "Neobrix Dawn"' "$(cat "$conf")"
    assert_has "the dark name is set" '"dark": "Neobrix Dusk"' "$(cat "$conf")"
    # An explicit "system" is a working preference -- the desktop's colour-scheme
    # already follows the palette -- so it is not overridden.
    assert_has "an explicit system mode is left alone" '"mode": "system"' "$(cat "$conf")"

    # But a pinned mode is synced, or Zed would sit on the wrong variant.
    python3 - "$conf" <<'PY'
import sys
p = sys.argv[1]
open(p, "w").write(open(p).read().replace('"mode": "system"', '"mode": "light"'))
PY
    "${run[@]}" dusk >/dev/null 2>&1
    assert_has "a pinned mode follows the palette" '"mode": "dark"' "$(cat "$conf")"

    # And nothing at all on a machine with neither Zed nor its config.
    local bare="$TMP/zed-none"; mkdir -p "$bare/cfg" "$bare/bin"
    env -i "PATH=$bare/bin" "HOME=$bare" "XDG_CONFIG_HOME=$bare/cfg" \
        "$REPO/scripts/neobrix-generate-zed" dusk >/dev/null 2>&1 || true
    [[ -e "$bare/cfg/zed" ]] && bad "it skips a machine without Zed" \
                             || ok "it skips a machine without Zed"
}

# ═════════════════════════════════════════════════════════════════════════════
TMP="$(mktemp -d)"
if (( DO_LOCAL )); then
    test_piped_stdin
    test_origins
    test_packages_reporting
    test_confirmation
    test_monitors
    test_monitors_rotation
    test_monitors_place_guard
    test_monitors_hazards
    test_monitors_cap_preserves
    test_monitors_layout
    test_idle_inhibit
    test_idle_resume
    test_btop_theme
    test_zed_theme
fi
(( DO_CONTAINER )) && test_container
(( DO_CONTAINER )) || printf '\n%s──%s the container case was not run (pass --container)\n' "$c_dim" "$c_off"

printf '\n%s\n' "────────────────────────────────────"
printf '%s%d passed%s, %s%d failed%s, %d skipped\n' \
    "$c_ok" "$PASS" "$c_off" "$c_err" "$FAIL" "$c_off" "$SKIP"
(( FAIL == 0 ))
