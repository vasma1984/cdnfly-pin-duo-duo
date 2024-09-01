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
    # 重置匹配器5
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json") as fp:
    data = fp.read()

cc_match = json.loads(data)
cc_match["5"] = {"ver":1, "uri":{"operator":"AC","value":["/_guard/slide.js", "/_guard/captcha.png","/_guard/verify-captcha","/_guard/encrypt.js","favicon.ico"]}}

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json","w") as fp:
    fp.write(json.dumps(cc_match))

EOF

/opt/venv/bin/python /tmp/_db.py


    #遍历所有规则组的所有规则，删除content_type的规则，如果content_type的过滤器有非请求频率的，添加一条匹配所有，过滤器为非请求频率的规则。如果都是请求频率的话，添加一条匹配所有，过滤器为9的规则
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
import json
reload(sys) 
sys.setdefaultencoding('utf8')

with open("/usr/local/openresty/nginx/conf/vhost/cc_rule.json") as fp:
    data = fp.read()

cc_rule = json.loads(data)

with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json") as fp:
    data = fp.read()

cc_match = json.loads(data)

with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json") as fp:
    data = fp.read()

cc_filter = json.loads(data)
cc_filter["4"] = {"within_second": 60, "ver": 1, "extra": {}, "max_challenge": 20, "max_per_uri": 15, "type": "req_rate"}
with open("/usr/local/openresty/nginx/conf/vhost/cc_filter.json","w") as fp:
    fp.write(json.dumps(cc_filter))


for rid in cc_rule:
    rdata = cc_rule[rid]['data']
    has_content_type = False
    new_filter1 = "9"
    new_rules = []
    for j in rdata:
        matcher = j['matcher']
        filter1 = j['filter1']
        matcher_data = cc_match[matcher]
        filter_data = cc_filter[filter1]
        filter1_type = filter_data['type']
        filter1_name = filter1
        if "content_type" in matcher_data:
            has_content_type = True
        else:
            new_rules.append(j)

        if filter1_type != "req_rate":
            new_filter1 = filter1

    if has_content_type:
        new_rules.append({"matcher": "3", "action": "ipset", "state": True, "filter1": new_filter1, "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": filter1_name})
        cc_rule[rid]['data'] = new_rules

# 临时白名单
cc_rule["3"] = {"ver":1,"data": [{"matcher": "3", "matcher_name": "匹配所有资源", "state": True, "filter1": "11", "filter2_name": "", "filter2": "", "action": "ipset", "filter1_name": "临时白名单专用1"}]}

with open("/usr/local/openresty/nginx/conf/vhost/cc_rule.json","w") as fp:
    fp.write(json.dumps(cc_rule))


EOF

/opt/venv/bin/python /tmp/_db.py

echo '{}' > /usr/local/openresty/nginx/conf/vhost/extra_cc_rule.json 
}

# 定义版本
version_name="v4.1.1"
version_num="40101"
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
upgrade_cmd
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



