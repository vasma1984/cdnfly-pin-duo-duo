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

upgrade_cmd() {
  # openresty.json加key
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/agent/")
from conf.config import ES_PWD
import json
reload(sys) 
import os
sys.setdefaultencoding('utf8')


if os.path.exists("/usr/local/openresty/nginx/conf/vhost/openresty.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json") as fp:
        data = fp.read()

    openresty = json.loads(data)
    openresty['key'] = ES_PWD
    openresty['captcha_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<link rel=\"stylesheet\" href=\"//apps.bdimg.com/libs/bootstrap/3.3.4/css/bootstrap.min.css\">\n<script type=\"text/javascript\" src=\"//apps.bdimg.com/libs/jquery/1.7.2/jquery.min.js\"></script>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:560px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span class=\"sr-only\">Error:</span>\n  &nbsp;网站当前访问量较大，请输入验证码后继续访问\n</div>\n<form class=\"form-inline\">\n<div class=\"panel panel-success\">\n  <div class=\"panel-body\">\n  <div class=\"row\">\n  <div class=\"col-md-3\"><div class=\"txts\">请输入验证码</div></div>\n  <div class=\"col-md-9\">\n  <div class=\"bds row\">\n  请输入图片中的验证码，不区分大小写<br>\n  <input type=\"text\" name=\"response\" class=\"form-control\" id=\"response\"  style=\"width:40%;display:inline;\">&nbsp;\n  <span style=\"width:60px\" id=\"captcha\" class=\"yz\"  alt=\"Captcha image\"><img class=\"captcha-code\" src=\"/_guard/captcha.png\"></span>&nbsp;<span><a class=\"refresh-captcha-code\">换一个</a></span>\n  <p><span style=\"color:red\" id=\"notice\"></span></p>\n  </div>\n  </div>\n  </div> \n  </div>\n   <div class=\"panel-footer\"><input id=\"access\" type=\"botton\" class=\"btn btn-success\" value=\"进入网站\" /></div>\n</div>\n</form>\n</div>\n<script language=\"javascript\" type=\"text/javascript\">\n\n    $(\".refresh-captcha-code\").click(function() {\n        $(\".captcha-code\").attr(\"src\",\"/_guard/captcha.png?r=\" + Math.random());\n    });\n\n    $(\"#access\").click(function(e){\n      var response = $(\"#response\").val();\n      document.cookie = \"guardret=\"+response\n      window.location.reload();\n    });\n\n</script>\n</body>\n</html>"
    
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
        fp.write(json.dumps(openresty))
        
EOF

/opt/venv/bin/python /tmp/_db.py

# nginx.conf
sed -i "s/keep-alive/''/" /usr/local/openresty/nginx/conf/nginx.conf

# rsyslog
cat > /etc/rsyslog.d/cdnfly.conf <<'EOF'

    $ModLoad imudp
    $UDPServerRun 514
    $Umask 0000
    :msg,contains,"[cdnfly" /var/log/cdnfly.log
    $Umask 0022
    $EscapeControlCharactersOnReceive off
EOF

service rsyslog restart || true

mkdir -p /var/log/cdnfly/    

}

# 定义版本
version_name="v4.2.0"
version_num="40200"
dir_name="cdnfly-agent-$version_name"
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

echo "复制config.py td-agent.conf配置文件到新版本目录..."
\cp  cdnfly/agent/conf/config.py $dir_name/agent/conf/config.py
sed -i "s/VERSION_NAME.*/VERSION_NAME=\"$version_name\"/" $dir_name/agent/conf/config.py
sed -i "s/VERSION_NUM.*/VERSION_NUM=\"$version_num\"/" $dir_name/agent/conf/config.py

\cp  cdnfly/agent/conf/filebeat.yml $dir_name/agent/conf/filebeat.yml
echo "复制完成"

###########
echo "执行升级命令..."
upgrade_cmd
echo "执行升级命令完成"
###########

echo "软链接到新版本"
cd /opt
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启agent..."

# supervisorctl reload
supervisorctl restart agent
supervisorctl restart task
supervisorctl restart filebeat
/usr/local/openresty/nginx/sbin/nginx -s reload
# 重启nginx

# killall nginx || true
# sleep 2
# ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9 || true
# /usr/local/openresty//nginx/sbin/nginx

echo "重启完成"
echo "完成$version_name版本升级"



