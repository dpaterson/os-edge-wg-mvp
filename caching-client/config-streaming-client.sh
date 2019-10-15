#!/bin/sh
IS_NM_ACTIVE=false
[ "`systemctl is-active NetworkManager`" != "active" ] || IS_NM_ACTIVE=true
while ! $IS_NM_ACTIVE; do
    echo "NetworkManager is not active, sleep...."
    sleep 30
    [ "`systemctl is-active NetworkManager`" != "active" ] || IS_NM_ACTIVE=true
done

echo "NetworkManager is now active, continue configuration."
echo "Change default user password and turn on password ssh auth."
# set default fedora user password
echo "f3d0r@!" | passwd --stdin fedora
# turn on password auth
sed -i "s/^.*PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart sshd

sleep 30
# install gnome and have it come up on boot.
echo "Update all packages"
dnf upgrade --refresh --allowerasing
dnf update -y
echo "Install gnome and set it as default graphical target."
dnf group install -y gnome-desktop
dnf install -y gdm
dnf install -y vino
systemctl enable gdm.service
systemctl set-default graphical.target
dnf install -y firefox

# enble video streaming in firefox and install proper codecs
#  see:  https://medium.com/@jm.duarte/how-to-install-h-264-mpeg-4-avc-on-fedora-82a296e7bc0f
echo "Install required codecs and firefox plugin for streaming in browser."
dnf config-manager -y --set-enabled fedora-cisco-openh264
dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf groupupdate -y core
dnf groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
dnf groupupdate -y sound-and-video
dnf install -y x264
dnf install -y dbus-x11
# update everything and clean packages to clear disk space
echo "All packages installed, final update and cleanup next."
dnf update -y
dnf clean -y all

# think there may be race condition when calling gsettings, let's wait a minute.
# sleep 60
echo "Environment variable output below"
echo `env`
# if export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
# is not set we need to set before calling gsettings
echo "Setting proxy gnome attributes for firefox etc."
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '::1']"
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy use-same-proxy true
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy mode 'manual'
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy autoconfig-url ''
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http use-authentication false
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http enabled false
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http authentication-password ''
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http port 3128
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http host '139.178.84.190'
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.http authentication-user ''
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.https port 3128
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.https host '139.178.84.190'
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.ftp port 3128
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.ftp host '139.178.84.190'
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.socks port 3128
sudo -Hu fedora dbus-launch gsettings set org.gnome.system.proxy.socks host '139.178.84.190'

echo "Setting gnome attributes for vnc access and screen lock timeout."
sudo -Hu fedora dbus-launch gsettings set org.gnome.Vino vnc-password $(echo -n f3d0r@! | base64)
sudo -Hu fedora dbus-launch gsettings set org.gnome.Vino prompt-enabled false
sudo -Hu fedora dbus-launch gsettings set org.gnome.Vino authentication-methods "['vnc']"
sudo -Hu fedora dbus-launch gsettings set org.gnome.Vino require-encryption false
sudo -Hu fedora dbus-launch gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
sudo -Hu fedora dbus-launch gsettings set org.gnome.desktop.interface gtk-im-module 'gtk-im-context-simple'
sudo -Hu fedora dbus-launch gsettings set org.gnome.desktop.remote-desktop.vnc encryption "['none']"

# set screen lock to 60 min
sudo -Hu fedora dbus-launch gsettings set org.gnome.desktop.screensaver lock-delay "uint32 3600"
echo "Done, reboot vm to boot to gnome."
