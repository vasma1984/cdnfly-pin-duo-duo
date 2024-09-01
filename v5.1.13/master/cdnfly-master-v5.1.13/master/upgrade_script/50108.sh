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
supervisorctl stop task
mysql -N -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB -e "truncate table node_monitor_log;"

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

    # config表openresty-config，增加default_page_refuse
    config = json.loads(conn.fetchone("select value from config where name='openresty-config' and type='openresty_config' and scope_name='global' ")['value'])
    config['default_page_refuse'] = "0"
    conn.execute("update config set value=%s where name='openresty-config' and type='openresty_config' and scope_name='global' ",json.dumps(config))
    conn.commit()    

    # config表node_monitor_config，增加bw_exceed_times
    config = json.loads(conn.fetchone("select value from config where name='node_monitor_config' and type='system' and scope_name='global' ")['value'])
    config['bw_exceed_times'] = 2
    conn.execute("update config set value=%s where name='node_monitor_config' and type='system' and scope_name='global' ",json.dumps(config))
    conn.commit()   

    # proxy_cache加range: false
    sites = conn.fetchall("select id,proxy_cache from site")
    for site in sites:
        site_id = site['id']
        proxy_cache = json.loads(site['proxy_cache'])
        if proxy_cache:
            for i in range(len(proxy_cache)):
                proxy_cache[i]["range"] = 0

            conn.execute("update site set proxy_cache=%s where id=%s",(json.dumps(proxy_cache),site_id,) )
            conn.commit()

    configs = conn.fetchall("select scope_name,value from config where name='proxy_cache' and type='site_default_config' ")
    for config in configs:
        value = json.loads(config['value'])
        scope_name = config['scope_name']

        if value:
            for i in range(len(value)):
                value[i]["range"] = 0

            conn.execute("update config set value=%s where type='site_default_config' and name='proxy_cache' and scope_name=%s ",(json.dumps(value),scope_name,) )
            conn.commit()

    # ups_keepalive
    if not conn.fetchone("select * from config where name='ups_keepalive' "):
        conn.execute("insert into config values ('ups_keepalive','1','site_default_config','0','global', now(),now(),1,null)")
        conn.commit()

    # ups_keepalive_conn
    if not conn.fetchone("select * from config where name='ups_keepalive_conn' "):
        conn.execute("insert into config values ('ups_keepalive_conn','5','site_default_config','0','global', now(),now(),1,null)")
        conn.commit()

    # ups_keepalive_timeout
    if not conn.fetchone("select * from config where name='ups_keepalive_timeout' "):
        conn.execute("insert into config values ('ups_keepalive_timeout','50','site_default_config','0','global', now(),now(),1,null)")
        conn.commit()

    # package_allow_upgrade
    if not conn.fetchone("select * from config where name='package_allow_upgrade' "):
        conn.execute("insert into config values ('package_allow_upgrade','1','system','0','global', now(),now(),1,null)")
        conn.commit()

    # package_allow_downgrade
    if not conn.fetchone("select * from config where name='package_allow_downgrade' "):
        conn.execute("insert into config values ('package_allow_downgrade','1','system','0','global', now(),now(),1,null)")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'package' AND column_name = 'backend_ip_limit';"):
        conn.execute("alter table package add backend_ip_limit text after buy_num_limit")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'node' AND column_name = 'bw_limit';"):
        conn.execute("alter table node add bw_limit varchar(50) default '' ")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'node' AND column_name = 'disable_by';"):
        conn.execute("alter table node add disable_by varchar(20) after enable")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'line' AND column_name = 'disable_by';"):
        conn.execute("alter table line add disable_by varchar(20)")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'node_monitor_log' AND column_name = 'type';"):
        conn.execute("alter table node_monitor_log add type varchar(10) after create_at")
        conn.commit()

    sql = '''
        alter table acl modify data MEDIUMTEXT;
        alter table cc_match modify data MEDIUMTEXT;
        alter table node_monitor_log modify ip varchar(50);
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


# 更新panel或conf
flist='master/panel/console/index.html
master/panel/src/controller/stream-usage-senior.js
master/panel/src/views/config/cc/index.html
master/panel/src/views/config/default/index.html
master/panel/src/views/node/group/index.html
master/panel/src/views/node/group/line.html
master/panel/src/views/node/monitor/index.html
master/panel/src/views/node/monitor/switch-log.html
master/panel/src/views/node/node/index.html
master/panel/src/views/node/node/node-log.html
master/panel/src/views/node/node/nodeform.html
master/panel/src/views/package/basic/addform.html
master/panel/src/views/package/basic/index.html
master/panel/src/views/site/monitor/access-log.html
master/panel/src/views/site/site/cache_form.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/site/site/update_form.html
master/panel/src/views/system/config/index.html
master/panel/src/views/system/update/index.html
master/conf/supervisor_master.conf
master/conf/nginx_http_vhost.tpl'

for f in `echo $flist`;do
\cp /opt/$dir_name/$f /opt/cdnfly/$f
done

}

update_file() {
cd /opt/$dir_name/master/
for i in `find ./ | grep -vE "^./$|^./agent$|^./conf$|conf/config.py|conf/nginx_global.tpl|conf/supervisor_master.conf|conf/nginx_http_default.tpl|conf/nginx_http_vhost.tpl|conf/nginx_stream_vhost.tpl|conf/ssl.cert|conf/ssl.key|^./panel"`;do
    \cp -aT $i /opt/cdnfly/master/$i
done

}

# 定义版本
version_name="v5.1.8"
version_num="50108"
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