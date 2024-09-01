#!/bin/bash

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

# 下载geoip2数据库
mkdir -p /opt/geoip/
cd /opt/geoip/
download "http://dl2.cdnfly.cn/cdnfly/GeoLite2-Country.mmdb" "http://us.centos.bz/cdnfly/GeoLite2-Country.mmdb" "GeoLite2-Country.mmdb-new"

# mmdblookup检查
/usr/local/openresty/libmaxminddb/bin/mmdblookup --file /opt/geoip/GeoLite2-Country.mmdb-new --ip 1.1.1.1 > /dev/null
if [[ $? != 0 ]]; then
    echo "mmdblookup检查失败"
    exit 1
fi

# 检查是否有更新
old_md5=`md5sum /opt/geoip/GeoLite2-Country.mmdb | awk '{print $1}'`
new_md5=`md5sum /opt/geoip/GeoLite2-Country.mmdb-new | awk '{print $1}'`
if [[ $old_md5 == $new_md5 ]]; then
    echo "no update"
    exit 0
fi

# 覆盖
cd /opt/geoip/
rm -f GeoLite2-Country.mmdb-old
mv GeoLite2-Country.mmdb GeoLite2-Country.mmdb-old
mv GeoLite2-Country.mmdb-new GeoLite2-Country.mmdb

echo "更新完成"