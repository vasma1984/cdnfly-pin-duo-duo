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

    # config表openresty-config，增加icmp_drop
    config = json.loads(conn.fetchone("select value from config where name='openresty-config' and type='openresty_config' and scope_name='global' ")['value'])
    config['icmp_drop'] = "0"
    conn.execute("update config set value=%s where name='openresty-config' and type='openresty_config' and scope_name='global' ",json.dumps(config))
    conn.commit()  

    # 登录安全 白名单，多个，短信或邮件二次验证
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'user' AND column_name = 'white_ip';"):
        conn.execute("alter table user add white_ip varchar(255) after cert_verified;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'user' AND column_name = 'login_captcha';"):
        conn.execute("alter table user add login_captcha varchar(10) after white_ip;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'login_log' AND column_name = 'post_content';"):
        conn.execute("alter table login_log add post_content text;")
        conn.commit()

    if not conn.fetchone("select value from config where name='allow-enable-email-captcha-login' "):
        conn.execute("insert into config values ('allow-enable-email-captcha-login','1','system','0','global',now(),now(),1,null);")
        conn.commit()

    if not conn.fetchone("select value from config where name='allow-enable-sms-captcha-login' "):
        conn.execute("insert into config values ('allow-enable-sms-captcha-login','0','system','0','global',now(),now(),1,null);")
        conn.commit()    
    

    # config表nginx，增加proxy_request_buffering
    config = json.loads(conn.fetchone("select value from config where name='nginx-config-file' and type='nginx_config' and scope_name='global' ")['value'])
    config['http']['proxy_request_buffering'] = "on"
    conn.execute("update config set value=%s where name='nginx-config-file' and type='nginx_config' and scope_name='global' ",json.dumps(config))
    conn.commit()

    # 证书过期通知
    if not conn.fetchone("select value from config where name='cert-expire-notify' "):
        conn.execute(''' insert into config values ("cert-expire-notify",'{"state":true,"notify-times":"2","interval":"24","phone-templ":"【cdn】尊敬的{{username}}，您的证书（ID: {{cert_id}}，名称:{{cert_name}}，域名:{{domain}} ）已过期，为避免影响业务，请尽快处理。","email-templ":"cdn证书过期提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的证书（ID: {{cert_id}}，名称:{{cert_name}}，域名:{{domain}} ）已过期，为避免影响业务，请尽快处理。</p>"}',"system","0", "global",now(),now(),1,null); ''')
        conn.commit()        

    if not conn.fetchone("select value from config where name='cert-expiring-notify' "):
        conn.execute('''insert into config values ("cert-expiring-notify",'{"state":true,"notify-times":"3","less":"7","interval":"24","phone-templ":"【cdn】尊敬的{{username}}，您的证书（ID: {{cert_id}}，名称:{{cert_name}}，域名:{{domain}} ）即期过期，仅剩余{{remain_days}}天，为避免影响您的业务，请及时处理。","email-templ":"cdn证书即将过期提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的证书（ID: {{cert_id}}，名称:{{cert_name}}，域名:{{domain}} ）即期过期，仅剩余{{remain_days}}天，为避免影响您的业务，请及时处理。</p>"}',"system","0", "global",now(),now(),1,null); ''')
        conn.commit()    

    users = conn.fetchall("select id from user")
    for user in users:
        user_id = user["id"]
        if not conn.fetchone("select * from message_sub where uid=%s and msg_type='cert-expire' ",user_id):
            conn.execute("insert into message_sub values (%s,'cert-expire',1,1);",user_id)
            conn.commit()

    # 节点类通知
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_need_send';"):
        conn.execute("alter table ip_switch_log add email_need_send boolean default false;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_is_sent';"):
        conn.execute("alter table ip_switch_log add email_is_sent boolean default false;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_fail_times';"):
        conn.execute("alter table ip_switch_log add email_fail_times int(11);")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_ret';"):
        conn.execute("alter table ip_switch_log add email_ret varchar(255);")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_time';"):
        conn.execute("alter table ip_switch_log add email_time datetime;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_time';"):
        conn.execute("alter table ip_switch_log add email_time datetime;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'email_send_state';"):
        conn.execute("alter table ip_switch_log add email_send_state varchar(10);")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_need_send';"):
        conn.execute("alter table ip_switch_log add phone_need_send boolean default false;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_is_sent';"):
        conn.execute("alter table ip_switch_log add phone_is_sent boolean default false;")
        conn.commit()

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_fail_times';"):
        conn.execute("alter table ip_switch_log add phone_fail_times int(11);")
        conn.commit()  
  
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_ret';"):
        conn.execute("alter table ip_switch_log add phone_ret varchar(255);")
        conn.commit()    
  
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_time';"):
        conn.execute("alter table ip_switch_log add phone_time datetime;")
        conn.commit()     
  
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'phone_send_state';"):
        conn.execute("alter table ip_switch_log add phone_send_state varchar(10);")
        conn.commit()  
  
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'content';"):
        conn.execute("alter table ip_switch_log add content text;")
        conn.commit()  

    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'ip_switch_log' AND column_name = 'id';"):
        conn.execute("alter table ip_switch_log add id bigint first;")
        conn.execute("alter table ip_switch_log change id id bigint not null auto_increment primary key;")
        conn.commit()    
  
    config = json.loads(conn.fetchone("select value from config where name='node_monitor_config' ")["value"])
    config["notification_period"] = "8-22"
    config["notify_method"] = "email sms"
    config["notify_msg_type"] = "节点IP解析 带宽监控 备用IP 备用默认解析 备用线路组"
    config["email"] = ""
    config["phone"] = ""
    conn.execute("update config set value=%s where name='node_monitor_config' ",json.dumps(config))
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
master/panel/src/views/account/personal/index.html
master/panel/src/views/account/sub/index.html
master/panel/src/views/config/cc/index.html
master/panel/src/views/config/nginx/index.html
master/panel/src/views/node/monitor/index.html
master/panel/src/views/node/monitor/switch-log.html
master/panel/src/views/node/monitor/top-res.html
master/panel/src/views/site/monitor/top-res.html
master/panel/src/views/site/site/url_ratelimit_form.html
master/panel/src/views/system/config/index.html
master/panel/src/views/system/message/index.html
master/panel/src/views/system/user/addform.html
master/panel/src/views/system/user/index.html
master/panel/src/views/user/login.html
master/panel/src/views/node/monitor/send-detail.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/stream/stream/update_form.html
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

# 定义版本
version_name="v5.1.12"
version_num="50112"
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
#supervisorctl restart all
supervisorctl reload
echo "重启完成"


# 重新获取授权
source /opt/venv/bin/activate
cd /opt/cdnfly/master/view
ret=`python -c "import util;print util.get_auth_code()" || true`
deactivate    

echo "清理文件"
rm -rf /opt/$dir_name
rm -f /opt/$tar_gz_name
echo "清理完成"

echo "完成$version_name版本升级"