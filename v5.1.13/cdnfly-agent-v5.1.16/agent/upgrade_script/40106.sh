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
    # 安装redis和flask_compress
    source /opt/venv/bin/activate
    pip install redis -i https://mirrors.aliyun.com/pypi/simple
    pip install flask_compress -i https://mirrors.aliyun.com/pypi/simple
    deactivate

    # 修改openresty.json
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import json
import os

# 点击和5秒盾的html
if os.path.exists("/usr/local/openresty/nginx/conf/vhost/openresty.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json") as fp:
        data = fp.read()

    openresty = json.loads(data)
    openresty['delay_jump_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:460px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n#second {color:red;}\n.alert {text-align:center}\n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n.alert-success {\n    color: #3c763d;\n    background-color: #dff0d8;\n    border-color: #d6e9c6;\n}\n.alert {\n    padding: 15px;\n    margin-bottom: 20px;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n.glyphicon {\n    position: relative;\n    top: 1px;\n    display: inline-block;\n    font-family: 'Glyphicons Halflings';\n    font-style: normal;\n    font-weight: 400;\n    line-height: 1;\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span style=\"font-size: 15px;\">浏览器安全检查中，系统将在<span id=\"second\">5</span>秒后返回网站</span>\n</div>\n\n</div>\n<script type='text/javascript' src='/_guard/encrypt.js'></script>\n<script type='text/javascript' src='/_guard/delay_jump.js'></script>\n</body>\n</html>"
    openresty['click_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:460px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n.alert {text-align:center}\n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n.alert-success {\n    color: #3c763d;\n    background-color: #dff0d8;\n    border-color: #d6e9c6;\n}\n.alert {\n    padding: 15px;\n    margin-bottom: 20px;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n.glyphicon {\n    position: relative;\n    top: 1px;\n    display: inline-block;\n    font-family: 'Glyphicons Halflings';\n    font-style: normal;\n    font-weight: 400;\n    line-height: 1;\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n}\n.btn-success {\n    color: #fff;\n    background-color: #5cb85c;\n    border-color: #4cae4c;\n}\n.btn {\n    display: inline-block;\n    padding: 6px 12px;\n    margin-bottom: 0;\n    font-size: 14px;\n    font-weight: 400;\n    line-height: 1.42857143;\n    text-align: center;\n    white-space: nowrap;\n    vertical-align: middle;\n    -ms-touch-action: manipulation;\n    touch-action: manipulation;\n    cursor: pointer;\n    -webkit-user-select: none;\n    -moz-user-select: none;\n    -ms-user-select: none;\n    user-select: none;\n    background-image: none;\n    border: 1px solid transparent;\n    border-radius: 4px;\n}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span style=\"font-size: 15px;\"> 网站当前访问量较大，请点击按钮继续访问</span><br>\n    <input style=\"margin-top: 20px;\" id=\"access\" type=\"botton\" class=\"btn btn-success\" value=\"进入网站\">\n</div>\n\n</div>\n<script type='text/javascript' src='/_guard/encrypt.js'></script>\n<script type='text/javascript' src='/_guard/click.js'></script>\n</body>\n</html>"
    
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
        fp.write(json.dumps(openresty))
        
EOF

/opt/venv/bin/python /tmp/_db.py

}

# 定义版本
version_name="v4.1.6"
version_num="40106"
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

\cp  cdnfly/agent/conf/td-agent.conf $dir_name/agent/conf/td-agent.conf
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
supervisorctl restart agent
supervisorctl restart task
/usr/local/openresty/nginx/sbin/nginx -s reload
echo "重启完成"
echo "完成$version_name版本升级"



