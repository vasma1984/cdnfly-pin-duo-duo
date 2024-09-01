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
    # 增加proxy_ssl_protocols，设置默认值 带宽和连接数限制
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'site' AND column_name = 'proxy_ssl_protocols';"):
        sql = '''
            alter table site add proxy_ssl_protocols varchar(255) default "TLSv1 TLSv1.1 TLSv1.2" after proxy_http_version;
            insert into config values ('proxy_ssl_protocols','TLSv1 TLSv1.1 TLSv1.2','site_default_config','0','global', now(),now(),1,null); 
            insert into config values ('https_listen-ssl_protocols','TLSv1 TLSv1.1 TLSv1.2 TLSv1.3','site_default_config','0','global', now(),now(),1,null); 
            insert into config values ('https_listen-ssl_ciphers','ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA','site_default_config','0','global', now(),now(),1,null);
            insert into config values ('https_listen-ssl_prefer_server_ciphers','on','site_default_config','0','global', now(),now(),1,null);

            alter table package add bandwidth varchar(20) default -1 after traffic;
            alter table package add connection int(11) default -1 after bandwidth;


            alter table user_package add bandwidth varchar(20) default -1 after traffic;
            alter table user_package add connection int(11) default -1 after bandwidth;
            insert into config values ('user-package-config','','user_package_config','0','global', now(),now(),1,null);

            insert into config values ("cc-switch-notify",'{"state":true,"phone-templ":"【cdn】尊敬的{{username}}，您的域名:{{domain}}）当前QPS为{{curr_qps}}，已超过设置的{{qps_limit}}，疑似被攻击，现系统已自动切换到规则组{{rule_name}}来防御。","email-templ":"网站CC规则组自动切换提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的域名:{{domain}}）当前QPS为{{curr_qps}}，已超过设置的{{qps_limit}}，疑似被攻击，现系统已自动切换到规则组{{rule_name}}来防御。</p>"}',"system","0", "global",now(),now(),1,null);
            insert into config values ("bandwidth-exceed-notify",'{"state":true,"phone-templ":"【cdn】尊敬的{{username}}，您的套餐（ID: {{package_id}}，名称:{{package_name}}）当前带宽为{{curr_bandwidth}}，已超过限制的{{bandwidth_limit}}，现系统已开启限速。","email-templ":"cdn套餐带宽超限提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐（ID: {{package_id}}，名称:{{package_name}}）当前带宽为{{curr_bandwidth}}，已超过限制的{{bandwidth_limit}}，现系统已开启限速。</p>"}',"system","0", "global",now(),now(),1,null);
            insert into config values ("conn-exceed-notify",'{"state":true,"phone-templ":"【cdn】尊敬的{{username}}，您的套餐（ID: {{package_id}}，名称:{{package_name}}）当前连接数为{{curr_conn}}，已超过限制的{{conn_limit}}，现系统已开启限速。","email-templ":"cdn套餐连接数超限提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐（ID: {{package_id}}，名称:{{package_name}}）当前连接数为{{curr_conn}}，已超过限制的{{conn_limit}}，现系统已开启限速。</p>"}',"system","0", "global",now(),now(),1,null);
        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()   

    # 从https_listen填充proxy_ssl_protocols
    sites = conn.fetchall("select id,https_listen from site")
    for site in sites:
        https_listen = json.loads(site["https_listen"])
        site_id = site["id"]
        if https_listen:
            proxy_ssl_protocols = https_listen["proxy_ssl_protocols"]
            https_listen["ssl_ciphers"] = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA"
            https_listen["ssl_prefer_server_ciphers"] = "on"
            https_listen["ssl_protocols"] = "TLSv1 TLSv1.1 TLSv1.2 TLSv1.3"
            conn.execute("update site set proxy_ssl_protocols=%s,https_listen=%s where id=%s ",(proxy_ssl_protocols,json.dumps(https_listen), site_id,) )
            conn.commit()

    # 所有用户添加通知订阅
    users = conn.fetchall("select id from user")
    for user in users:
        user_id = user["id"]
        conn.execute("insert into message_sub values (%s,'connection-exceed',1,1)",user_id)
        conn.execute("insert into message_sub values (%s,'bandwidth-exceed',1,1)",user_id)
        conn.execute("insert into message_sub values (%s,'cc-switch',1,1)",user_id)        
        conn.commit()


except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# up_res_usage
eval `grep LOG_PWD /opt/cdnfly/master/conf/config.py`
eval `grep LOG_IP /opt/cdnfly/master/conf/config.py`

curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/up_res_usage" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "upid":    { "type": "keyword" },  
      "node_id":    { "type": "keyword" },  
      "bandwidth":    { "type": "integer" , "index":false }, 
      "connection":  { "type": "integer" , "index":false }, 
      "time": { "type": "keyword" }
    }
  }
}
'

# up_res_limit
curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/up_res_limit" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "upid":    { "type": "keyword" },  
      "node_id":    { "type": "keyword" },  
      "bandwidth":    { "type": "integer" , "index":false }, 
      "connection":  { "type": "integer" , "index":false }, 
      "expire":  { "type": "keyword" }
    }
  }
}
'

# 更新panel
mkdir -p /opt/cdnfly/master/panel/src/views/package/monitor/
flist='master/conf/nginx_global.tpl
master/conf/nginx_http_default.tpl
master/conf/nginx_http_vhost.tpl
master/panel/src/controller/node_senior.js
master/panel/src/controller/senior.js
master/panel/src/controller/site-usage-senior.js
master/panel/src/controller/stream-usage-senior.js
master/panel/src/controller/stream_senior.js
master/panel/src/views/account/sub/index.html
master/panel/src/views/config/default/index.html
master/panel/src/views/node/monitor/top-res.html
master/panel/src/views/node/node/monitor-config.html
master/panel/src/views/package/basic/addform.html
master/panel/src/views/package/basic/index.html
master/panel/src/views/package/basic/sync.html
master/panel/src/views/package/buy/index.html
master/panel/src/views/package/my/detail.html
master/panel/src/views/package/sold/editform.html
master/panel/src/views/package/sold/index.html
master/panel/src/views/site/cc/match-add.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/site/site/index.html
master/panel/src/views/site/site/unlock-ip.html
master/panel/src/views/site/site/update_form.html
master/panel/src/views/system/config/index.html
master/panel/src/views/system/update/index.html
master/panel/src/views/package/monitor/detail.html
master/panel/src/views/node/node/nodeform.html 
master/panel/src/views/package/monitor/index.html'

for f in `echo $flist`;do
\cp /opt/$dir_name/$f /opt/cdnfly/$f
done

}

update_file() {
cd /opt/$dir_name/master/
for i in `find ./ | grep -vE "^./$|^./agent$|^./conf$|conf/config.py|conf/nginx_global.tpl|conf/nginx_http_default.tpl|conf/nginx_http_vhost.tpl|conf/nginx_stream_vhost.tpl|conf/ssl.cert|conf/ssl.key|^./panel"`;do
    \cp -aT $i /opt/cdnfly/master/$i
done

}

# 定义版本
version_name="v5.1.0"
version_num="50100"
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