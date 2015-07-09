#!/bin/bash

# Take input for username and password
read -p "Transmission username: " uname
read -p "$uname's Password: " passw

# Update system and install required packages
yum -y update
yum -y install gcc gcc-c++ m4 xz make automake curl-devel intltool libtool gettext openssl-devel perl-Time-HiRes wget

#Create UNIX user and directories for transmission
encrypt_pass=$(perl -e 'print crypt($ARGV[0], "password")' $passw)
useradd -m -p $encrypt_pass $uname
mkdir -p /home/$uname/Downloads/
chown -R $uname.$uname /home/$uname/Downloads/
chmod g+w /home/$uname/Downloads/

# Install the firewall (CSF)
cd /usr/local/src
wget http://configserver.com/free/csf.tgz
tar xzf csf.tgz
cd csf
./install.generic.sh
cd /etc/csf
sed -i 's/^TESTING =.*/TESTING = "0"/' csf.conf
sed -i 's/^TCP_IN =.*/TCP_IN = "22,80,9091,10000,51413"/' csf.conf
sed -i 's/^TCP_OUT =.*/TCP_OUT = "1:65535"/' csf.conf
sed -i 's/^UDP_IN =.*/UDP_IN = "51413"/' csf.conf
sed -i 's/^UDP_OUT =.*/UDP_OUT = "1:65535"/' csf.conf
csf -r

# Install libevent
cd /usr/local/src
wget https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz
tar xzf libevent-2.0.22-stable.tar.gz
cd libevent-2.0.22-stable
./configure --prefix=/usr
make
make install

# Where are those libevent libraries?
echo /usr/lib > /etc/ld.so.conf.d/libevent-i386.conf
echo /usr/lib > /etc/ld.so.conf.d/libevent-x86_64.conf
ldconfig
export PKG_CONFIG_PATH=/usr/lib/pkgconfig

# Install transmission
cd /usr/local/src
wget https://transmission.cachefly.net/transmission-2.84.tar.xz
tar xvf transmission-2.84.tar.xz
cd transmission-2.84
./configure --prefix=/usr
make
make install

# Set up init script for transmission-daemon
cd /etc/init.d
wget -O transmissiond https://gist.githubusercontent.com/elijahpaul/b98f39011bce48c0750d/raw/0812b6d949b01922f7060f4d4d15dc5e70c5d5a5/transmission-daemon
sed -i "s%TRANSMISSION_HOME=/home/transmission%TRANSMISSION_HOME=/home/$uname%" transmissiond
sed -i 's%DAEMON_USER="transmission"%DAEMON_USER="placeholder123"%' transmissiond
sed -i "s%placeholder123%$uname%" transmissiond
chmod 755 /etc/init.d/transmissiond
chkconfig --add transmissiond
chkconfig --level 345 transmissiond on

# Edit the transmission configuration
service transmissiond start
service transmissiond stop
sleep 3
cd /home/$uname/.config/transmission
sed -i 's/^.*rpc-whitelist-enabled.*/"rpc-whitelist-enabled": false,/' settings.json
sed -i 's/^.*rpc-authentication-required.*/"rpc-authentication-required": true,/' settings.json
sed -i 's/^.*rpc-username.*/"rpc-username": "placeholder123",/' settings.json
sed -i 's/^.*rpc-password.*/"rpc-password": "placeholder321",/' settings.json
sed -i "s/placeholder123/$uname/" settings.json
sed -i "s/placeholder321/$passw/" settings.json

# Yay!!!
service transmissiond start
