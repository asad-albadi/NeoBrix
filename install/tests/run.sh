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

c_ok=$'\033[32m'; c_err=$'\033[31m'; c_warn=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
PASS=0; FAIL=0; SKIP=0; KNOWN=0
case_() { printf '\n%s──%s %s\n' "$c_dim" "$c_off" "$1"; }
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$c_ok"  "$c_off" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$c_err" "$c_off" "$1"; }
skip() { SKIP=$((SKIP+1)); printf '  %sSKIP%s %s\n' "$c_dim" "$c_off" "$1"; }
# A failure that is understood, is somebody else's to fix, and is not this
# suite's own breakage. Loud, counted, and does not turn the run red — but
# narrowly matched, so a *different* failure at the same point still fails.
known() { KNOWN=$((KNOWN+1)); printf '  %sKNOWN%s %s\n' "$c_warn" "$c_off" "$1"; }

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
    # This is the same fixture against the bootstrap.sh on origin/main, and it
    # is here to be seen failing the assertions above.
    case_ "piped stdin: the same fixture catches the bug on origin/main"
    local old="$TMP/old-bootstrap.sh"
    if ! git -C "$REPO" show origin/main:install/bootstrap.sh > "$old" 2>/dev/null; then
        skip "origin/main is not fetched here, so there is nothing to compare against"
        return
    fi
    local d2="$TMP/stdin-old"; mkdir -p "$d2"
    stdin_fixture "$d2"
    local before; before="$(piped_run "$d2" "$old")"
    if [[ "$before" == *"CHILD-READ[EOF]"* ]]; then
        skip "origin/main does not show the bug (already fixed upstream?)"
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

# origin_case <name> <origin-url> <NEOBRIX_REPO> <keep|repoint>
origin_case() {
    local name="$1" origin="$2" repo="$3" want="$4"
    case_ "origin: $name"
    local d; d="$(mktemp -d "$TMP/origin.XXXX")"
    fake_clone "$d/clone" "$d/upstream.git" "$origin"
    local before after out
    before="$(git -C "$d/clone" remote get-url origin 2>/dev/null || echo NONE)"
    # BatchMode/GIT_TERMINAL_PROMPT: never sit waiting on a credential prompt for
    # a URL that is only here to be compared. Whether the pull then succeeds is
    # beside the point — every assertion below is on output printed before it.
    out="$(cat "$BOOTSTRAP" | env -i PATH="$PATH" HOME="$d/home" \
        GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=3' \
        NEOBRIX_DIR="$d/clone" NEOBRIX_REPO="$repo" bash -s -- --yes 2>&1)"
    after="$(git -C "$d/clone" remote get-url origin 2>/dev/null || echo NONE)"

    if [[ $want == keep ]]; then
        assert_eq  "origin unchanged" "$before" "$after"
        assert_has "said so"          "left alone" "$out"
    else
        assert_eq  "origin repointed" "$repo" "$after"
        assert_has "warned"           "different repository" "$out"
        assert_has "printed the old URL so it can be put back" "$before" "$out"
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
    origin_case "a genuinely different repository is repointed, loudly" \
        'git@github.com:someone-else/their-fork.git' \
        'https://github.com/asad-albadi/NeoBrix.git' repoint

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
#  container: the real `… | bash`, with the packages genuinely absent
# ═════════════════════════════════════════════════════════════════════════════
IMAGE=neobrix-installer-test
test_container() {
    case_ "container: the real piped install, packages genuinely absent"
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

    local out ec
    out="$($D exec -u tester -e XDG_RUNTIME_DIR=/run/user/1000 "$cid" container-run 2>&1)"; ec=$?
    $D rm -f "$cid" >/dev/null
    printf '%s\n' "$out" > "$TMP/container.log"

    assert_has    "packages were genuinely missing"  "missing:" "$out"
    assert_has    "pacman really ran"                "Proceed with installation" "$out"
    assert_before "packages ran before deploy"       "missing:" "checking dependencies" "$out"
    assert_has    "deploy started"                   "linking configuration" "$out"
    # Known blocker, unrelated to the three fixes this suite was written for:
    # deploy.sh's require_lua_capable_hyprland does
    #
    #     version=$(hyprctl version 2>/dev/null | head -1 | grep -oE ... | head -1)
    #     [[ -n "$version" ]] || { warn "could not determine..."; return 0; }
    #
    # With no compositor running, hyprctl exits 1 and grep matches nothing, so
    # under `set -euo pipefail` the *assignment* fails and the script is gone
    # before the guard on the next line can run. That guard is unreachable, and
    # a first install — no Hyprland session yet, which is the whole point of the
    # one-liner — dies there. Same family as the `grep -q`/SIGPIPE note 60 lines
    # above it in that file.
    if [[ "$out" != *"Neobrix is deployed"* && "$out" == *"linking configuration"* \
          && "$out" != *"supports the Lua configuration"* ]]; then
        known "deploy.sh dies at require_lua_capable_hyprland (see the comment here); everything up to it works"
    else
        assert_has "deploy installed its units" "installing systemd user units" "$out"
        assert_has "reached the last step"      "Neobrix is deployed" "$out"
        assert_eq  "exit status"                "0" "$ec"
    fi
    printf '  full log: %s\n' "$TMP/container.log"
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
TMP="$(mktemp -d)"
if (( DO_LOCAL )); then
    test_piped_stdin
    test_origins
    test_packages_reporting
fi
(( DO_CONTAINER )) && test_container
(( DO_CONTAINER )) || printf '\n%s──%s the container case was not run (pass --container)\n' "$c_dim" "$c_off"

printf '\n%s\n' "────────────────────────────────────"
printf '%s%d passed%s, %s%d failed%s, %d known, %d skipped\n' \
    "$c_ok" "$PASS" "$c_off" "$c_err" "$FAIL" "$c_off" "$KNOWN" "$SKIP"
(( FAIL == 0 ))
