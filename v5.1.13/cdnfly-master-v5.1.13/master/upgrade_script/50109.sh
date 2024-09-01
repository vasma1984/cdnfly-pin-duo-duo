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
        update site set ups_keepalive=0;
        update config set value="0" where name='ups_keepalive' and type='site_default_config';    
    '''

    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()   

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'message' AND column_name = 'user_package_id';"):
        sql = '''
          alter table message add `user_package_id` int(11) after event_id;
        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  


    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'message' AND column_name = 'site_id';"):
        sql = '''
          alter table message add `site_id` int(11) after user_package_id;

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  


    if not conn.fetchone("show index from message where Column_name='user_package_id';"):
        sql = '''
            alter table message add index user_package_id_idx(user_package_id);

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  
            

    if not conn.fetchone("show index from message where Column_name='site_id';"):
        sql = '''
            alter table message add index site_id_idx(site_id);    

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  

    if not conn.fetchone("show index from message where Column_name='type';"):
        sql = '''
            alter table message add index type_idx(type);   

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  


    if not conn.fetchone("show index from message where Column_name='receive';"):
        sql = '''
            alter table message add index receive_idx(receive);

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  

        
    if not conn.fetchone("show index from message where Column_name='is_show';"):
        sql = '''
            alter table message add index is_show_idx(is_show);

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()  

    if not conn.fetchone("show index from message where Column_name='create_at';"):
        sql = '''
            alter table message add index create_at_idx(create_at);

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
flist='master/panel/src/views/finance/order/count.html
master/panel/src/views/package/sold/up_down.html
master/panel/src/views/system/message/
master/panel/console/index.html
master/panel/src/controller/site-usage-senior.js
master/panel/src/controller/stream-usage-senior.js
master/panel/src/views/account/personal/index.html
master/panel/src/views/finance/order/index.html
master/panel/src/views/package/basic/assign.html
master/panel/src/views/package/basic/index.html
master/panel/src/views/package/my/detail.html
master/panel/src/views/package/my/index.html
master/panel/src/views/package/my/up_down.html
master/panel/src/views/package/sold/index.html
master/panel/src/views/site/cert/addform.html
master/panel/src/views/site/cert/cert.html
master/panel/src/views/site/group/addform.html
master/panel/src/views/site/monitor/blackip.html
master/panel/src/views/site/monitor/top-res.html
master/panel/src/views/site/monitor/usage.html
master/panel/src/views/site/site/addform.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/site/site/index.html
master/panel/src/views/site/site/update_form.html
master/panel/src/views/stream/monitor/usage.html
master/panel/src/views/stream/stream/addform.html
master/panel/src/views/stream/stream/index.html
master/panel/src/views/system/announcement/index.html
master/panel/src/views/system/user/addform.html
master/panel/src/views/system/user/index.html
master/panel/src/views/user/reg.html
master/conf/nginx_global.tpl'

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

after_update_file() {
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from view.util import create_node_task
import pymysql
import json
reload(sys) 
sys.setdefaultencoding('utf8')

conn = Db()
try:
    main_type = "nginx全局配置"
    name = "同步Nginx全局配置"

    task_id = create_node_task(conn, main_type, "同步", name, "global-0-nginx_config-nginx-config-file", 0)
    conn.execute("update config set task_id=%s where name='nginx-config-file' and type='nginx_config' and scope_name='global' ",(task_id,) )
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
version_name="v5.1.9"
version_num="50109"
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

after_update_file

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