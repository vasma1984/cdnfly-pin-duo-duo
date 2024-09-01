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
mysql -N -uroot -p@cdnflypass cdn -e 'show processlist' | awk '{print $1}' | xargs kill || true

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
    
    # 建表
    sql = '''
        create table `node_line` (`id` int(11) not null AUTO_INCREMENT,`node_id` int(11),`ip` varchar(255),`line_id` varchar(255),`line_name` varchar(255),`create_at` datetime,`update_at` datetime,`enable` boolean,primary KEY `id` (`id`),KEY `idx_enable` (`enable`),CONSTRAINT `node_ibfk_4` FOREIGN KEY (`node_id`) REFERENCES `node` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        alter table line add node_line_id int(11) after node_group_id;
        alter table line add CONSTRAINT `node_line_ibfk_1` FOREIGN KEY (`node_line_id`) REFERENCES `node_line` (`id`); 
        insert into `tlock` values ("node_line");

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 转换数据
    lines = conn.fetchall("select * from line group by node_id,ip,line_id;")
    for l in lines:
        node_group_id = l['node_group_id']
        node_id = l['node_id']
        ip = l['ip']
        line_id = l['line_id']
        line_name = l['line_name']
        create_at = l['create_at']
        update_at = l['update_at']
        enable = l['enable']

        conn.execute("insert into node_line values (null,%s,%s,%s,%s,%s,%s,%s)",(node_id,ip,line_id,line_name,create_at,update_at,enable,))
        node_line_id = conn.insert_id()
        conn.execute("update line set node_line_id=%s where node_id=%s and ip=%s and line_id=%s ",(node_line_id,node_id,ip,line_id,) )
        conn.commit()

    # 删除字段
    sql = '''
        delete from line where enable=0;
        alter table line drop FOREIGN KEY `node_ibfk_3`;
        alter table line drop node_id;
        alter table line drop ip;
        alter table line drop line_id;
        alter table line drop line_name;
        alter table line drop enable;
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
version_name="v4.1.2"
version_num="40102"
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

