#!/bin/bash

set -o errexit

source /opt/venv/bin/activate
pip install websocket_client -i https://mirrors.aliyun.com/pypi/simple/
deactivate

apt-get install -y git g++ make psmisc binutils autoconf automake autotools-dev libtool pkg-config \
  zlib1g-dev libcunit1-dev libssl-dev libxml2-dev libev-dev libevent-dev libjansson-dev lrzsz \
  libjemalloc-dev cython python3-dev python-setuptools apache2-utils

cd /tmp/
wget http://10268950.d.cturls.net/down/10268950/cdnfly/nghttp2-master.zip
unzip nghttp2-master.zip
cd nghttp2-master
autoreconf -i
automake
autoconf
./configure
make
sudo make install

cd ~
sudo apt-get build-dep curl -y

wget http://10268950.d.cturls.net/down/10268950/cdnfly/curl-7.58.0.tar.bz2
tar -xvjf curl-7.58.0.tar.bz2
cd curl-7.58.0
./configure --with-nghttp2=/usr/local --with-ssl
sudo make && make install

echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
ldconfig


echo "192.168.0.158 for-test.cdnfly.cn" >> /etc/hosts
cd /usr/bin
mv curl curl-bak
ln -s /usr/local/bin/curl
echo "nameserver 223.5.5.5"  > /etc/resolv.conf 


# 打包tests.tar.gz上传
# 信任158
ssh-keygen
ssh-copy-id 192.168.0.158
ssh-copy-id 192.168.0.27
ssh-copy-id 192.168.0.194

sed -i 's/127.0.0.1/192.168.0.22/g' /opt/cdnfly/master/tests/task/site_sync.py /opt/cdnfly/master/tests/task/stream_sync.py
sed -i 's/192.168.0.22/192.168.0.158/g' /opt/cdnfly/master/tests/util.py
sed -i 's/192.168.0.32/192.168.0.27/g' /opt/cdnfly/master/tests/util.py
sed -i 's/192.168.0.31/192.168.0.213/g' /opt/cdnfly/master/tests/util.py

sed -i 's/192.168.0.22/192.168.0.158/g' /opt/cdnfly/master/tests/util.py
sed -i 's/192.168.0.24/192.168.0.159/g' /opt/cdnfly/master/tests/util.py
sed -i 's/192.168.0.25/192.168.0.160/g' /opt/cdnfly/master/tests/util.py
sed -i 's/192.168.0.26/192.168.0.161/g' /opt/cdnfly/master/tests/util.py

sed -i 's/192.168.0.22/192.168.0.158/g' /opt/cdnfly/master/tests/route2/*
sed -i 's/192.168.0.24/192.168.0.159/g' /opt/cdnfly/master/tests/route2/*
sed -i 's/192.168.0.25/192.168.0.160/g' /opt/cdnfly/master/tests/route2/*
sed -i 's/192.168.0.26/192.168.0.161/g' /opt/cdnfly/master/tests/route2/*

sed -i 's/192.168.0.22/192.168.0.158/g' /opt/cdnfly/master/tests/func/*
sed -i 's/192.168.0.24/192.168.0.159/g' /opt/cdnfly/master/tests/func/*
sed -i 's/192.168.0.25/192.168.0.160/g' /opt/cdnfly/master/tests/func/*
sed -i 's/192.168.0.26/192.168.0.161/g' /opt/cdnfly/master/tests/func/*

sed -i 's/192.168.0.22/192.168.0.158/g' /opt/cdnfly/master/tests/task/*
sed -i 's/192.168.0.24/192.168.0.159/g' /opt/cdnfly/master/tests/task/*
sed -i 's/192.168.0.25/192.168.0.160/g' /opt/cdnfly/master/tests/task/*
sed -i 's/192.168.0.26/192.168.0.161/g' /opt/cdnfly/master/tests/task/*


# 158网卡配置：
TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens192
UUID=71f72df7-9cd6-4c37-af3e-1efa3d5b4138
DEVICE=ens192
ONBOOT=yes


IPADDR="192.168.0.158"
PREFIX="24"
IPADDR1="192.168.0.159"
PREFIX1="24"
IPADDR2="192.168.0.160"
PREFIX2="24"
IPADDR3="192.168.0.161"
PREFIX3="24"
GATEWAY="192.168.0.1"


# agent:
ip address add 104.245.36.15 dev ens192
ip address add 154.223.140.195 dev ens192
ip address add 113.15.120.37 dev ens192
ip address add 124.166.232.1 dev ens192
yum install psmisc -y