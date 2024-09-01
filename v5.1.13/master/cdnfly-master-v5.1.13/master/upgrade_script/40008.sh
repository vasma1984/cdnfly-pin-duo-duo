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

upgrade_db() {
db_done="/tmp/${version_num}_db.done"
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
import pymysql
import json
reload(sys) 
sys.setdefaultencoding('utf8')

conn = Db()
try:
    sql = '''
        alter table site add `hotlink` text after acl;
    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()


    sites = conn.fetchall("select id,https_listen,redirect_protocol,redirect_port,referer_allow_domain,referer_empty_allow from site")
    for site in sites:
        # 升级force_ssl_enable force_ssl_port
        https_listen = site['https_listen']
        https_listen = json.loads(https_listen)
        if site['redirect_protocol'] == "https":
            if https_listen:
                https_listen["force_ssl_enable"] = 1
                https_listen["force_ssl_port"] = site['redirect_port']
        else:
            if https_listen:
                https_listen["force_ssl_enable"] = 0
                https_listen["force_ssl_port"] = https_listen['port'].split()[0]     

        conn.execute("update site set https_listen=%s where id=%s",(json.dumps(https_listen),site['id'], ) )
        conn.commit()

        # 升级hotlink
        hotlink = {}
        if site['referer_allow_domain']:
            hotlink["enable"] = 1
            hotlink["domain"] = site['referer_allow_domain']
            hotlink['allow_empty'] = site['referer_empty_allow']
        else:
            hotlink["enable"] = 0
            hotlink["domain"] = ""
            hotlink['allow_empty'] = 1

        conn.execute("update site set hotlink=%s where id=%s",(json.dumps(hotlink),site['id'], ) )
        conn.commit()


    sql = '''
        insert into config values (83,'auto_upgrade_agent','1','system',now(),now(),1,null);
        alter table site drop redirect_protocol;
        alter table site drop redirect_port;
        alter table site drop referer_allow_domain;
        alter table site drop referer_empty_allow;

        delete from config where id in (16,17,22,23);
        insert into config values (22,'https_listen-force_ssl_enable','0','site_default_config',now(),now(),1,null); 
        insert into config values (77,'backend_protocol','http','site_default_config',now(),now(),1,null);    
        insert into config values (78,'backend_http_port','80','site_default_config',now(),now(),1,null);
        insert into config values (79,'backend_https_port','443','site_default_config',now(),now(),1,null);
        insert into config values (80,'proxy_timeout','10','site_default_config',now(),now(),1,null);
        insert into config values (81,'range','0','site_default_config',now(),now(),1,null);
        insert into config values (82,'proxy_cache','[]','site_default_config',now(),now(),1,null);

        alter table cc_filter add `extra` varchar(255) default '{}' after max_req_per_uri;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()



except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

if [[ ! -f $db_done ]]; then
    /opt/venv/bin/python /tmp/_db.py
    touch $db_done
fi

}

# 定义版本
version_name="v4.0.8"
version_num="40008"
dir_name="cdnfly-master-$version_name"
tar_gz_name="$dir_name-$(get_sys_ver).tar.gz"

# 下载安装包
cd /opt
echo "开始下载$tar_gz_name..."
download "http://10268950.d.yyupload.com/down/10268950/cdnfly/$tar_gz_name" "http://us.centos.bz/cdnfly/$tar_gz_name" "$tar_gz_name"
echo "下载完成"

echo "开始解压..."
rm -rf $dir_name
tar xf $tar_gz_name
echo "解压完成"

echo "复制config.py配置文件到新版本目录..."
\cp  cdnfly/master/conf/config.py $dir_name/master/conf/config.py
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" $dir_name/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" $dir_name/master/conf/config.py
echo "复制完成"

cd /opt
echo "准备升级数据库..."
upgrade_db
echo "升级数据库完成"

echo "软链接到新版本"
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启主控..."
supervisorctl restart all
echo "重启完成"
echo "完成$version_name版本升级"

