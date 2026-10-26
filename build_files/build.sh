#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages
# Names confirmed against Fedora 44, which ghcr.io/ublue-os/base-main tracks.
# qt6-wayland is not a Fedora package; the Wayland Qt platform is qt6-qtwayland.
# cage hosts Folio's elavo-greeter at login, and nothing else.
# NetworkManager, PipeWire, and WirePlumber are already on base-main.
# kanshi applies the display arrangement System Settings saves. mate-polkit
# is the password prompt for pkexec and polkit D-Bus calls; polkit-gnome is
# not packaged for Fedora 44. accountsservice, polkit, and pciutils (lspci,
# for About's graphics row) are on base-main today; they are listed so that
# stays true. ImageMagick prepares account pictures and ffmpeg shows the
# camera in Change Picture.
# fuse-libs is libfuse.so.2. AppImages built with the older runtime load it to
# mount themselves; newer ones carry their own. squashfs-tools' unsquashfs
# reads an AppImage's name and icon for the Applications folder without
# running it.

dnf5 install -y \
    wlroots \
    libsfdo \
    greetd \
    cage \
    gtk4-layer-shell \
    foot \
    nautilus \
    sushi \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-wlr \
    wl-clipboard \
    cliphist \
    grim \
    slurp \
    swayidle \
    swaybg \
    wlr-randr \
    wlopm \
    bluez \
    brightnessctl \
    power-profiles-daemon \
    flatpak \
    qt6-qtwayland \
    plymouth \
    plymouth-plugin-script \
    curl \
    google-roboto-fonts \
    rsms-inter-fonts \
    jetbrains-mono-fonts \
    adwaita-cursor-theme \
    gnome-keyring \
    gnome-keyring-pam \
    xdg-user-dirs \
    fuse-libs \
    squashfs-tools \
    kanshi \
    mate-polkit \
    accountsservice \
    polkit \
    pciutils \
    ImageMagick \
    ffmpeg

# base-main ships Firefox as an RPM. Elavo's Firefox is the Flathub Flatpak
# (preinstalled below), which updates on its own; with both, the launcher and
# the dock would show two Firefoxes, with separate profiles.
dnf5 remove -y firefox firefox-langpacks
test ! -e /usr/bin/firefox

# No copy in /etc/skel: elavo-session runs labwc --merge-config, so these
# system files stay in effect and ~/.config/labwc holds only user changes.
install -d /etc/xdg/labwc
cp -a /ctx/config/labwc/. /etc/xdg/labwc/
chmod 755 /etc/xdg/labwc/autostart \
    /usr/libexec/elavo-grim-region /usr/libexec/elavo-session \
    /usr/libexec/elavo-user-theme /usr/libexec/elavo-labwc-theme \
    /usr/libexec/elavo-idle \
    /usr/libexec/elavo-wallpaper \
    /usr/libexec/elavo-panel-action /usr/libexec/elavo-power-button
python3 /usr/libexec/elavo-power-button --self-test
test -x /usr/bin/swaybg
test -x /usr/bin/magick
test -x /usr/bin/ffmpeg
test -x /usr/libexec/elavo-wallpaper

# labwc from the mods stage. Nothing in the package set Requires: labwc
# (checked on Fedora 44), so the distro package is not installed. wlroots
# and libsfdo above are the runtime libraries the mods build links.
cp -a /ctx/labwc_files/. /
test -x /usr/bin/labwc

# Folio's panel, dock, Lens, app switcher, text input, and desktop (the folio
# stage in the Containerfile). They are wanted by graphical-session.target,
# which elavo-session.target (started from labwc's autostart) pulls in.
cp -a /ctx/folio_files/. /
test -x /usr/bin/elavo-panel
test -x /usr/bin/elavo-dock
test -x /usr/bin/elavo-lens
test -x /usr/bin/elavo-switcher
test -x /usr/bin/elavo-input
test -x /usr/bin/elavo-desktop
systemctl --global enable elavo-panel.service elavo-dock.service elavo-lens.service elavo-switcher.service elavo-input.service elavo-desktop.service
# The login and lock screen. greetd's config.toml runs it in cage, and
# elavo-idle runs it with --lock. The lock checks passwords with
# /etc/pam.d/elavo-lock. Sessions publish their wallpaper for it through
# the helper the polkit policy names; tmpfiles makes the directory.
test -x /usr/bin/elavo-greeter
test -x /usr/libexec/elavo-greeter-publish
test -f /usr/share/polkit-1/actions/io.elavo.greeter.policy
test -f /usr/lib/tmpfiles.d/elavo-greeter.conf
test -f /etc/pam.d/elavo-lock
grep -q 'elavo-greeter' /etc/greetd/config.toml
# Closing the lid soon after waking must still suspend and lock.
grep -q '^HoldoffTimeoutSec=5$' /usr/lib/systemd/logind.conf.d/40-elavo-lid-holdoff.conf
# The greeter sets cage's output scale on 4K panels with wlr-randr.
command -v wlr-randr >/dev/null
getent passwd greetd >/dev/null

# System Settings (the system-settings stage). The panel's System Settings…
# item and the dock's Dock Settings… open it. Its helper runs updates and
# the lid setting as root through pkexec; the policy names the helper's
# path. Idle locking, password prompts, and the saved display arrangement
# are user services it relies on. kanshi's drop-in keeps it stopped until
# the first arrangement is saved.
cp -a /ctx/system_settings_files/. /
test -x /usr/bin/elavo-system-settings
test -x /usr/libexec/elavo-system-settings-helper
test -f /usr/share/applications/io.elavo.SystemSettings.desktop
test -f /usr/share/polkit-1/actions/io.elavo.SystemSettings.policy
test -x /usr/libexec/polkit-mate-authentication-agent-1
test -f /usr/lib/systemd/user/kanshi.service
test -x /usr/bin/lspci
systemctl --global enable elavo-idle.service elavo-wallpaper.service \
    elavo-polkit-agent.service elavo-power-button.service kanshi.service

# The Applications folder (the applications stage). /Applications is shared
# by every account and lives in /var, which tmpfiles makes: root:wheel 2775
# with a default ACL, plus /var/.Trash so entries can go to the Trash from
# another mount. The root service makes the locked entries the allowlist
# names and an entry for every system Flatpak; each account's service
# installs what that account drops in. Files loads the module that opens
# entries as applications.
cp -a /ctx/applications_files/. /
ln -sfn var/Applications /Applications
test "$(readlink /Applications)" = var/Applications
test -x /usr/bin/elavo-applications
test -x /usr/bin/elavo-applications-ctl
test -x /usr/libexec/elavo-applications-helper
test -f /usr/lib64/nautilus/extensions-4/libelavo-applications.so
test -f /usr/share/polkit-1/actions/io.elavo.Applications.policy
test -f /usr/share/dbus-1/services/io.elavo.Applications.service
grep -q '^d /var/Applications 2775 root wheel' /usr/lib/tmpfiles.d/elavo-applications.conf
grep -q '^d /var/.Trash 1777' /usr/lib/tmpfiles.d/elavo-applications.conf
grep -q elavo-applications/exports /usr/lib/environment.d/60-elavo-applications.conf
test -s /usr/share/elavo-applications/system-applications
test -s /usr/share/elavo-applications/standardized-icons/template.png
test -s /usr/share/elavo-applications/standardized-icons/mask.png
command -v unsquashfs >/dev/null
systemctl --global enable elavo-applications.service
systemctl enable elavo-applications-system.service elavo-applications-system.path

# The Elavo themes from elavo-visuals, pinned. Only the splash follows main.
# The GTK theme covers GTK4, libadwaita, the GTK3 stopgap, labwc's title
# bars, and Firefox's window buttons. The icon theme carries the panel's sun
# and Elavo's app icons, and inherits Adwaita for everything else. The stamp
# tells elavo-user-theme which build each account's copy came from.
visuals_theme_rev=86a4bcb26a08f58c3e0b10fdd11eb62291b86e10
theme_tmp=$(mktemp -d)
curl -fsSL -o "${theme_tmp}/visuals.tar.gz" \
    "https://github.com/elavo-io/elavo-visuals/archive/${visuals_theme_rev}.tar.gz"
tar -xzf "${theme_tmp}/visuals.tar.gz" -C "${theme_tmp}" \
    "elavo-visuals-${visuals_theme_rev}/themes/Elavo" \
    "elavo-visuals-${visuals_theme_rev}/themes/elavo-icons"
install -d /usr/share/themes /usr/share/icons
rm -rf /usr/share/themes/Elavo /usr/share/icons/Elavo
cp -a "${theme_tmp}/elavo-visuals-${visuals_theme_rev}/themes/Elavo" /usr/share/themes/Elavo
cp -a "${theme_tmp}/elavo-visuals-${visuals_theme_rev}/themes/elavo-icons" /usr/share/icons/Elavo
# Dynamic wallpapers and still pictures such as landscape/. A dynamic
# picture may be named light.jpg or blue-light.jpg, and may sit under
# dynamic-wallpapers/. A landscape picture is one file,
# landscape/beach-nenad-radojcic.jpg. The source directory is the artwork
# master and is not installed. The visuals pin must carry assets/wallpaper.
tar -xzf "${theme_tmp}/visuals.tar.gz" -C "${theme_tmp}" \
    "elavo-visuals-${visuals_theme_rev}/assets/wallpaper"
wallpaper_src="${theme_tmp}/elavo-visuals-${visuals_theme_rev}/assets/wallpaper"
install -d /usr/share/backgrounds/elavo
find "${wallpaper_src}" -type d -name source -prune -o -type f ! -name '*source*' -print \
    | while read -r file; do
        rel=${file#"${wallpaper_src}/"}
        install -D -m 0644 "${file}" "/usr/share/backgrounds/elavo/${rel}"
    done
test -n "$(find /usr/share/backgrounds/elavo -name '*-light.jpg' -print -quit)"
test -n "$(find /usr/share/backgrounds/elavo -name '*-dark.jpg' -print -quit)"
# Suggestion pictures for Change Picture. Required: an image without them
# shows an empty Suggestions page on an installed machine. Do not test for
# the directory with `tar | grep -q`. pipefail is on, grep -q closes the
# pipe at the first hit, tar dies with SIGPIPE, and the if is false, so the
# copy is skipped and the build still succeeds.
tar -xzf "${theme_tmp}/visuals.tar.gz" -C "${theme_tmp}" \
    "elavo-visuals-${visuals_theme_rev}/assets/user-images"
install -d /usr/share/elavo/user-images
find "${theme_tmp}/elavo-visuals-${visuals_theme_rev}/assets/user-images" -type f \
    \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) \
    -exec install -m 0644 {} /usr/share/elavo/user-images/ \;
test -n "$(find /usr/share/elavo/user-images -type f -print -quit)"
rm -rf "${theme_tmp}"
gtk-update-icon-cache -f /usr/share/icons/Elavo
test -f /usr/share/icons/Elavo/index.theme
test -f /usr/share/icons/Elavo/symbolic/apps/elavo-sun-symbolic.svg
test -f /usr/share/icons/Elavo/512x512/apps/io.elavo.SystemSettings.png
printf '%s\n' "${visuals_theme_rev}" > /usr/share/themes/Elavo/.elavo-image
test -f /usr/share/themes/Elavo/gtk-4.0/gtk.css
test -f /usr/share/themes/Elavo/gtk-4.0/libadwaita.css
test -f /usr/share/themes/Elavo/gtk-3.0/gtk.css
test -f /usr/share/themes/Elavo/openbox-3/themerc
test -f /usr/share/themes/Elavo/openbox-3/themerc-dark
test -e /usr/share/themes/Elavo/openbox-3/close-active.png
test -x /usr/share/themes/Elavo/firefox/install.sh
# The theme names Roboto; without it GTK falls back to another family.
test -f /usr/share/fonts/google-roboto/Roboto-Regular.ttf
systemctl --global enable elavo-user-theme.service elavo-labwc-theme.service
# elavo-user-theme themes the profiles that exist at login. This themes the
# ones Firefox creates later, including the Flatpak's first after its
# preinstall finishes.
systemctl --global enable elavo-firefox-theme.path

# Flatpak finds ~/Downloads (xdg-download) through ~/.config/user-dirs.dirs.
# Without that file a Flatpak browser saves into a Downloads folder inside its
# sandbox, which is lost when it quits. The package's autostart entry is
# skipped under systemd; its user unit runs before graphical-session-pre.target,
# which elavo-session.target wants.
test -f /usr/lib/systemd/user/xdg-user-dirs.service
systemctl --global enable xdg-user-dirs.service

# Unlock the login keyring with the greetd password. Append after the last
# line of each group so auto_start runs after pam_systemd. The package file
# is the Fedora stack; these lines are only added when they are missing.
patch_pam() {
    local file="$1"
    local group="$2"
    local line="$3"
    [[ -f "${file}" ]] || return 0
    grep -qF "${line}" "${file}" && return 0
    awk -v group="${group}" -v line="${line}" '
        $1 == group { last = NR }
        { lines[NR] = $0 }
        END {
            if (last == 0) {
                for (i = 1; i <= NR; i++) print lines[i]
                print line
                exit
            }
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == last) print line
            }
        }
    ' "${file}" > "${file}.elavo"
    mv "${file}.elavo" "${file}"
}
test -f /etc/pam.d/greetd
test -f /etc/pam.d/passwd
test -x /usr/bin/gnome-keyring-daemon
test -e /usr/lib64/security/pam_gnome_keyring.so
patch_pam /etc/pam.d/greetd auth "auth        optional      pam_gnome_keyring.so"
patch_pam /etc/pam.d/greetd session "session     optional      pam_gnome_keyring.so auto_start"
patch_pam /etc/pam.d/passwd password "password    optional      pam_gnome_keyring.so"

# Splash from elavo-visuals main, bootscreen/elavo-new/elavo-boot. The images
# are not stored in this repo. The image build takes whatever main is when
# the build runs. The theme's .plymouth file names this install path.
visuals_tmp=$(mktemp -d)
curl -fsSL -o "${visuals_tmp}/visuals.tar.gz" \
    "https://github.com/elavo-io/elavo-visuals/archive/refs/heads/main.tar.gz"
tar -xzf "${visuals_tmp}/visuals.tar.gz" -C "${visuals_tmp}"
rm -rf /usr/share/plymouth/themes/elavo-boot
install -d /usr/share/plymouth/themes/elavo-boot
cp -a "${visuals_tmp}/elavo-visuals-main/bootscreen/elavo-new/elavo-boot/." \
    /usr/share/plymouth/themes/elavo-boot/
rm -rf "${visuals_tmp}"
test -f /usr/share/plymouth/themes/elavo-boot/elavo-boot.plymouth
test -f /usr/share/plymouth/themes/elavo-boot/elavo-boot.script
test -f /usr/share/plymouth/themes/elavo-boot/logo.png

plymouth-set-default-theme elavo-boot
# Same rebuild Universal Blue uses in ublue-os/main build_files/initramfs.sh.
# --add ostree is required. Without it the theme is in the initramfs and
# ostree-prepare-root is not, so boot reaches the splash and then emergency
# mode. -R is not used: it writes /boot, which this image does not boot from.
# DRACUT_NO_XATTR avoids cp failing on security.selinux inside the container.
# dracut still prints errors about /dev/log and /root here. /root is a symlink
# to /var/roothome, which does not exist during the image build. Those lines
# do not fail this command.
export DRACUT_NO_XATTR=1
kernel_version="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
/usr/bin/dracut --no-hostonly --kver "${kernel_version}" --reproducible --add ostree -f \
    "/lib/modules/${kernel_version}/initramfs.img"
chmod 0600 "/lib/modules/${kernel_version}/initramfs.img"

install -d /etc/dconf/profile /etc/dconf/db/local.d
if [[ ! -f /etc/dconf/profile/user ]]; then
    printf '%s\n' 'user-db:user' 'system-db:local' > /etc/dconf/profile/user
elif ! grep -q '^system-db:local$' /etc/dconf/profile/user; then
    printf '%s\n' 'system-db:local' >> /etc/dconf/profile/user
fi
dconf update

# Flathub is shipped in /etc/flatpak/remotes.d. Firefox is a preinstall file
# under /usr/share/flatpak/preinstall.d. elavo-flatpak-preinstall.service
# applies it after the network is up, because a system Flatpak install lives
# in /var and bootc does not ship /var. It runs at boot, and the
# NetworkManager dispatcher script runs it again when a connection comes up,
# for machines whose Wi-Fi connects only after login.
chmod 755 /usr/lib/NetworkManager/dispatcher.d/90-elavo-flatpak-preinstall

systemctl enable greetd.service elavo-flatpak-preinstall.service
systemctl set-default graphical.target

# Automatic updates follow System Settings' two switches, saved in
# /etc/elavo/updates.conf. elavo-system-update.timer, from System Settings,
# reads them. The base image's rpm-ostreed-automatic.timer staged updates
# with no setting, so it is turned off. Disabling it only changes new
# installs, where /etc comes from the image. The drop-in also stops it on
# machines installed before, whose /etc keeps the timer enabled.
systemctl enable elavo-system-update.timer
systemctl disable rpm-ostreed-automatic.timer
install -d /usr/lib/systemd/system/rpm-ostreed-automatic.service.d
printf '%s\n' '[Service]' 'ExecCondition=/bin/false' \
    > /usr/lib/systemd/system/rpm-ostreed-automatic.service.d/90-elavo-off.conf
test -f /usr/lib/systemd/system/elavo-system-update.service
test -L /etc/systemd/system/timers.target.wants/elavo-system-update.timer
test ! -e /etc/systemd/system/timers.target.wants/rpm-ostreed-automatic.timer

# Elavo's own version. GRUB's menu title is PRETTY_NAME, and About reads
# VERSION, so both show this. VERSION_ID stays Fedora's major, read from the
# base image: the ISO builder and grub2-switch-to-blscfg use it, and About's
# Fedora Version row shows it. ID stays fedora: quay.io/centos-bootc/bootc-image-builder:latest
# has no fedora-44 definition and no --override-distro-def flag, and an ID of
# elavo makes the ISO build look for a definition that image does not ship.
# grub2-switch-to-blscfg derives EFIDIR from ID, so leaving ID=fedora also
# keeps the signed bootloader in EFI/fedora.
# Edit /usr/lib/os-release, not the /etc/os-release symlink. sed -i on the
# symlink would replace it with a regular file.
osrel=/usr/lib/os-release
test -f "${osrel}"
test -L /etc/os-release
elavo_version=0.3.1.2
version_id=$(sed -n 's/^VERSION_ID=//p' "${osrel}" | tr -d "\"'")
[[ "${version_id}" =~ ^[0-9]+$ ]]
kept_version_id=$(sed -n 's/^VERSION_ID=//p' "${osrel}")
kept_platform_id=$(sed -n 's/^PLATFORM_ID=//p' "${osrel}")
kept_cpe=$(sed -n 's/^CPE_NAME=//p' "${osrel}")
kept_codename=$(sed -n 's/^VERSION_CODENAME=//p' "${osrel}")
kept_bz=$(sed -n 's/^REDHAT_BUGZILLA_PRODUCT_VERSION=//p' "${osrel}")
kept_support=$(sed -n 's/^REDHAT_SUPPORT_PRODUCT_VERSION=//p' "${osrel}")
kept_ostree=$(sed -n 's/^OSTREE_VERSION=//p' "${osrel}")
kept_id=$(sed -n 's/^ID=//p' "${osrel}")
test "${kept_id}" = "fedora"

os_release_set() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "${osrel}"; then
        awk -v key="${key}" -v value="${value}" '
            index($0, key "=") == 1 { print key "=" value; next }
            { print }
        ' "${osrel}" > "${osrel}.elavo"
        mv "${osrel}.elavo" "${osrel}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${osrel}"
    fi
}

# The public site URL is not recorded yet. These point at the image repository
# until that URL exists.
os_release_set NAME '"Elavo"'
os_release_set PRETTY_NAME "\"Elavo ${elavo_version}\""
os_release_set VERSION "\"${elavo_version}\""
os_release_set DEFAULT_HOSTNAME '"elavo"'
os_release_set LOGO elavo-sun-symbolic
os_release_set HOME_URL '"https://github.com/elavo-io/elavo"'
os_release_set DOCUMENTATION_URL '"https://github.com/elavo-io/elavo"'
os_release_set SUPPORT_URL '"https://github.com/elavo-io/elavo/issues"'
os_release_set BUG_REPORT_URL '"https://github.com/elavo-io/elavo/issues"'

test "$(sed -n 's/^VERSION_ID=//p' "${osrel}")" = "${kept_version_id}"
test "$(sed -n 's/^PLATFORM_ID=//p' "${osrel}")" = "${kept_platform_id}"
test "$(sed -n 's/^CPE_NAME=//p' "${osrel}")" = "${kept_cpe}"
test "$(sed -n 's/^VERSION_CODENAME=//p' "${osrel}")" = "${kept_codename}"
test "$(sed -n 's/^REDHAT_BUGZILLA_PRODUCT_VERSION=//p' "${osrel}")" = "${kept_bz}"
test "$(sed -n 's/^REDHAT_SUPPORT_PRODUCT_VERSION=//p' "${osrel}")" = "${kept_support}"
test "$(sed -n 's/^OSTREE_VERSION=//p' "${osrel}")" = "${kept_ostree}"
test "$(sed -n 's/^ID=//p' "${osrel}")" = "${kept_id}"
grep -q "^PRETTY_NAME=\"Elavo ${elavo_version}\"\$" "${osrel}"
grep -q '^NAME="Elavo"$' "${osrel}"
grep -q "^VERSION=\"${elavo_version}\"\$" "${osrel}"
test -L /etc/os-release

test -f /usr/lib/fedora-release
printf 'Elavo release %s\n' "${elavo_version}" > /usr/lib/fedora-release

# The image repository commit. Software Update compares this with the
# revision label on the update and lists the commits in between.
if [[ -n "${ELAVO_GIT_REVISION:-}" ]]; then
    printf '%s\n' "${ELAVO_GIT_REVISION}" > /usr/lib/elavo-image-revision
fi
