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
    if not conn.fetchone("select * from cc_filter where id=10002;"):
        sql = '''
            insert into cc_filter VALUES (10002,NULL,'旋转图片60-5','内置过滤器','rotate_filter',60,5,0,'{}',now(),now(),1,1,NULL,1);
            insert into cc_rule VALUES (10003,8,NULL,'旋转图片','内置规则','[{"matcher": "3", "action": "ipset", "state": true, "filter1": "10002", "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": "旋转图片60-5"}]',now(),now(),1,1,1,NULL,1);
        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()   

    # config表openresty-config，增加rotate_html
    config = json.loads(conn.fetchone("select value from config where name='openresty-config' and type='openresty_config' and scope_name='global' ")['value'])
    config['rotate_html'] = "<html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />\n<meta name='viewport' content='width=device-width, initial-scale=1, user-scalable=no'>\n<title>安全验证</title>\n</head>\n<body>\n<style>\n@media screen and (max-width: 305px) { \n.captcha-root {max-width:100%;font-size: 16px;} \n} \n</style>\n<div class='J__captcha__'></div>\n<script src='/_guard/rotate.js'></script>\n<script>\nlet myCaptcha = document.querySelectorAll('.J__captcha__').item(0).captcha({\n  // 验证成功时显示\n  timerProgressBar: !0, // 是否启用进度条\n  timerProgressBarColor: '#07f', // 进度条颜色\n        title: '安全验证',\n  desc: '拖动滑块，使图片角度为正'  \n});\n</script>\n</body>\n</html>\n"
    conn.execute("update config set value=%s where name='openresty-config' and type='openresty_config' and scope_name='global' ",json.dumps(config))
    conn.commit()    

    # error-page增加p515
    config = json.loads(conn.fetchone("select value from config where name='error-page' and scope_name='global' ")['value'])
    config['p515'] = '\n<!DOCTYPE html>\n<!--[if lt IE 7]> <html class=\"no-js ie6 oldie\" lang=\"en-US\"> <![endif]-->\n<!--[if IE 7]>    <html class=\"no-js ie7 oldie\" lang=\"en-US\"> <![endif]-->\n<!--[if IE 8]>    <html class=\"no-js ie8 oldie\" lang=\"en-US\"> <![endif]-->\n<!--[if gt IE 8]><!--> <html class=\"no-js\" lang=\"en-US\"> <!--<![endif]-->\n<head>\n<title>套餐连接数超限</title>\n<meta charset=\"UTF-8\" />\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n<meta http-equiv=\"X-UA-Compatible\" content=\"IE=Edge,chrome=1\" />\n<meta name=\"robots\" content=\"noindex, nofollow\" />\n<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" />\n<style>\n*, body, html {\n    margin: 0;\n    padding: 0;\n}\n\nbody, html {\n    --text-opacity: 1;\n    color: #404040;\n    color: rgba(64,64,64,var(--text-opacity));\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n    font-family: system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;\n    font-size: 16px;\n}\n* {\n    box-sizing: border-box;\n}\nhtml[Attributes Style] {\n    -webkit-locale: \"en-US\";\n}\n.p-0 {\n    padding: 0;\n}\n\n\n.w-240 {\n    width: 60rem;\n}\n\n.antialiased {\n    -webkit-font-smoothing: antialiased;\n    -moz-osx-font-smoothing: grayscale;\n}\n.pt-10 {\n    padding-top: 2.5rem;\n}\n.mb-15 {\n    margin-bottom: 3.75rem;\n}\n.mx-auto {\n    margin-left: auto;\n    margin-right: auto;\n}\n\n.text-black-dark {\n    --text-opacity: 1;\n    color: #404040;\n    color: rgba(64,64,64,var(--text-opacity));\n}\n\n.mr-2 {\n    margin-right: .5rem;\n}\n.leading-tight {\n    line-height: 1.25;\n}\n.text-60 {\n    font-size: 60px;\n}\n.font-light {\n    font-weight: 300;\n}\n.inline-block {\n    display: inline-block;\n}\n\n.text-15 {\n    font-size: 15px;\n}\n.font-mono {\n    font-family: monaco,courier,monospace;\n}\n.text-gray-600 {\n    --text-opacity: 1;\n    color: #999;\n    color: rgba(153,153,153,var(--text-opacity));\n}\n.leading-1\\.3 {\n    line-height: 1.3;\n}\n.text-3xl {\n    font-size: 1.875rem;\n}\n\n.mb-8 {\n    margin-bottom: 2rem;\n}\n\n.w-1\\/2 {\n    width: 50%;\n}\n\n.mt-6 {\n    margin-top: 1.5rem;\n}\n\n.mb-4 {\n    margin-bottom: 1rem;\n}\n\n\n.font-normal {\n    font-weight: 400;\n}\n\n#what-happened-section p {\n    font-size: 15px;\n    line-height: 1.5;\n}\n\n</style>\n\n</head>\n<body>\n  <div id=\"cf-wrapper\">\n    <div id=\"cf-error-details\" class=\"p-0\">\n      <header class=\"mx-auto pt-10 lg:pt-6 lg:px-8 w-240 lg:w-full mb-15 antialiased\">\n         <h1 class=\"inline-block md:block mr-2 md:mb-2 font-light text-60 md:text-3xl text-black-dark leading-tight\">\n           <span data-translate=\"error\">Error</span>\n           <span>515</span>\n         </h1>\n         <span class=\"inline-block md:block heading-ray-id font-mono text-15 lg:text-sm lg:leading-relaxed\">您的IP: {client_ip} &bull;</span>\n         <span class=\"inline-block md:block heading-ray-id font-mono text-15 lg:text-sm lg:leading-relaxed\">节点IP: {node_ip}</span>\n        <h2 class=\"text-gray-600 leading-1.3 text-3xl lg:text-2xl font-light\">套餐连接数超限</h2>\n      </header>\n\n      <section class=\"w-240 lg:w-full mx-auto mb-8 lg:px-8\">\n          <div id=\"what-happened-section\" class=\"w-1/2 md:w-full\">\n            <h2 class=\"text-3xl leading-tight font-normal mb-4 text-black-dark antialiased\" data-translate=\"what_happened\">什么问题?</h2>\n            <p>您的套餐连接数超限。</p>\n            \n          </div>\n\n          \n          <div id=\"resolution-copy-section\" class=\"w-1/2 mt-6 text-15 leading-normal\">\n            <h2 class=\"text-3xl leading-tight font-normal mb-4 text-black-dark antialiased\" data-translate=\"what_can_i_do\">如何解决?</h2>\n            <p>请联系管理员。</p>\n          </div>\n          \n      </section>\n\n      <div class=\"cf-error-footer cf-wrapper w-240 lg:w-full py-10 sm:py-4 sm:px-8 mx-auto text-center sm:text-left border-solid border-0 border-t border-gray-300\">\n\n</div><!-- /.error-footer -->\n\n\n    </div><!-- /#cf-error-details -->\n  </div><!-- /#cf-wrapper -->\n\n\n</body>\n</html>\n\n';
    conn.execute("update config set value=%s where name='error-page'  and scope_name='global' ",json.dumps(config))
    conn.commit()



except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 更新panel或conf

flist='master/conf/nginx_global.tpl
master/conf/nginx_http_default.tpl
master/conf/nginx_http_vhost.tpl
master/panel/console/index.html
master/panel/src/views/config/cc/index.html
master/panel/src/views/config/error/index.html
master/panel/src/views/package/basic/assign.html
master/panel/src/views/package/basic/index.html
master/panel/src/views/package/monitor/index.html
master/panel/src/views/site/site/edit.html
'

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
version_name="v5.1.2"
version_num="50102"
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