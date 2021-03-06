#!/bin/bash
set -e

systemctl disable apt-daily.service
systemctl disable apt-daily.timer

apt-get update -y
apt-get upgrade -y

apt-get install -y \
        build-essential  \
        git \
        wget \
        dkms \
        apt-transport-https \
        ca-certificates \
        python-apt \
        python-pip \
        curl \
        netcat \
        ngrep \
        dstat \
        nmon \
        iptraf \
        iftop \
        iotop \
        atop \
        mtr \
        tree \
        unzip \
        sysdig \
        git \
        htop \
        jq \
        ntp \
        logrotate \
        dhcping \
        dhcpdump \
        tmpreaper

mv /etc/tmpreaper.conf /etc/tmpreaper.conf.tmp
grep -v SHOW_WARNING > /etc/tmpreaper.conf < /etc/tmpreaper.conf.tmp
rm /etc/tmpreaper.conf.tmp
echo 'TMPREAPER_TIME=1d' >> /etc/tmpreaper.conf

pip install awscli

apt-get dist-upgrade -y
