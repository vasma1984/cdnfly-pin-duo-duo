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
    # 套餐
    sql = '''
        alter table package add websocket boolean default true after custom_cc_rule;
        alter table package add expire datetime after websocket;
        alter table package add buy_num_limit int(11) default -1 after expire;
        alter table package add id_verify boolean default false after buy_num_limit;
        alter table package add before_exp_days_renew int(11) default -1 after id_verify;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # site.https_listen，加oscp_stapling为false
    sites = conn.fetchall("select id,https_listen from site")
    for site in sites:
        https_listen = json.loads(site['https_listen'])
        if https_listen:
            https_listen['oscp_stapling'] = False
            site_id = site['id']
            conn.execute("update site set https_listen=%s where id=%s",(json.dumps(https_listen),site_id,) )

    conn.commit()

    # 注册相关和实名认证
    sql = '''
        insert into config values (85,'register_require','{"username":{"need":1},"email":{"need":1,"verify":1},"phone":{"need":0,"verify":0},"qq":{"need":0}}','system',now(),now(),1,null); 
        insert into config values (86,'user_agreement','{"title":"用户协议、法律声明和隐私政策","data":"这里填写协议内容"}','system',now(),now(),1,null); 
        insert into config values (87,'sms_config','{}','system',now(),now(),1,null); 
        insert into config values (88,'phone_captcha_templ','【cdnfly】您的验证码为{{captcha}}，在5分钟内有效。','system',now(),now(),1,null); 
        insert into config values (89,'alipay_id_auth','{}','system',now(),now(),1,null); 

        CREATE TABLE `captcha` (`id` int(11) NOT NULL AUTO_INCREMENT,`email` varchar(50) DEFAULT NULL,`phone` varchar(15) DEFAULT NULL,`captcha` varchar(10) DEFAULT NULL,`ip` varchar(18) DEFAULT NULL,`create_at` datetime DEFAULT NULL,PRIMARY KEY (`id`),KEY `idx_email` (`email`),KEY `idx_phone` (`phone`),KEY `idx_ip` (`ip`),KEY `idx_create_at` (`create_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        alter table user modify email varchar(255) DEFAULT NULL;

        alter table user add cert_id varchar(32) after qq;
        alter table user add cert_name varchar(32) after cert_id;
        alter table user add cert_no varchar(32) after cert_name;
        alter table user add cert_verified boolean default false after cert_no;
        

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 点击验证 5秒盾
    sql = '''
        alter table cc_rule add `sort` int(11) after id;
        alter table cc_rule add `is_show` boolean default 1 after enable;

        insert into cc_match values (10020, null, null, null, null,null,null,null,null,null,null);
        insert into cc_filter VALUES (10000,NULL,'点击过滤60-5','内置过滤器','click_filter',60,5,0,'{}',now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (10001,NULL,'5秒盾60-5','内置过滤器','delay_jump_filter',60,5,0,'{}',now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (10020,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        insert into cc_rule VALUES (10000,5,NULL,'点击验证','内置规则','[{"matcher": "3", "action": "ipset", "state": true, "filter1": "10000", "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": "点击过滤60-5"}]',now(),now(),1,1,1,NULL,1);
        insert into cc_rule VALUES (10001,4,NULL,'5秒盾','内置规则','[{"matcher": "3", "action": "ipset", "state": true, "filter1": "10001", "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": "5秒盾60-5"}]',now(),now(),1,1,1,NULL,1);
        insert into cc_rule VALUES (10002,1,NULL,'关闭','内置规则','[]',now(),now(),1,1,1,NULL,1);
        insert into cc_rule VALUES (10020,100,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        update cc_rule set is_show=0 where id=3;
        update cc_rule set sort=100;
        update cc_rule set sort=1 where id=10002;
        update cc_rule set sort=2 where id=6;
        update cc_rule set sort=3 where id=1;
        update cc_rule set sort=4 where id=10001;
        update cc_rule set sort=5 where id=10000;
        update cc_rule set sort=6 where id=2;
        update cc_rule set sort=7 where id=4;

        drop table black_ip;
        CREATE TABLE `black_ip` (`site_id` int(11) DEFAULT NULL,`ip` varchar(16) DEFAULT NULL,`fname` varchar(10) DEFAULT NULL,`uid` int(11) DEFAULT NULL,`exp` int(11) DEFAULT NULL,UNIQUE KEY `u_index` (`site_id`,`ip`,`fname`,`uid`),KEY `site_id_idx` (`site_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        CREATE TABLE `tmp_white_ip` (`site_id` int(11) DEFAULT NULL,`ip` varchar(16) DEFAULT NULL,`exp` int(11) DEFAULT NULL,UNIQUE KEY `u_index` (`site_id`,`ip`),KEY `site_id_idx` (`site_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 点击验证和5秒盾
    openresty = json.loads(conn.fetchone("select value from config where id=13")['value'])
    openresty['delay_jump_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:460px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n#second {color:red;}\n.alert {text-align:center}\n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n.alert-success {\n    color: #3c763d;\n    background-color: #dff0d8;\n    border-color: #d6e9c6;\n}\n.alert {\n    padding: 15px;\n    margin-bottom: 20px;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n.glyphicon {\n    position: relative;\n    top: 1px;\n    display: inline-block;\n    font-family: 'Glyphicons Halflings';\n    font-style: normal;\n    font-weight: 400;\n    line-height: 1;\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span style=\"font-size: 15px;\">浏览器安全检查中，系统将在<span id=\"second\">5</span>秒后返回网站</span>\n</div>\n\n</div>\n<script type='text/javascript' src='/_guard/encrypt.js'></script>\n<script type='text/javascript' src='/_guard/delay_jump.js'></script>\n</body>\n</html>"
    openresty['click_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:460px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n.alert {text-align:center}\n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n.alert-success {\n    color: #3c763d;\n    background-color: #dff0d8;\n    border-color: #d6e9c6;\n}\n.alert {\n    padding: 15px;\n    margin-bottom: 20px;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n.glyphicon {\n    position: relative;\n    top: 1px;\n    display: inline-block;\n    font-family: 'Glyphicons Halflings';\n    font-style: normal;\n    font-weight: 400;\n    line-height: 1;\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n}\n.btn-success {\n    color: #fff;\n    background-color: #5cb85c;\n    border-color: #4cae4c;\n}\n.btn {\n    display: inline-block;\n    padding: 6px 12px;\n    margin-bottom: 0;\n    font-size: 14px;\n    font-weight: 400;\n    line-height: 1.42857143;\n    text-align: center;\n    white-space: nowrap;\n    vertical-align: middle;\n    -ms-touch-action: manipulation;\n    touch-action: manipulation;\n    cursor: pointer;\n    -webkit-user-select: none;\n    -moz-user-select: none;\n    -ms-user-select: none;\n    user-select: none;\n    background-image: none;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span style=\"font-size: 15px;\"> 网站当前访问量较大，请点击按钮继续访问</span><br>\n    <input style=\"margin-top: 20px;\" id=\"access\" type=\"botton\" class=\"btn btn-success\" value=\"进入网站\">\n</div>\n\n</div>\n<script type='text/javascript' src='/_guard/encrypt.js'></script>\n<script type='text/javascript' src='/_guard/click.js'></script>\n</body>\n</html>"
    conn.execute("update config set value=%s where id=13",json.dumps(openresty))
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
version_name="v4.1.7"
version_num="40107"
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
supervisorctl restart all
echo "重启完成"
echo "完成$version_name版本升级"

