#!/usr/bin/env bash
# Runs inside the test container, as tester. Performs the install the README
# leads with — piped into bash — against a local clone of the working tree, so
# what is under test is the tree on disk and not the last commit.
#
# Every argument is forwarded past `bash -s --`, which is how the piped form
# takes flags at all. Called twice by run.sh: once bare, to prove that an
# unattended run refuses to install, and once with --yes.
set -uo pipefail

SRC=/src                     # the working tree, read-only
BARE=/tmp/neobrix.git

# A clone bootstrap.sh can fetch from. The working tree is copied and committed
# first: bootstrap.sh itself is piped from $SRC, but the children it runs
# (packages.sh, deploy.sh) come out of the clone, and testing yesterday's
# children against today's bootstrap is how a fix looks like it works.
if [[ ! -d $BARE ]]; then
    cp -a "$SRC" /tmp/wt
    git -C /tmp/wt add -A
    git -C /tmp/wt -c user.email=t@t -c user.name=t commit -qm "working tree under test" || true
    git clone -q --bare /tmp/wt "$BARE"
fi

echo "── the piped form, no terminal, packages genuinely absent: bash -s -- $* ──"
# No `-t` anywhere, so there is no terminal: this is the CI shape of the run.
cat "$SRC/install/bootstrap.sh" | NEOBRIX_REPO="$BARE" bash -s -- "$@"
ec=$?
echo "── bootstrap exit: $ec ──"
exit $ec
