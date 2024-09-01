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
eval `grep MYSQL_PASS /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_IP /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_PORT /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_DB /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_USER /opt/cdnfly/master/conf/config.py`


mysql -N -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB -e 'show processlist' | awk '{print $1}' | xargs kill || true
supervisorctl stop cc_auto_switch site_res_count site_sync task
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

    # 外键
    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_1'"):
        conn.execute("ALTER TABLE `line` DROP FOREIGN KEY `task_ibfk_1`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_3'"):
        conn.execute(" ALTER TABLE `cert` DROP FOREIGN KEY `task_ibfk_3`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_4'"):
        conn.execute(" ALTER TABLE `cert` DROP FOREIGN KEY `task_ibfk_4`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_5'"):
        conn.execute("ALTER TABLE `acl` DROP FOREIGN KEY `task_ibfk_5`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_8'"):
        conn.execute("ALTER TABLE `cc_rule` DROP FOREIGN KEY `task_ibfk_8`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_6'"):
        conn.execute("ALTER TABLE `cc_match` DROP FOREIGN KEY `task_ibfk_6`")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_7'"):
        conn.execute("ALTER TABLE `cc_filter` DROP FOREIGN KEY `task_ibfk_7`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_14'"):
        conn.execute(" ALTER TABLE `config` DROP FOREIGN KEY `task_ibfk_14`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_9'"):
        conn.execute("ALTER TABLE `site` DROP FOREIGN KEY `task_ibfk_9`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_19'"):
        conn.execute("ALTER TABLE `site` DROP FOREIGN KEY `task_ibfk_19`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_11'"):
        conn.execute("ALTER TABLE `stream` DROP FOREIGN KEY `task_ibfk_11`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_20'"):
        conn.execute("ALTER TABLE `stream` DROP FOREIGN KEY `task_ibfk_20`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_18'"):
        conn.execute("ALTER TABLE `job` DROP FOREIGN KEY `task_ibfk_18`;")
        conn.commit()

    if conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_21'"):
        conn.execute("ALTER TABLE `user_package` DROP FOREIGN KEY `task_ibfk_21`;")
        conn.commit()

    # 索引

    if not conn.fetchone("show index from node_monitor_log where Column_name='type';"):
        conn.execute("alter table node_monitor_log add index idx_type(`type`);")
        conn.commit()  

    if conn.fetchone("show index from line where Key_name='task_ibfk_1';"):
        conn.execute("ALTER TABLE `line` DROP INDEX `task_ibfk_1`;")
        conn.commit()  

    if conn.fetchone("show index from cert where Key_name='task_ibfk_3';"):
        conn.execute("ALTER TABLE `cert` DROP INDEX `task_ibfk_3`;")
        conn.commit()  

    if conn.fetchone("show index from cert where Key_name='task_ibfk_4';"):
        conn.execute("ALTER TABLE `cert` DROP INDEX `task_ibfk_4`;")
        conn.commit()  

    if conn.fetchone("show index from acl where Key_name='task_ibfk_5';"):
        conn.execute("ALTER TABLE `acl` DROP INDEX `task_ibfk_5`;")
        conn.commit()  

    if conn.fetchone("show index from cc_rule where Key_name='task_ibfk_8';"):
        conn.execute("ALTER TABLE `cc_rule` DROP INDEX `task_ibfk_8`;")
        conn.commit()  

    if conn.fetchone("show index from cc_match where Key_name='task_ibfk_6';"):
        conn.execute("ALTER TABLE `cc_match` DROP INDEX `task_ibfk_6`;")
        conn.commit()  

    if conn.fetchone("show index from cc_filter where Key_name='task_ibfk_7';"):
        conn.execute("ALTER TABLE `cc_filter` DROP INDEX `task_ibfk_7`;")
        conn.commit()  

    if conn.fetchone("show index from config where Key_name='task_ibfk_14';"):
        conn.execute("ALTER TABLE `config` DROP INDEX `task_ibfk_14`;")
        conn.commit()  

    if conn.fetchone("show index from site where Key_name='task_ibfk_9';"):
        conn.execute("ALTER TABLE `site` DROP INDEX `task_ibfk_9`;")
        conn.commit()  

    if conn.fetchone("show index from site where Key_name='task_ibfk_19';"):
        conn.execute("ALTER TABLE `site` DROP INDEX `task_ibfk_19`;")
        conn.commit()  

    if conn.fetchone("show index from stream where Key_name='task_ibfk_11';"):
        conn.execute("ALTER TABLE `stream` DROP INDEX `task_ibfk_11`;")
        conn.commit()                          

    if conn.fetchone("show index from stream where Key_name='task_ibfk_20';"):
        conn.execute("ALTER TABLE `stream` DROP INDEX `task_ibfk_20`;")
        conn.commit()   

    if conn.fetchone("show index from job where Key_name='task_ibfk_18';"):
        conn.execute("ALTER TABLE `job` DROP INDEX `task_ibfk_18`;")
        conn.commit()   

    if conn.fetchone("show index from user_package where Key_name='task_ibfk_21';"):
        conn.execute("ALTER TABLE `user_package` DROP INDEX `task_ibfk_21`;")
        conn.commit()   


    sql = '''
        alter table line modify task_id bigint;
        alter table cert modify task_id bigint;
        alter table cert modify issue_task_id bigint;
        alter table acl modify task_id bigint;
        alter table cc_rule modify task_id bigint;
        alter table cc_match modify task_id bigint;
        alter table cc_filter modify task_id bigint;
        alter table config modify task_id bigint;
        alter table site modify task_id bigint;
        alter table site modify cname_task_id bigint;
        alter table stream modify task_id bigint;
        alter table stream modify cname_task_id bigint;
        alter table job modify task_id bigint;
        alter table user_package modify task_id bigint;


        DROP TABLE IF EXISTS `task`;
        CREATE TABLE `task` (`id` bigint(20) NOT NULL AUTO_INCREMENT,`pid` int(11) DEFAULT NULL,`pry` int(11) DEFAULT NULL,`name` varchar(255) DEFAULT NULL,`type` varchar(255) DEFAULT NULL,`res` longtext,`data` longtext,`depend` text,`create_at` datetime DEFAULT NULL,`start_at` datetime DEFAULT NULL,`end_at` datetime DEFAULT NULL,`ret` text,`enable` tinyint(1) DEFAULT NULL,`state` varchar(255) DEFAULT NULL,`err_times` int(11) DEFAULT '0',`retry_at` datetime DEFAULT NULL,`progress` varchar(255) DEFAULT NULL,PRIMARY KEY (`id`),KEY `idx_pid` (`pid`),KEY `idx_type` (`type`(191)),KEY `idx_create_at` (`create_at`),KEY `idx_enable` (`enable`),KEY `idx_state` (`state`(191)),KEY `idx_pry` (`pry`)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()   

    if not conn.fetchone("select id from task where id=1"):
        conn.execute("insert into task values (1,0,null,null,null,null,null,null,now(),now(),now(),null,1,'done',0,null,null);")
        conn.commit()
    
    sql = '''
        update line set task_id = 1;
        update cert set task_id  = 1;
        update cert set issue_task_id  = 1;
        update acl set task_id = 1;
        update cc_rule set task_id  = 1;
        update cc_match set task_id  = 1;
        update cc_filter set task_id = 1;
        update user_package set task_id = 1;
        update config set task_id  = 1;
        update site set task_id = 1;
        update site set cname_task_id  = 1;
        update stream set task_id = 1;
        update stream set cname_task_id  = 1;
        update job set task_id  = 1;
        update node set config_task = 1;

    '''

    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()   

    # 添加外键    
    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_1'"):
        conn.execute("alter table line add CONSTRAINT `task_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_3'"):
        conn.execute("alter table cert add CONSTRAINT `task_ibfk_3` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_4'"):
        conn.execute("alter table cert add CONSTRAINT `task_ibfk_4` FOREIGN KEY (`issue_task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_5'"):
        conn.execute("alter table acl add CONSTRAINT `task_ibfk_5` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_8'"):
        conn.execute("alter table cc_rule add CONSTRAINT `task_ibfk_8` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_6'"):
        conn.execute("alter table cc_match add CONSTRAINT `task_ibfk_6` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_7'"):
        conn.execute("alter table cc_filter add CONSTRAINT `task_ibfk_7` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_21'"):
        conn.execute("alter table user_package add CONSTRAINT `task_ibfk_21` foreign key(`task_id`) REFERENCES `task`(`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_14'"):
        conn.execute("alter table config add CONSTRAINT `task_ibfk_14` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_9'"):
        conn.execute("alter table site add CONSTRAINT `task_ibfk_9` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_19'"):
        conn.execute("alter table site add CONSTRAINT `task_ibfk_19` foreign key(`cname_task_id`) REFERENCES `task`(`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_11'"):
        conn.execute("alter table stream add CONSTRAINT `task_ibfk_11` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_20'"):
        conn.execute("alter table stream add CONSTRAINT `task_ibfk_20` foreign key(`cname_task_id`) REFERENCES `task`(`id`);")
        conn.commit()

    if not conn.fetchone("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where CONSTRAINT_NAME='task_ibfk_18'"):
        conn.execute("alter table job add CONSTRAINT `task_ibfk_18` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);")
        conn.commit()

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py


# 更新panel或conf
flist='master/panel/console/index.html
master/panel/src/views/node/node/index.html
master/panel/src/views/node/node/node-log.html
master/panel/console/user_menu.json'

for f in `echo $flist`;do
\cp -a /opt/$dir_name/$f /opt/cdnfly/$f
done

}

update_file() {
cd /opt/$dir_name/master/
for i in `find ./ | grep -vE "^./$|^./agent$|^./conf$|conf/config.py|conf/nginx_global.tpl|conf/supervisor_master.conf|conf/nginx_http_default.tpl|conf/nginx_http_vhost.tpl|conf/nginx_stream_vhost.tpl|conf/ssl.cert|conf/ssl.key|^./panel"`;do
    \cp -aT $i /opt/cdnfly/master/$i
done

}

# 定义版本
version_name="v5.1.11"
version_num="50111"
dir_name="cdnfly-master-$version_name"
tar_gz_name="$dir_name-$(get_sys_ver).tar.gz"

# 下载安装包
cd /opt
echo "开始下载$tar_gz_name..."
download "https://dl2.cdnfly.cn/cdnfly/$tar_gz_name" "https://us.centos.bz/cdnfly/$tar_gz_name" "$tar_gz_name"
echo "下载完成"

echo "开始解压..."
rm -rf $dir_name
tar xf $tar_gz_name
echo "解压完成"

cd /opt
echo "准备升级数据库..."
upgrade_db
echo "升级数据库完成"

echo "更新文件..."
update_file
echo "更新文件完成."

echo "修改config.py版本..."
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" /opt/cdnfly/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" /opt/cdnfly/master/conf/config.py
echo "修改完成"

echo "开始重启主控..."
supervisorctl restart all
#supervisorctl reload
echo "重启完成"


echo "清理文件"
rm -rf /opt/$dir_name
rm -f /opt/$tar_gz_name
echo "清理完成"

echo "完成$version_name版本升级"