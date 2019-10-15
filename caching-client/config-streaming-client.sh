#!/bin/sh
IS_NM_ACTIVE=false
[ "`sudo systemctl is-active NetworkManager`" != "active" ] || IS_NM_ACTIVE=true
while ! $IS_NM_ACTIVE; do
    echo "NetworkManager is not active, sleep...."
    sleep 30
    [ "`sudo systemctl is-active NetworkManager`" != "active" ] || IS_NM_ACTIVE=true
done

echo "NetworkManager is now active, continue configuration."
echo "Change default user password and turn on password ssh auth."
# set default fedora user password
sudo echo "f3d0r@!" | sudo passwd --stdin fedora
# turn on password auth
sudo sed -i "s/^.*PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo systemctl restart sshd

sleep 30
# install gnome and have it come up on boot.
echo "Update all packages"
sudo dnf upgrade --refresh --allowerasing
sudo dnf update -y
echo "Install gnome and set it as default graphical target."
sudo dnf group install -y gnome-desktop
sudo dnf install -y gdm
sudo dnf install -y vino
sudo systemctl enable gdm.service
sudo systemctl set-default graphical.target
sudo dnf install -y firefox

# enble video streaming in firefox and install proper codecs
#  see:  https://medium.com/@jm.duarte/how-to-install-h-264-mpeg-4-avc-on-fedora-82a296e7bc0f
echo "Install required codecs and firefox plugin for streaming in browser."
sudo dnf config-manager -y --set-enabled fedora-cisco-openh264
sudo dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf groupupdate -y core
sudo dnf groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
sudo dnf groupupdate -y sound-and-video
sudo dnf install -y x264
sudo dnf install -y dbus-x11
# update everything and clean packages to clear disk space
echo "All packages installed, final update and cleanup next."
sudo dnf update -y
sudo dnf clean -y all

# think there may be race condition when calling gsettings, let's wait a minute.
sleep 60
echo "Environment variable output below"
echo `env`
# if export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
# is not set we need to set before calling gsettings
echo "Setting proxy gnome attributes for firefox etc."
DISPLAY=:0 gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '::1']"
DISPLAY=:0 gsettings set org.gnome.system.proxy use-same-proxy true
DISPLAY=:0 gsettings set org.gnome.system.proxy mode 'none'
DISPLAY=:0 gsettings set org.gnome.system.proxy autoconfig-url ''
DISPLAY=:0 gsettings set org.gnome.system.proxy.http use-authentication false
DISPLAY=:0 gsettings set org.gnome.system.proxy.http enabled false
DISPLAY=:0 gsettings set org.gnome.system.proxy.http authentication-password ''
DISPLAY=:0 gsettings set org.gnome.system.proxy.http port 3218
DISPLAY=:0 gsettings set org.gnome.system.proxy.http host '139.178.84.190'
DISPLAY=:0 gsettings set org.gnome.system.proxy.http authentication-user ''
DISPLAY=:0 gsettings set org.gnome.system.proxy.https port 3218
DISPLAY=:0 gsettings set org.gnome.system.proxy.https host '139.178.84.190'
DISPLAY=:0 gsettings set org.gnome.system.proxy.ftp port 3218
DISPLAY=:0 gsettings set org.gnome.system.proxy.ftp host '139.178.84.190'
DISPLAY=:0 gsettings set org.gnome.system.proxy.socks port 3218
DISPLAY=:0 gsettings set org.gnome.system.proxy.socks host '139.178.84.190'

echo "Setting gnome attributes for vnc access and screen lock timeout."
DISPLAY=:0 gsettings set org.gnome.Vino vnc-password $(echo -n f3d0r@! | base64)
DISPLAY=:0 gsettings set org.gnome.Vino prompt-enabled false
DISPLAY=:0 gsettings set org.gnome.Vino authentication-methods "['vnc']"
DISPLAY=:0 gsettings set org.gnome.Vino require-encryption false
DISPLAY=:0 gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
DISPLAY=:0 gsettings set org.gnome.desktop.interface gtk-im-module 'gtk-im-context-simple'
DISPLAY=:0 gsettings set org.gnome.desktop.remote-desktop.vnc encryption "['none']"

# set screen lock to 60 min
DISPLAY=:0 gsettings set org.gnome.desktop.screensaver lock-delay "uint32 3600"
echo "Done, reboot vm to boot to gnome."
