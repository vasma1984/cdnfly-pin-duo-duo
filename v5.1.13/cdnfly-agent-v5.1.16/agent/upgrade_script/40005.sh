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
version_name="v4.0.5"
version_num="40005"
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

echo "执行升级命令..."

# 增加lua_shared_dict healthcheck 100m
if [[ `grep  "lua_shared_dict healthcheck" /usr/local/openresty/nginx/conf/nginx.conf` == "" ]]; then
    sed -i '/init_by_lua_file/i\lua_shared_dict healthcheck 100m;' /usr/local/openresty/nginx/conf/nginx.conf
fi

# 增加auto_switch = {"enable":True, "qps_50x":50,"qps_total":1000,"rule":"2","seconds":300}
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/openresty.json") as fp:
    data = fp.read()

openresty = json.loads(data)
openresty['auto_switch'] = {"enable":True, "qps_50x":50,"qps_total":1000,"rule":"2","seconds":300}

with open("/usr/local/openresty/nginx/conf/vhost/openresty.json","w") as fp:
    fp.write(json.dumps(openresty))

EOF

/opt/venv/bin/python /tmp/_db.py

# 增加内置规则
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_rule.json") as fp:
    data = fp.read()

cc_rule = json.loads(data)
cc_rule["1"] = {"data":[{"matcher":"2","action":"ipset","state":True,"filter1":"6","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-15-10"},{"matcher":"1","action":"ipset","state":True,"filter1":"8","filter2_name":"","filter2":"","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","filter1_name":"\u6d4f\u89c8\u5668\u8bc6\u522b60-5"}],"ver":1}
cc_rule["2"] = {"data":[{"matcher":"2","action":"ipset","state":True,"filter1":"6","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-15-10"},{"matcher":"1","action":"ipset","state":True,"filter1":"2","filter2_name":"","filter2":"","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","filter1_name":"\u6ed1\u52a8\u8fc7\u6ee460-5"}],"ver":1}
cc_rule["3"] = {"data":[{"matcher":"2","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","state":True,"filter1":"11","filter2_name":"","filter2":"","action":"ipset","filter1_name":"\u4e34\u65f6\u767d\u540d\u5355\u4e13\u75281"},{"matcher":"1","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","state":True,"filter1":"12","filter2_name":"","filter2":"","action":"ipset","filter1_name":"\u4e34\u65f6\u767d\u540d\u5355\u4e13\u75282"}],"ver":1}
cc_rule["4"] = {"data":[{"matcher":"2","action":"ipset","state":True,"filter1":"6","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-15-10"},{"matcher":"1","action":"ipset","state":True,"filter1":"3","filter2_name":"","filter2":"","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","filter1_name":"\u9a8c\u8bc1\u780160-5"}],"ver":1}
cc_rule["5"] = {"data":[{"matcher":"3","action":"ipset","state":True,"filter1":"1","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u6240\u6709\u8d44\u6e90","filter1_name":"302\u8df3\u8f6c60-5"}],"ver":1}
cc_rule["6"] = {"data":[{"matcher":"2","action":"ipset","state":True,"filter1":"9","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-150-25"},{"matcher":"1","action":"ipset","state":True,"filter1":"10","filter2_name":"\u9a8c\u8bc1\u780160-5","filter2":"3","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-50-20"}],"ver":1}
cc_rule["7"] = {"data":[{"matcher":"2","matcher_name":"\u5339\u914d\u975ehtml\u8d44\u6e90","state":True,"filter1":"7","filter2_name":"","filter2":"","action":"ipset","filter1_name":"\u8bf7\u6c42\u901f\u73875-100-10"},{"matcher":"1","action":"ipset","state":True,"filter1":"5","filter2_name":"\u6ed1\u52a8\u8fc7\u6ee460-5","filter2":"2","matcher_name":"\u5339\u914dhtml\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-20-10"}],"ver":1}

with open("/usr/local/openresty/nginx/conf/vhost/cc_rule.json","w") as fp:
    fp.write(json.dumps(cc_rule))

EOF

/opt/venv/bin/python /tmp/_db.py

# cc_match
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json") as fp:
    data = fp.read()

cc_match = json.loads(data)
cc_match["1"] = {"ver": 1, "content_type": {"operator": "contain", "value": "text/html"}}
cc_match["2"] = {"ver": 1, "content_type": {"operator": "!contain", "value": "text/html"}}
cc_match["3"] = {"ver": 1}
cc_match["4"] = {"req_uri": {"operator": "AC", "value": [".js", ".css", ".png", ".jpg", ".jpeg", ".gif"]}, "ver": 1}
cc_match["5"] = {"ver": 1, "uri": {"operator": "AC", "value": ["slide.js", "captcha.png", "verify-captcha", "encrypt.js", "favicon.ico"]}}

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json","w") as fp:
    fp.write(json.dumps(cc_match))

EOF

/opt/venv/bin/python /tmp/_db.py

# cc_filter
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json") as fp:
    data = fp.read()

cc_filter = json.loads(data)
cc_filter["1"] = {"max_challenge": 5, "type": "302_challenge", "within_second": 60, "max_per_uri": 0, "ver": 1}
cc_filter["2"] = {"max_challenge": 5, "type": "slide_filter", "within_second": 60, "max_per_uri": 0, "ver": 1}
cc_filter["3"] = {"max_challenge": 5, "type": "captcha_filter", "within_second": 60, "max_per_uri": 0, "ver": 1}
cc_filter["4"] = {"max_challenge": 5, "ver": 1, "type": "req_rate", "max_per_uri": 0, "within_second": 60}
cc_filter["5"] = {"max_challenge": 20, "type": "req_rate", "within_second": 5, "max_per_uri": 10, "ver": 1}
cc_filter["6"] = {"max_challenge": 30, "type": "req_rate", "within_second": 5, "max_per_uri": 20, "ver": 1}
cc_filter["7"] = {"max_challenge": 100, "type": "req_rate", "within_second": 5, "max_per_uri": 10, "ver": 1}
cc_filter["8"] = {"max_challenge": 5, "type": "browser_verify_auto", "within_second": 60, "max_per_uri": 0, "ver": 1}
cc_filter["9"] = {"max_challenge": 120, "type": "req_rate", "within_second": 5, "max_per_uri": 25, "ver": 1}
cc_filter["10"] = {"max_challenge": 50, "type": "req_rate", "within_second": 5, "max_per_uri": 20, "ver": 1}
cc_filter["11"] = {"max_challenge": 120, "type": "req_rate", "within_second": 5, "max_per_uri": 15, "ver": 1}
cc_filter["12"] = {"max_challenge": 50, "type": "req_rate", "within_second": 5, "max_per_uri": 15, "ver": 1}

with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json","w") as fp:
    fp.write(json.dumps(cc_filter))

EOF

/opt/venv/bin/python /tmp/_db.py



# 修改所有网站版本为0，好让主控重新同步网站
sed -i 's/^# .*/# 0/g' /usr/local/openresty/nginx/conf/vhost/*.conf


echo "执行升级命令完成"

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



