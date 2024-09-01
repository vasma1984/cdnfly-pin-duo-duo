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

start_on_boot(){
    local cmd="$1"
    if [[ -f "/etc/rc.local" ]]; then
        sed -i '/exit 0/d' /etc/rc.local
        if [[ `grep "${cmd}" /etc/rc.local` == "" ]];then 
            echo "${cmd}" >> /etc/rc.local
        fi 
        chmod +x /etc/rc.local
    fi


    if [[ -f "/etc/rc.d/rc.local" ]]; then
        sed -i '/exit 0/d' /etc/rc.d/rc.local
        if [[ `grep "${cmd}" /etc/rc.d/rc.local` == "" ]];then 
            echo "${cmd}" >> /etc/rc.d/rc.local
        fi 
        chmod +x /etc/rc.d/rc.local 
    fi 
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

force_restart() {
    ps aux | grep [n]ginx | awk '{print $2}' | xargs kill || true
    sleep 2
    ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9 || true
    sleep 2
    rm -f /var/run/nginx.sock
    /usr/local/openresty/nginx/sbin/nginx    
}

upgrade_cmd() {

# openresty.json文件，增加rotate_html
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
    openresty['rotate_html'] = "<html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />\n<meta name='viewport' content='width=device-width, initial-scale=1, user-scalable=no'>\n<title>安全验证</title>\n</head>\n<body>\n<style>\n@media screen and (max-width: 305px) { \n.captcha-root {max-width:100%;font-size: 16px;} \n} \n</style>\n<div class='J__captcha__'></div>\n<script src='/_guard/rotate.js'></script>\n<script>\nlet myCaptcha = document.querySelectorAll('.J__captcha__').item(0).captcha({\n  // 验证成功时显示\n  timerProgressBar: !0, // 是否启用进度条\n  timerProgressBarColor: '#07f', // 进度条颜色\n        title: '安全验证',\n  desc: '拖动滑块，使图片角度为正'  \n});\n</script>\n</body>\n</html>\n"
    
    with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
        fp.write(json.dumps(openresty))
        
EOF

/opt/venv/bin/python /tmp/_db.py

# 在listen_80.conf listen_other.conf和vhost增加旋转图片的配置
if [[ -f "/usr/local/openresty/nginx/conf/listen_80.conf" ]];then
    if [[ `grep "__rotate_img__" /usr/local/openresty/nginx/conf/listen_80.conf` == ""  ]];then
        sed -i '/more_set_headers "Content-Type/a\location ~ /guard/__rotate_img__/ {\ninternal;\nmore_set_headers "Content-Type: image/jpeg";\nrewrite /guard/__rotate_img__/(.*) /$1 break;\nroot /opt/cdnfly/nginx/conf/rotate/;\n}' /usr/local/openresty/nginx/conf/listen_80.conf
    fi
fi

if [[ -f "/usr/local/openresty/nginx/conf/listen_other.conf" ]];then
    if [[ `grep "__rotate_img__" /usr/local/openresty/nginx/conf/listen_other.conf` == ""  ]];then
        sed -i '/more_set_headers "Content-Type/a\location ~ /guard/__rotate_img__/ {\ninternal;\nmore_set_headers "Content-Type: image/jpeg";\nrewrite /guard/__rotate_img__/(.*) /$1 break;\nroot /opt/cdnfly/nginx/conf/rotate/;\n}' /usr/local/openresty/nginx/conf/listen_other.conf
    fi
fi

# 下载rotate.tar.gz到/opt/cdnfly/nginx/conf，并解压
cd /opt/cdnfly/nginx/conf
download "https://dl2.cdnfly.cn/cdnfly/rotate.tar.gz" "https://us.centos.bz/cdnfly/rotate.tar.gz" "rotate.tar.gz"
tar xf rotate.tar.gz
rm -f rotate.tar.gz

# vhost增加515
cd /usr/local/openresty/nginx/conf/vhost/
sed -i 's#/(403|502|504|512|513|514).err#/(403|502|504|512|513|514|515).err#' *.conf || true

# nginx.conf增加515
sed -i '/514.err/a\error_page 515             /515.err;' /usr/local/openresty/nginx/conf/nginx.conf

# 生成515.html
cat > /usr/local/openresty/nginx/conf/vhost/515.html <<EOF

<!DOCTYPE html>
<!--[if lt IE 7]> <html class="no-js ie6 oldie" lang="en-US"> <![endif]-->
<!--[if IE 7]>    <html class="no-js ie7 oldie" lang="en-US"> <![endif]-->
<!--[if IE 8]>    <html class="no-js ie8 oldie" lang="en-US"> <![endif]-->
<!--[if gt IE 8]><!--> <html class="no-js" lang="en-US"> <!--<![endif]-->
<head>
<title>套餐连接数超限</title>
<meta charset="UTF-8" />
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1" />
<meta name="robots" content="noindex, nofollow" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<style>
*, body, html {
    margin: 0;
    padding: 0;
}

body, html {
    --text-opacity: 1;
    color: #404040;
    color: rgba(64,64,64,var(--text-opacity));
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    font-family: system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;
    font-size: 16px;
}
* {
    box-sizing: border-box;
}
html[Attributes Style] {
    -webkit-locale: "en-US";
}
.p-0 {
    padding: 0;
}


.w-240 {
    width: 60rem;
}

.antialiased {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}
.pt-10 {
    padding-top: 2.5rem;
}
.mb-15 {
    margin-bottom: 3.75rem;
}
.mx-auto {
    margin-left: auto;
    margin-right: auto;
}

.text-black-dark {
    --text-opacity: 1;
    color: #404040;
    color: rgba(64,64,64,var(--text-opacity));
}

.mr-2 {
    margin-right: .5rem;
}
.leading-tight {
    line-height: 1.25;
}
.text-60 {
    font-size: 60px;
}
.font-light {
    font-weight: 300;
}
.inline-block {
    display: inline-block;
}

.text-15 {
    font-size: 15px;
}
.font-mono {
    font-family: monaco,courier,monospace;
}
.text-gray-600 {
    --text-opacity: 1;
    color: #999;
    color: rgba(153,153,153,var(--text-opacity));
}
.leading-1\.3 {
    line-height: 1.3;
}
.text-3xl {
    font-size: 1.875rem;
}

.mb-8 {
    margin-bottom: 2rem;
}

.w-1\/2 {
    width: 50%;
}

.mt-6 {
    margin-top: 1.5rem;
}

.mb-4 {
    margin-bottom: 1rem;
}


.font-normal {
    font-weight: 400;
}

#what-happened-section p {
    font-size: 15px;
    line-height: 1.5;
}

</style>

</head>
<body>
  <div id="cf-wrapper">
    <div id="cf-error-details" class="p-0">
      <header class="mx-auto pt-10 lg:pt-6 lg:px-8 w-240 lg:w-full mb-15 antialiased">
         <h1 class="inline-block md:block mr-2 md:mb-2 font-light text-60 md:text-3xl text-black-dark leading-tight">
           <span data-translate="error">Error</span>
           <span>515</span>
         </h1>
         <span class="inline-block md:block heading-ray-id font-mono text-15 lg:text-sm lg:leading-relaxed">您的IP: {client_ip} &bull;</span>
         <span class="inline-block md:block heading-ray-id font-mono text-15 lg:text-sm lg:leading-relaxed">节点IP: {node_ip}</span>
        <h2 class="text-gray-600 leading-1.3 text-3xl lg:text-2xl font-light">套餐连接数超限</h2>
      </header>

      <section class="w-240 lg:w-full mx-auto mb-8 lg:px-8">
          <div id="what-happened-section" class="w-1/2 md:w-full">
            <h2 class="text-3xl leading-tight font-normal mb-4 text-black-dark antialiased" data-translate="what_happened">什么问题?</h2>
            <p>您的套餐连接数超限。</p>
            
          </div>

          
          <div id="resolution-copy-section" class="w-1/2 mt-6 text-15 leading-normal">
            <h2 class="text-3xl leading-tight font-normal mb-4 text-black-dark antialiased" data-translate="what_can_i_do">如何解决?</h2>
            <p>请联系管理员。</p>
          </div>
          
      </section>

      <div class="cf-error-footer cf-wrapper w-240 lg:w-full py-10 sm:py-4 sm:px-8 mx-auto text-center sm:text-left border-solid border-0 border-t border-gray-300">

</div><!-- /.error-footer -->


    </div><!-- /#cf-error-details -->
  </div><!-- /#cf-wrapper -->


</body>
</html>
EOF



}

update_file() {
cd /opt/$dir_name/
for i in `find ./ | grep -vE "conf/config.py|conf/filebeat.yml|^./agent/conf$|^./$|^./agent$"`;do
    \cp -aT $i /opt/cdnfly/$i
done

}


# 定义版本
version_name="v5.1.1"
version_num="50101"
dir_name="cdnfly-agent-$version_name"
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

###########
echo "执行升级命令..."
upgrade_cmd
echo "执行升级命令完成"
###########

echo "更新文件..."
update_file
echo "更新文件完成."

echo "开始重启agent..."

echo "修改config.py版本..."
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" /opt/cdnfly/agent/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" /opt/cdnfly/agent/conf/config.py
echo "修改完成"

#supervisorctl reload
supervisorctl restart agent
supervisorctl restart task
supervisorctl restart filebeat
ps aux  | grep [/]usr/local/openresty/nginx/sbin/nginx | awk '{print $2}' | xargs kill -HUP || true
# 重启nginx

# ps aux | grep [n]ginx | awk '{print $2}' | xargs kill || true
# sleep 2
# ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9 || true
# /usr/local/openresty//nginx/sbin/nginx

echo "重启完成"


echo "清理文件"
rm -rf /opt/$dir_name
rm -f /opt/$tar_gz_name
echo "清理完成"

echo "完成$version_name版本升级"



