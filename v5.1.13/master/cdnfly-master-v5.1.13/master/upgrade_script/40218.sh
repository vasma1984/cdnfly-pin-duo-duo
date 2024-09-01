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
supervisorctl stop  cc_auto_switch site_res_count site_sync task
eval `grep MYSQL_PASS /opt/cdnfly/master/conf/config.py`
mysql -N -uroot -p$MYSQL_PASS cdn -e 'show processlist' | awk '{print $1}' | xargs kill || true

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
    # 
    sql = '''
        alter table user_package add task_id int(11);
        alter table user_package add CONSTRAINT `task_ibfk_21` foreign key(`task_id`) REFERENCES `task`(`id`)
        insert into config values ('node_monitor_config','{"monitor_api":"", "interval":30,"failed_times":3,"failed_rate":"50"}','system','0','global', now(),now(),1,null); 

        alter table node drop check_failed;
        alter table node drop check_log;
        alter table node add check_protocol varchar(10) default "http";
        alter table node add check_timeout int(11) default 2;
        alter table node add check_port int(11) default 80;
        alter table node add check_host varchar(255) ;
        alter table node add check_path varchar(255) default '/';
        alter table node add check_node_group varchar(255) default 1;
        alter table node add check_action varchar(10) default 'pause';
        update node set check_on=0;

        CREATE TABLE `node_monitor_log` (`create_at` datetime DEFAULT NULL,`event_id` varchar(10) DEFAULT NULL,`ip` varchar(15) DEFAULT NULL,`success` varchar(2) DEFAULT NULL,`node_id` int(11) DEFAULT NULL,KEY `idx_create_at` (`create_at`),KEY `idx_event_id` (`event_id`),KEY `idx_ip` (`ip`),KEY `idx_success` (`success`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        alter table line add is_backup boolean default False;
        alter table line add enable_backup boolean default False;        

        alter table package add backup_node_group int(11) after node_group_id;
        alter table package add CONSTRAINT `node_group_ibfk_4` FOREIGN KEY (`backup_node_group`) REFERENCES `node_group` (`id`);

        alter table user_package add backup_node_group int(11) after node_group_id;
        alter table user_package add CONSTRAINT `node_group_ibfk_5` FOREIGN KEY (`backup_node_group`) REFERENCES `node_group` (`id`);
        alter table user_package add enable_backup_group boolean default 0 after backup_node_group;


        alter table site add backup_node_group int(11) after node_group_id;
        alter table site add CONSTRAINT `node_group_ibfk_6` FOREIGN KEY (`backup_node_group`) REFERENCES `node_group` (`id`);
        alter table site add enable_backup_group boolean default 0 after backup_node_group;

        alter table stream add backup_node_group int(11) after node_group_id;
        alter table stream add CONSTRAINT `node_group_ibfk_7` FOREIGN KEY (`backup_node_group`) REFERENCES `node_group` (`id`);
        alter table stream add enable_backup_group boolean default 0 after backup_node_group;

        CREATE TABLE `ip_switch_log` (`create_at` datetime DEFAULT NULL,`type` varchar(30) DEFAULT NULL,`node_group_id` int(11),`node_id` int(11),`line_id` int(11),`ip` varchar(20) DEFAULT NULL,`action` varchar(20) DEFAULT NULL,KEY `idx_type` (`type`),KEY `idx_node_id` (`node_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


        alter table line add is_backup_default_line boolean default false;
        alter table line add enable_backup_default_line boolean default false;

        alter table task  modify res longtext;
        alter table task  modify data longtext;

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

/opt/venv/bin/python /tmp/_db.py

}
# 定义版本
version_name="v4.2.18"
version_num="40218"
dir_name="cdnfly-master-$version_name"
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
#supervisorctl restart all
supervisorctl reload
echo "重启完成"
echo "完成$version_name版本升级"

