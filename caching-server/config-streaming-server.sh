#!/bin/sh
echo "Fix hosts file, not sure why host is not set by cloud-init..."
sed -i "1s/^/127.0.0.1 `sudo -Hu ubuntu hostname`\n/" /etc/hosts

echo "Hosts file updated, hostname: `hostname`"

IS_NETWORKING_ACTIVE=false
[ "`systemctl is-active networking`" != "active" ] || IS_NETWORKING_ACTIVE=true
while ! $IS_NETWORKING_ACTIVE; do
    echo "networking.service is not active, sleep...."
    sleep 30
    [ "`systemctl is-active networking`" != "active" ] || IS_NETWORKING_ACTIVE=true
done

echo "networking.service is now active, continue configuration."
echo "Change default user password and turn on password ssh auth."
# set default fedora user password
usermod --password $(openssl passwd -1 squ\!d) ubuntu
# turn on password auth
sed -i "s/^.*PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart sshd


# install gnome and have it come up on boot.
echo "Update all packages"
apt-get update
apt-get upgrade
echo "Install and configure squid."
apt-get install -y squid
echo "Stopping squid"
systemctl stop squid
echo "Backing up original squid.conf."
cp /etc/squid/squid.conf /etc/squid/squid.conf.orig
echo "Clear existing squid.conf"
sed -i '1,$d' /etc/squid/squid.conf
echo "Writing new squid.conf"
cat > /etc/squid/squid.conf <<EOF
coredump_dir /var/spool/squid
# dp - set to 20 mb, if we only care about big stuff
# minimum_object_size 20971520
# dp - start with 1mb
minimum_object_size 1048576
# dp - set max very high (500mb) just for testing, need to turn down
maximum_object_size 524288000
# dp - set to 5G (5000) and 16 subdirectories and 256 directories under sub-directories
# the 16 and 256 are defaults. ufs is old standard and only built in directory type.
# cache_dir ufs /var/spool/squid 5000 16 256
# dp - use one bucket to keep it simple when demoing,
# can just list single directory and see newly cached items
cache_dir ufs /var/spool/squid 5000 1 1
acl manager proto cache_object
acl SSL_ports port 443
acl SSL_ports port 3128
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT
acl SSL method CONNECT
http_access deny !Safe_ports
acl ban_domains dstdomain "/etc/squid/ban_domains.txt"
acl allow_domains dstdomain "/etc/squid/allow_domains.txt"
http_access deny ban_domains
http_access allow allow_domains
http_access deny manager
http_access allow localhost manager
http_access deny to_localhost
http_access deny all
http_port 3128 accel vhost allow-direct
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern .png            120     50%     86400 ignore-reload
# This forces all content to be cached for 2 minutes at least:
refresh_pattern .               120       20%     4320
EOF

cat > /etc/squid/ban_domains.txt <<EOFBAD
ubuntu@squid-xenial-1:~$ sudo cat /etc/squid/ban_domains.txt
www.360zuqiu.com
360
yabo03.in
EOFBAD

cat > /etc/squid/allow_domains.txt <<EOFALLOW
ubuntu@squid-xenial-1:~$ sudo cat /etc/squid/ban_domains.txt
commondatastorage.googleapis.com
detectportal.firefox.com
mozilla.github.io
EOFALLOW
systemctl start squid

echo "Done, squid http caching should be enabled..."
