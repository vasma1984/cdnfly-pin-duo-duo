#!/bin/bash

set -o errexit

download(){
  # wget安装
  if [[ ! `which wget` ]]; then
    if check_sys sysRelease ubuntu;then
        apt-get install -y wget
    elif check_sys sysRelease centos;then
        yum install -y wget
    fi 
  fi

  local url1=$1
  local url2=$2
  local filename=$3
  
  speed1=`curl -m 5 -L -s -w '%{speed_download}' "$url1" -o /dev/null || true`
  speed1=${speed1%%.*}
  speed2=`curl -m 5 -L -s -w '%{speed_download}' "$url2" -o /dev/null || true`
  speed2=${speed2%%.*}
  echo "speed1:"$speed1
  echo "speed2:"$speed2
  url=$url1
  if [[ $speed2 -gt $speed1 ]]; then
    url=$url2
  fi
  echo "using url:"$url
  wget "$url" -O $filename

}

#判断系统版本
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''
    local packageSupport=''

    if [[ "$release" == "" ]] || [[ "$systemPackage" == "" ]] || [[ "$packageSupport" == "" ]];then

        if [[ -f /etc/redhat-release ]];then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "debian";then
            release="debian"
            systemPackage="apt"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "ubuntu";then
            release="ubuntu"
            systemPackage="apt"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat";then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "debian";then
            release="debian"
            systemPackage="apt"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "ubuntu";then
            release="ubuntu"
            systemPackage="apt"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "centos|red hat|redhat";then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        else
            release="other"
            systemPackage="other"
            packageSupport=false
        fi
    fi

    echo -e "release=$release\nsystemPackage=$systemPackage\npackageSupport=$packageSupport\n" > /tmp/ezhttp_sys_check_result

    if [[ $checkType == "sysRelease" ]]; then
        if [ "$value" == "$release" ];then
            return 0
        else
            return 1
        fi

    elif [[ $checkType == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ];then
            return 0
        else
            return 1
        fi

    elif [[ $checkType == "packageSupport" ]]; then
        if $packageSupport;then
            return 0
        else
            return 1
        fi
    fi
}

get_sys_ver() {
cat > /tmp/sys_ver.py <<EOF
import platform
import re

sys_ver = platform.platform()
sys_ver = re.sub(r'.*-with-(.*)-.*',"\g<1>",sys_ver)
if sys_ver.startswith("centos-7"):
    sys_ver = "centos-7"
if sys_ver.startswith("centos-6"):
    sys_ver = "centos-6"
print sys_ver
EOF
echo `python /tmp/sys_ver.py`
}

force_restart() {
    killall nginx || true
    sleep 2
    ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9 || true
    sleep 2
    rm -f /var/run/nginx.sock
    /usr/local/openresty//nginx/sbin/nginx    
}

upgrade_cmd() {
# 添加ipset cdnfly_white
ipset -N cdnfly_white iphash maxelem 10000000 timeout 0
iptables -I INPUT -m set --match-set cdnfly_white src -j ACCEPT || true

# 全局白名单 爬虫
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import subprocess
sys.path.append("/opt/cdnfly/agent/")
from conf.config import ES_PWD
import json
reload(sys) 
import os
sys.setdefaultencoding('utf8')


if os.path.exists("/usr/local/openresty/nginx/conf/vhost/openresty.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json") as fp:
        data = fp.read()

    openresty = json.loads(data)
    openresty['custom_white'] = ""
    openresty['cc_enable'] = True
    openresty["built_in_white"] = ["180.153.232.0/24","180.153.234.0/24","180.153.236.0/24","180.163.220.0/24","42.236.101.0/24","42.236.102.0/24","42.236.103.0/24","42.236.10.0/24","42.236.12.0/24","42.236.13.0/24","42.236.14.0/24","42.236.15.0/24","42.236.16.0/24","42.236.17.0/24","42.236.46.0/24","42.236.48.0/24","42.236.49.0/24","42.236.50.0/24","42.236.51.0/24","42.236.52.0/24","42.236.53.0/24","42.236.54.0/24","42.236.55.0/24","42.236.99.0/24","124.166.232.0/24","116.179.32.0/24","180.76.15.0/24","180.76.5.0/24","220.181.108.0/24","123.125.71.0/24","123.125.66.0/24","111.206.198.0/24","111.206.221.0/24","180.149.133.0/24","61.135.186.0/24","220.181.32.0/24","61.135.168.0/24","23.88.208.0/24","61.135.165.0/24","61.135.169.0/24","104.245.36.0/24","149.28.84.0/24","158.247.209.0/24","23.89.152.0/24","45.66.156.0/24","65.49.194.0/24","8.9.8.0/24","103.28.15.0/24","109.228.12.0/24","109.238.6.0/24","129.143.3.0/24","142.147.250.0/24","144.76.92.0/24","162.221.189.0/24","173.212.206.0/24","173.212.237.0/24","173.249.20.0/24","173.249.22.0/24","173.249.31.0/24","174.34.149.0/24","175.45.118.0/24","178.20.236.0/24","194.48.168.0/24","194.67.218.0/24","195.201.22.0/24","202.222.13.0/24","202.222.14.0/24","203.208.60.0/24","209.141.43.0/24","209.141.60.0/24","212.162.12.0/24","213.136.87.0/24","213.136.91.0/24","217.156.87.0/24","217.20.115.0/24","23.105.51.0/24","45.77.110.0/24","45.77.142.0/24","45.77.69.0/24","5.189.166.0/24","64.68.88.0/24","64.68.90.0/24","64.68.91.0/24","64.68.92.0/24","66.249.64.0/24","66.249.65.0/24","66.249.66.0/24","66.249.68.0/24","66.249.69.0/24","66.249.70.0/24","66.249.71.0/24","66.249.72.0/24","66.249.73.0/24","66.249.74.0/24","66.249.75.0/24","66.249.76.0/24","66.249.79.0/24","79.143.185.0/24","79.174.79.0/24","89.46.100.0/24","91.144.154.0/24","93.104.213.0/24","95.211.225.0/24","108.177.64.0/24","108.177.65.0/24","108.177.66.0/24","108.177.67.0/24","108.177.68.0/24","108.177.69.0/24","108.177.70.0/24","108.177.71.0/24","108.177.72.0/24","108.177.73.0/24","108.177.74.0/24","108.177.75.0/24","108.177.76.0/24","108.177.77.0/24","108.177.78.0/24","203.208.38.0/24","209.85.238.0/24","66.249.87.0/24","66.249.89.0/24","66.249.90.0/24","66.249.91.0/24","66.249.92.0/24","72.14.199.0/24","74.125.148.0/24","74.125.149.0/24","74.125.150.0/24","74.125.151.0/24","74.125.216.0/24","74.125.217.0/24","106.11.152.0/24","106.11.153.0/24","106.11.154.0/24","106.11.155.0/24","106.11.156.0/24","106.11.157.0/24","106.11.158.0/24","106.11.159.0/24","42.120.160.0/24","42.120.161.0/24","42.120.234.0/24","42.120.235.0/24","42.120.236.0/24","42.156.136.0/24","42.156.137.0/24","42.156.138.0/24","42.156.139.0/24","42.156.254.0/24","42.156.255.0/24","103.25.156.0/24","103.255.141.0/24","104.44.253.0/24","104.44.91.0/24","104.44.92.0/24","104.44.93.0/24","104.47.224.0/24","111.221.28.0/24","111.221.31.0/24","131.253.24.0/24","131.253.25.0/24","131.253.26.0/24","131.253.27.0/24","131.253.35.0/24","131.253.36.0/24","131.253.38.0/24","131.253.46.0/24","131.253.47.0/24","13.66.139.0/24","13.66.144.0/24","157.245.205.0/24","157.55.10.0/24","157.55.103.0/24","157.55.106.0/24","157.55.107.0/24","157.55.12.0/24","157.55.13.0/24","157.55.154.0/24","157.55.2.0/24","157.55.21.0/24","157.55.22.0/24","157.55.23.0/24","157.55.34.0/24","157.55.39.0/24","157.55.50.0/24","157.55.7.0/24","157.56.0.0/24","157.56.1.0/24","157.56.2.0/24","157.56.3.0/24","157.56.71.0/24","157.56.92.0/24","157.56.93.0/24","185.209.30.0/24","191.232.136.0/24","199.30.17.0/24","199.30.18.0/24","199.30.19.0/24","199.30.20.0/24","199.30.21.0/24","199.30.22.0/24","199.30.23.0/24","199.30.24.0/24","199.30.25.0/24","199.30.26.0/24","199.30.27.0/24","199.30.28.0/24","199.30.29.0/24","199.30.30.0/24","199.30.31.0/24","202.222.14.0/24","202.89.235.0/24","207.46.12.0/24","207.46.126.0/24","207.46.13.0/24","207.46.199.0/24","207.68.155.0/24","23.103.64.0/24","40.66.1.0/24","40.66.4.0/24","40.73.148.0/24","40.77.160.0/24","40.77.161.0/24","40.77.162.0/24","40.77.163.0/24","40.77.164.0/24","40.77.165.0/24","40.77.166.0/24","40.77.167.0/24","40.77.168.0/24","40.77.169.0/24","40.77.170.0/24","40.77.171.0/24","40.77.172.0/24","40.77.173.0/24","40.77.174.0/24","40.77.175.0/24","40.77.176.0/24","40.77.177.0/24","40.77.178.0/24","40.77.179.0/24","40.77.180.0/24","40.77.181.0/24","40.77.182.0/24","40.77.183.0/24","40.77.184.0/24","40.77.185.0/24","40.77.186.0/24","40.77.187.0/24","40.77.188.0/24","40.77.189.0/24","40.77.190.0/24","40.77.191.0/24","40.77.192.0/24","40.77.193.0/24","40.77.194.0/24","40.77.195.0/24","40.77.208.0/24","40.77.209.0/24","40.77.210.0/24","40.77.211.0/24","40.77.212.0/24","40.77.213.0/24","40.77.214.0/24","40.77.215.0/24","40.77.216.0/24","40.77.217.0/24","40.77.218.0/24","40.77.219.0/24","40.77.220.0/24","40.77.221.0/24","40.77.222.0/24","40.77.223.0/24","40.77.248.0/24","40.77.250.0/24","40.77.251.0/24","40.77.252.0/24","40.77.253.0/24","40.77.254.0/24","40.77.255.0/24","40.90.11.0/24","40.90.144.0/24","40.90.145.0/24","40.90.146.0/24","40.90.147.0/24","40.90.148.0/24","40.90.149.0/24","40.90.150.0/24","40.90.151.0/24","40.90.152.0/24","40.90.153.0/24","40.90.154.0/24","40.90.155.0/24","40.90.156.0/24","40.90.157.0/24","40.90.158.0/24","40.90.159.0/24","40.90.8.0/24","42.159.176.0/24","42.159.48.0/24","51.4.84.0/24","51.5.84.0/24","52.167.144.0/24","62.109.1.0/24","64.4.22.0/24","65.52.109.0/24","65.52.110.0/24","65.54.164.0/24","65.54.247.0/24","65.55.107.0/24","65.55.146.0/24","65.55.189.0/24","65.55.208.0/24","65.55.209.0/24","65.55.210.0/24","65.55.211.0/24","65.55.212.0/24","65.55.213.0/24","65.55.214.0/24","65.55.215.0/24","65.55.216.0/24","65.55.217.0/24","65.55.218.0/24","65.55.219.0/24","65.55.25.0/24","65.55.54.0/24","106.120.173.0/24","106.120.188.0/24","106.38.241.0/24","111.202.100.0/24","111.202.101.0/24","111.202.103.0/24","123.125.125.0/24","123.126.113.0/24","123.126.68.0/24","123.183.224.0/24","173.82.95.0/24","218.30.103.0/24","220.181.124.0/24","220.181.125.0/24","36.110.147.0/24","43.231.99.0/24","49.7.116.0/24","49.7.117.0/24","49.7.20.0/24","49.7.21.0/24","58.250.125.0/24","61.135.189.0/24","110.249.201.0/24","110.249.202.0/24","111.225.148.0/24","111.225.149.0/24","220.243.135.0/24","220.243.136.0/24","220.243.188.0/24","220.243.189.0/24","60.8.123.0/24","60.8.151.0/24"]
    openresty["global_white"] = {"wm16": False, "wm8": False, "data": ["180.153.232","180.153.234","180.153.236","180.163.220","42.236.101","42.236.102","42.236.103","42.236.10","42.236.12","42.236.13","42.236.14","42.236.15","42.236.16","42.236.17","42.236.46","42.236.48","42.236.49","42.236.50","42.236.51","42.236.52","42.236.53","42.236.54","42.236.55","42.236.99","124.166.232","116.179.32","180.76.15","180.76.5","220.181.108","123.125.71","123.125.66","111.206.198","111.206.221","180.149.133","61.135.186","220.181.32","61.135.168","23.88.208","61.135.165","61.135.169","104.245.36","149.28.84","158.247.209","23.89.152","45.66.156","65.49.194","8.9.8","103.28.15","109.228.12","109.238.6","129.143.3","142.147.250","144.76.92","162.221.189","173.212.206","173.212.237","173.249.20","173.249.22","173.249.31","174.34.149","175.45.118","178.20.236","194.48.168","194.67.218","195.201.22","202.222.13","202.222.14","203.208.60","209.141.43","209.141.60","212.162.12","213.136.87","213.136.91","217.156.87","217.20.115","23.105.51","45.77.110","45.77.142","45.77.69","5.189.166","64.68.88","64.68.90","64.68.91","64.68.92","66.249.64","66.249.65","66.249.66","66.249.68","66.249.69","66.249.70","66.249.71","66.249.72","66.249.73","66.249.74","66.249.75","66.249.76","66.249.79","79.143.185","79.174.79","89.46.100","91.144.154","93.104.213","95.211.225","108.177.64","108.177.65","108.177.66","108.177.67","108.177.68","108.177.69","108.177.70","108.177.71","108.177.72","108.177.73","108.177.74","108.177.75","108.177.76","108.177.77","108.177.78","203.208.38","209.85.238","66.249.87","66.249.89","66.249.90","66.249.91","66.249.92","72.14.199","74.125.148","74.125.149","74.125.150","74.125.151","74.125.216","74.125.217","106.11.152","106.11.153","106.11.154","106.11.155","106.11.156","106.11.157","106.11.158","106.11.159","42.120.160","42.120.161","42.120.234","42.120.235","42.120.236","42.156.136","42.156.137","42.156.138","42.156.139","42.156.254","42.156.255","103.25.156","103.255.141","104.44.253","104.44.91","104.44.92","104.44.93","104.47.224","111.221.28","111.221.31","131.253.24","131.253.25","131.253.26","131.253.27","131.253.35","131.253.36","131.253.38","131.253.46","131.253.47","13.66.139","13.66.144","157.245.205","157.55.10","157.55.103","157.55.106","157.55.107","157.55.12","157.55.13","157.55.154","157.55.2","157.55.21","157.55.22","157.55.23","157.55.34","157.55.39","157.55.50","157.55.7","157.56.0","157.56.1","157.56.2","157.56.3","157.56.71","157.56.92","157.56.93","185.209.30","191.232.136","199.30.17","199.30.18","199.30.19","199.30.20","199.30.21","199.30.22","199.30.23","199.30.24","199.30.25","199.30.26","199.30.27","199.30.28","199.30.29","199.30.30","199.30.31","202.222.14","202.89.235","207.46.12","207.46.126","207.46.13","207.46.199","207.68.155","23.103.64","40.66.1","40.66.4","40.73.148","40.77.160","40.77.161","40.77.162","40.77.163","40.77.164","40.77.165","40.77.166","40.77.167","40.77.168","40.77.169","40.77.170","40.77.171","40.77.172","40.77.173","40.77.174","40.77.175","40.77.176","40.77.177","40.77.178","40.77.179","40.77.180","40.77.181","40.77.182","40.77.183","40.77.184","40.77.185","40.77.186","40.77.187","40.77.188","40.77.189","40.77.190","40.77.191","40.77.192","40.77.193","40.77.194","40.77.195","40.77.208","40.77.209","40.77.210","40.77.211","40.77.212","40.77.213","40.77.214","40.77.215","40.77.216","40.77.217","40.77.218","40.77.219","40.77.220","40.77.221","40.77.222","40.77.223","40.77.248","40.77.250","40.77.251","40.77.252","40.77.253","40.77.254","40.77.255","40.90.11","40.90.144","40.90.145","40.90.146","40.90.147","40.90.148","40.90.149","40.90.150","40.90.151","40.90.152","40.90.153","40.90.154","40.90.155","40.90.156","40.90.157","40.90.158","40.90.159","40.90.8","42.159.176","42.159.48","51.4.84","51.5.84","52.167.144","62.109.1","64.4.22","65.52.109","65.52.110","65.54.164","65.54.247","65.55.107","65.55.146","65.55.189","65.55.208","65.55.209","65.55.210","65.55.211","65.55.212","65.55.213","65.55.214","65.55.215","65.55.216","65.55.217","65.55.218","65.55.219","65.55.25","65.55.54","106.120.173","106.120.188","106.38.241","111.202.100","111.202.101","111.202.103","123.125.125","123.126.113","123.126.68","123.183.224","173.82.95","218.30.103","220.181.124","220.181.125","36.110.147","43.231.99","49.7.116","49.7.117","49.7.20","49.7.21","58.250.125","61.135.189","110.249.201","110.249.202","111.225.148","111.225.149","220.243.135","220.243.136","220.243.188","220.243.189","60.8.123","60.8.151"], "wm24": True, "wm32": False}

    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
        fp.write(json.dumps(openresty))

    # 加载到ipset，并保存到/opt
    ipset_list = []
    for ip in openresty["built_in_white"]:
        ipset_list.append("add cdnfly_white {ip} timeout 0".format(ip=ip))
    

    with open("/opt/global_white_ip_list","w") as fp:
        fp.write("\n".join(ipset_list))

    subprocess.check_output(["/sbin/ipset", "-!" , "restore" ,"-f", "/opt/global_white_ip_list"],stderr=subprocess.STDOUT)      

        
EOF

/opt/venv/bin/python /tmp/_db.py




}

# 定义版本
version_name="v4.2.10"
version_num="40210"
dir_name="cdnfly-agent-$version_name"
tar_gz_name="$dir_name-$(get_sys_ver).tar.gz"

# 下载安装包
cd /opt
echo "开始下载$tar_gz_name..."
download "http://dl2.cdnfly.cn/cdnfly/$tar_gz_name" "http://us.centos.bz/cdnfly/$tar_gz_name" "$tar_gz_name"
echo "下载完成"

echo "开始解压..."
rm -rf $dir_name
tar xf $tar_gz_name
echo "解压完成"

echo "复制config.py td-agent.conf配置文件到新版本目录..."
\cp  cdnfly/agent/conf/config.py $dir_name/agent/conf/config.py
sed -i "s/VERSION_NAME.*/VERSION_NAME=\"$version_name\"/" $dir_name/agent/conf/config.py
sed -i "s/VERSION_NUM.*/VERSION_NUM=\"$version_num\"/" $dir_name/agent/conf/config.py

\cp  cdnfly/agent/conf/filebeat.yml $dir_name/agent/conf/filebeat.yml
echo "复制完成"

###########
echo "执行升级命令..."
upgrade_cmd
echo "执行升级命令完成"
###########

echo "软链接到新版本"
cd /opt
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启agent..."

# supervisorctl reload
supervisorctl restart agent
supervisorctl restart task
#supervisorctl restart filebeat
/usr/local/openresty/nginx/sbin/nginx -s reload
# 重启nginx

# killall nginx || true
# sleep 2
# ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9 || true
# /usr/local/openresty//nginx/sbin/nginx

echo "重启完成"
echo "完成$version_name版本升级"



