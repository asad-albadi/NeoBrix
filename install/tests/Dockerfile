# Arch with systemd as PID 1, and the Neobrix package set installed *except* a
# handful of small ones. That exception is the point: packages.sh must find
# something genuinely absent, so the run reaches a real `sudo pacman -S` with a
# real confirmation to read — which is the line that used to eat the installer.
#
# systemd really has to be PID 1. deploy.sh ends in `systemctl --user enable`,
# and with no user manager that fails, the run stops before its last step, and
# this test could no longer tell that apart from the bug it is looking for.
FROM archlinux:base

# The list comes from the script under test, so adding a package to packages.sh
# invalidates this layer rather than quietly testing yesterday's list.
COPY install/packages.sh /tmp/packages.sh

# Held back on purpose: small, quick to download, and every one of them is
# REQUIRED, so the run cannot dismiss them as optional.
ENV HOLDBACK="brightnessctl hyprpicker satty cliphist"

RUN pacman -Syu --noconfirm --needed git sudo which \
 && keep="$(bash /tmp/packages.sh --list | grep -vxF -f <(printf '%s\n' $HOLDBACK) \
            | grep -vxE 'zen-browser-bin|cursor-bin')" \
 && pacman -S --noconfirm --needed $keep \
 && pacman -Scc --noconfirm \
 && for p in $HOLDBACK; do pacman -Qq "$p" >/dev/null 2>&1 && { echo "held-back package $p is installed; the test would prove nothing" >&2; exit 1; }; done; true

RUN useradd -m -u 1000 tester \
 && echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester \
 && systemctl mask systemd-firstboot getty@tty1 systemd-udevd systemd-udev-trigger

COPY install/tests/container-run.sh /usr/local/bin/container-run
RUN chmod +x /usr/local/bin/container-run

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
