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

# 定义版本
version_name="v4.0.7"
version_num="40007"
dir_name="cdnfly-agent-$version_name"
tar_gz_name="$dir_name-$(get_sys_ver).tar.gz"

# 下载安装包
cd /opt
echo "开始下载$tar_gz_name..."
download "http://10268950.d.yyupload.com/down/10268950/cdnfly/$tar_gz_name" "http://us.centos.bz/cdnfly/$tar_gz_name" "$tar_gz_name"
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

# 修改所有网站版本为0，好让主控重新同步网站
sed -i 's/^# .*/# 0/g' /usr/local/openresty/nginx/conf/vhost/*.conf || true

# 修复cc-filter 4
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json") as fp:
    data = fp.read()

cc_filter = json.loads(data)
cc_filter["4"] = {"max_challenge": 10, "ver": 1, "type": "req_rate", "max_per_uri": 10, "within_second": 60}


with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json","w") as fp:
    fp.write(json.dumps(cc_filter))

EOF

/opt/venv/bin/python /tmp/_db.py

# 增加cc-match 5
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json") as fp:
    data = fp.read()

cc_match = json.loads(data)
cc_match["5"] = {"ver":1,"uri":{"operator":"AC","value":["slide.js","captcha.png","verify-captcha","encrypt.js","favicon.ico"]}}


with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json","w") as fp:
    fp.write(json.dumps(cc_match))

EOF

/opt/venv/bin/python /tmp/_db.py

# 给sh权限
chmod +x /opt/cdnfly/agent/sh/*.sh

# 升级openresty.json
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/openresty.json") as fp:
    data = fp.read()

openresty = json.loads(data)
openresty['rnd_url'] = {"enable":True,"rnd_url_qps":100, "uptime":120,"in_seconds":60,"max_req":10,"last_seconds":300}

with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
    fp.write(json.dumps(openresty))

EOF

/opt/venv/bin/python /tmp/_db.py

# set-dict
curl -d '{"key":"start_time","value":0}'  --unix-socket /var/run/nginx.sock http://localhost/_guard/set-dict


echo "执行升级命令完成"
###########

echo "软链接到新版本"
cd /opt
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启agent..."
supervisorctl restart all
/usr/local/openresty/nginx/sbin/nginx -s reload
echo "重启完成"
echo "完成$version_name版本升级"



