#!/bin/bash

# 下载geoip2数据库
mkdir -p /opt/geoip/
wget -q "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=Hqin8a2wR9d6mKQ7&suffix=tar.gz" -O /tmp/GeoLite2-Country.mmdb.gz
cd /tmp
rm -rf GeoLite2-Country_*
tar xf GeoLite2-Country.mmdb.gz
\cp GeoLite2-Country_*/GeoLite2-Country.mmdb /opt/geoip/GeoLite2-Country.mmdb-new

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
