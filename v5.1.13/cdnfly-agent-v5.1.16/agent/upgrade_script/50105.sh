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
# block_region.json生成
cd /usr/local/openresty/nginx/conf//vhost/
grep "block_region" *.conf || true > /tmp/block_region

cat > /tmp/50105.py <<EOF
# -*- coding: utf-8 -*-

import re
import json
import os       
import sys

if os.path.exists("/tmp/block_region"):
    fp = open("/tmp/block_region")
    block_region_dict = {}
    for line in fp:
        match = re.match(r'([0-9]+?).*"(.*?)".*',line)
        if not match:
            continue 

        site_id, block_region = re.match(r'([0-9]+?).*"(.*?)".*',line).groups()
        if block_region == "abrord_inc":
            block_region_dict[site_id] = {"gw": 1, "gu": 1, "gt": 1, "gr": 1, "gq": 1, "gp": 1, "gy": 1, "ge": 1, "gd": 1, "ga": 1, "gn": 1, "gm": 1, "gl": 1, "gh": 1, "lb": 1, "lc": 1, "la": 1, "tv": 1, "tw": 1, "tt": 1, "tr": 1, "lk": 1, "li": 1, "lv": 1, "to": 1, "tl": 1, "tm": 1, "tj": 1, "ls": 1, "th": 1, "tg": 1, "td": 1, "tc": 1, "ly": 1, "do": 1, "dm": 1, "dj": 1, "dk": 1, "de": 1, "ye": 1, "dz": 1, "uy": 1, "vu": 1, "qa": 1, "ai": 1, "zm": 1, "be": 1, "ee": 1, "eg": 1, "za": 1, "ec": 1, "mk": 1, "et": 1, "zw": 1, "es": 1, "er": 1, "ru": 1, "rw": 1, "rs": 1, "it": 1, "ro": 1, "bd": 1, "wf": 1, "bf": 1, "bg": 1, "ba": 1, "bb": 1, "bl": 1, "bm": 1, "bn": 1, "bo": 1, "bh": 1, "bi": 1, "bj": 1, "bt": 1, "jm": 1, "jo": 1, "ws": 1, "br": 1, "bs": 1, "tz": 1, "by": 1, "bz": 1, "om": 1, "ua": 1, "bw": 1, "ci": 1, "ch": 1, "co": 1, "cm": 1, "cl": 1, "ca": 1, "cg": 1, "cf": 1, "cd": 1, "cz": 1, "cy": 1, "cr": 1, "cw": 1, "cv": 1, "cu": 1, "ad": 1, "pr": 1, "ps": 1, "pw": 1, "pt": 1, "py": 1, "lt": 1, "uk": 1, "iq": 1, "pa": 1, "pf": 1, "pg": 1, "pe": 1, "lr": 1, "ph": 1, "pl": 1, "tk": 1, "hr": 1, "ht": 1, "hu": 1, "hk": 1, "lu": 1, "hn": 1, "ao": 1, "pk": 1, "jp": 1, "me": 1, "md": 1, "mg": 1, "mf": 1, "ma": 1, "mc": 1, "uz": 1, "mm": 1, "ml": 1, "mo": 1, "mn": 1, "us": 1, "mu": 1, "mt": 1, "mw": 1, "mv": 1, "mq": 1, "ms": 1, "mr": 1, "ug": 1, "my": 1, "mx": 1, "mz": 1, "va": 1, "vc": 1, "ae": 1, "ve": 1, "ag": 1, "af": 1, "tn": 1, "is": 1, "ir": 1, "am": 1, "al": 1, "vn": 1, "kn": 1, "as": 1, "ar": 1, "au": 1, "at": 1, "aw": 1, "in": 1, "az": 1, "ie": 1, "id": 1, "ni": 1, "nl": 1, "no": 1, "il": 1, "na": 1, "nc": 1, "ne": 1, "ng": 1, "nz": 1, "np": 1, "so": 1, "nr": 1, "nu": 1, "fr": 1, "sb": 1, "fi": 1, "fj": 1, "fm": 1, "sy": 1, "sx": 1, "kg": 1, "ke": 1, "ss": 1, "sr": 1, "ki": 1, "kh": 1, "sv": 1, "km": 1, "st": 1, "sk": 1, "kr": 1, "si": 1, "kp": 1, "kw": 1, "sn": 1, "sm": 1, "sl": 1, "sc": 1, "kz": 1, "sa": 1, "sg": 1, "se": 1, "sd": 1}

        elif block_region == "abrord_no_inc":
            block_region_dict[site_id] = {"gw": 1, "gu": 1, "gt": 1, "gr": 1, "gq": 1, "gp": 1, "gy": 1, "ge": 1, "gd": 1, "ga": 1, "gn": 1, "gm": 1, "gl": 1, "gh": 1, "lb": 1, "lc": 1, "la": 1, "tv": 1,  "tt": 1, "tr": 1, "lk": 1, "li": 1, "lv": 1, "to": 1, "tl": 1, "tm": 1, "tj": 1, "ls": 1, "th": 1, "tg": 1, "td": 1, "tc": 1, "ly": 1, "do": 1, "dm": 1, "dj": 1, "dk": 1, "de": 1, "ye": 1, "dz": 1, "uy": 1, "vu": 1, "qa": 1, "ai": 1, "zm": 1, "be": 1, "ee": 1, "eg": 1, "za": 1, "ec": 1, "mk": 1, "et": 1, "zw": 1, "es": 1, "er": 1, "ru": 1, "rw": 1, "rs": 1, "it": 1, "ro": 1, "bd": 1, "wf": 1, "bf": 1, "bg": 1, "ba": 1, "bb": 1, "bl": 1, "bm": 1, "bn": 1, "bo": 1, "bh": 1, "bi": 1, "bj": 1, "bt": 1, "jm": 1, "jo": 1, "ws": 1, "br": 1, "bs": 1, "tz": 1, "by": 1, "bz": 1, "om": 1, "ua": 1, "bw": 1, "ci": 1, "ch": 1, "co": 1, "cm": 1, "cl": 1, "ca": 1, "cg": 1, "cf": 1, "cd": 1, "cz": 1, "cy": 1, "cr": 1, "cw": 1, "cv": 1, "cu": 1, "ad": 1, "pr": 1, "ps": 1, "pw": 1, "pt": 1, "py": 1, "lt": 1, "uk": 1, "iq": 1, "pa": 1, "pf": 1, "pg": 1, "pe": 1, "lr": 1, "ph": 1, "pl": 1, "tk": 1, "hr": 1, "ht": 1, "hu": 1,  "lu": 1, "hn": 1, "ao": 1, "pk": 1, "jp": 1, "me": 1, "md": 1, "mg": 1, "mf": 1, "ma": 1, "mc": 1, "uz": 1, "mm": 1, "ml": 1, "mn": 1, "us": 1, "mu": 1, "mt": 1, "mw": 1, "mv": 1, "mq": 1, "ms": 1, "mr": 1, "ug": 1, "my": 1, "mx": 1, "mz": 1, "va": 1, "vc": 1, "ae": 1, "ve": 1, "ag": 1, "af": 1, "tn": 1, "is": 1, "ir": 1, "am": 1, "al": 1, "vn": 1, "kn": 1, "as": 1, "ar": 1, "au": 1, "at": 1, "aw": 1, "in": 1, "az": 1, "ie": 1, "id": 1, "ni": 1, "nl": 1, "no": 1, "il": 1, "na": 1, "nc": 1, "ne": 1, "ng": 1, "nz": 1, "np": 1, "so": 1, "nr": 1, "nu": 1, "fr": 1, "sb": 1, "fi": 1, "fj": 1, "fm": 1, "sy": 1, "sx": 1, "kg": 1, "ke": 1, "ss": 1, "sr": 1, "ki": 1, "kh": 1, "sv": 1, "km": 1, "st": 1, "sk": 1, "kr": 1, "si": 1, "kp": 1, "kw": 1, "sn": 1, "sm": 1, "sl": 1, "sc": 1, "kz": 1, "sa": 1, "sg": 1, "se": 1, "sd": 1}

        elif block_region == "china_inc":
            block_region_dict[site_id] = {"cn":1, "hk":1,"tw":1,"mo":1}

        elif block_region == "china_not_inc":
            block_region_dict[site_id] = {"cn":1}

    with open("/usr/local/openresty/nginx/conf/vhost/block_region.json","w") as fp:
        fp.write(json.dumps(block_region_dict))

def transform_op_value(op, value):
    if op in ["=","!="]:
        lines = value.split("\n")
        if len(lines) > 1:
            v = []
            for l in lines:
                l = re.escape(l)
                v.append(l)

            value = "^({v})$".format(v="|".join(v).encode('utf-8'))
            op = op.replace("=","regex")

        return op, value

    elif op in ["contain","!contain"]:
        lines = value.split("\n")
        if len(lines) > 1:
            v = []
            for l in lines:
                l = re.escape(l)
                v.append(l)

            value = "{v}".format(v="|".join(v).encode('utf-8'))
            op = op.replace("contain","regex")

        return op, value

    elif op == "suffix":
        lines = value.split("\n")

        v = []
        for l in lines:
            l = re.escape(l)
            v.append(l)

        value = "({v})$".format(v="|".join(v).encode('utf-8'))

        return "regex", value

    elif op == "prefix":
        lines = value.split("\n")

        v = []
        for l in lines:
            l = re.escape(l)
            v.append(l)

        value = "^({v})".format(v="|".join(v).encode('utf-8'))

        return "regex", value

    else:
        return op, value

# acl.json转换
# 原{"1": {"default_action": "allow", "acl_data": [{"acl_action": "allow", "acl_matcher": {"ip": {"operator": "AC", "value": ["aa","bb"]}}}], "ver": 1}}
# 新{"1": {"default_action": "allow", "acl_data": [{"acl_action": "allow", "acl_matcher": {"ip": {"operator": "contain", "value": "aa\nbb"}}}], "ver": 1}}
# 新{"1": {"default_action": "allow", "acl_data": [{"acl_action": "allow", "acl_matcher": {"ip": {"operator": "regex", "value": "aa\nbb"}}}], "ver": 1}}

if os.path.exists("/usr/local/openresty/nginx/conf/vhost/acl.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/acl.json") as fp:
        acl_content = json.loads(fp.read())
        for site_id in acl_content:
            acl_data = acl_content[site_id]["acl_data"]
            for i in range(len(acl_data)):
                acl_matcher = acl_data[i]["acl_matcher"]
                for item in acl_matcher:
                    operator = acl_matcher[item]["operator"]
                    value = acl_matcher[item]["value"]
                    if operator in ["AC","!AC"]:
                        operator = operator.replace("AC","contain")
                        value = "\n".join(value)
                        operator, value = transform_op_value(operator,value)
                        acl_content[site_id]["acl_data"][i]["acl_matcher"][item]["operator"] = operator
                        acl_content[site_id]["acl_data"][i]["acl_matcher"][item]["value"] = value


    with open("/usr/local/openresty/nginx/conf/vhost/acl.json","w") as fp:
        fp.write(json.dumps(acl_content))

# cc_match.json转换
# 原 {"4":{"req_uri":{"operator":"AC","value":[".js",".css",".png",".jpg",".jpeg",".gif"]},"ver":1}}
# 新 {"4":{"req_uri":{"operator":"contain","value":".js\n.css\n.png\n.jpg\n.jpeg\n.gif"},"ver":1}}
# 新 {"4":{"req_uri":{"operator":"regex","value":"\\.js|\\.css|\\.png|\\.jpg|\\.jpeg|\\.gif"},"ver":2}}

if os.path.exists("/usr/local/openresty/nginx/conf/vhost/cc_match.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json") as fp:
        match_content = json.loads(fp.read())
        for match_id in match_content:
            match_rule = match_content[match_id]
            for item in match_rule:
                if item == "ver":
                    continue

                operator = match_rule[item]["operator"]
                value = match_rule[item]["value"]
                if operator in ["AC","!AC"]:
                    operator = operator.replace("AC","contain")
                    value = "\n".join(value)
                    operator, value = transform_op_value(operator,value)
                    match_content[match_id][item]["operator"] = operator
                    match_content[match_id][item]["value"] = value

    with open("/usr/local/openresty/nginx/conf/vhost/cc_match.json","w") as fp:
        fp.write(json.dumps(match_content))


# extra_cc_rule.json 转换
# 原 {"1":{"4":[{"matcher":{"req_uri":{"operator":"AC","value":["/dir"]}},"matcher_name":"url-ratelimit","state":true,"filter1":{"max_challenge":111,"within_second":10,"type":"req_rate","max_per_uri":111,"extra":{}},"filter2_name":"","filter2":"","action":"ipset","filter1_name":"url-ratelimit"},{"matcher":"3","action":"ipset","state":true,"filter1":"3","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u6240\u6709\u8d44\u6e90","filter1_name":"\u9a8c\u8bc1\u780160-5"}],"6":[{"matcher":{"req_uri":{"operator":"AC","value":["/dir"]}},"matcher_name":"url-ratelimit","state":true,"filter1":{"max_challenge":111,"within_second":10,"type":"req_rate","max_per_uri":111,"extra":{}},"filter2_name":"","filter2":"","action":"ipset","filter1_name":"url-ratelimit"},{"matcher":"3","action":"ipset","state":true,"filter1":"9","filter2_name":"","filter2":"","matcher_name":"\u5339\u914d\u6240\u6709\u8d44\u6e90","filter1_name":"\u8bf7\u6c42\u901f\u73875-300-50"}]}}

if os.path.exists("/usr/local/openresty/nginx/conf/vhost/extra_cc_rule.json"):
    with open("/usr/local/openresty/nginx/conf/vhost/extra_cc_rule.json") as fp:
        extra_cc_content = json.loads(fp.read())
    
    for site_id in extra_cc_content:
        rules = extra_cc_content[site_id]
        for rule_id in rules:
            rule = rules[rule_id]
            for i in range(len(rule)):
                matcher = rule[i]["matcher"]
                if isinstance(matcher, dict):
                    for item in matcher:
                        operator = matcher[item]["operator"]
                        value = matcher[item]["value"]
                        if operator in ["AC","!AC"]:
                            operator = operator.replace("AC","contain")
                            value = "\n".join(value)
                            operator, value = transform_op_value(operator,value) 
                            extra_cc_content[site_id][rule_id][i]["matcher"][item]["operator"] = operator
                            extra_cc_content[site_id][rule_id][i]["matcher"][item]["value"] = value

    with open("/usr/local/openresty/nginx/conf/vhost/extra_cc_rule.json","w") as fp:
        fp.write(json.dumps(extra_cc_content))


EOF
python /tmp/50105.py

# ipv6
# 添加cdnfly ipset ipv6
if ! ipset list cdnfly_v6 > /dev/null 2>&1; then
    ipset create cdnfly_v6 hash:net family inet6 maxelem 10000000 timeout 3600
fi

if ! ipset list cdnfly_white_v6 > /dev/null 2>&1; then
    ipset create cdnfly_white_v6 hash:net family inet6 maxelem 10000000 timeout 0
fi

if ! ipset list cdnfly_black_v6 > /dev/null 2>&1; then
    ipset create cdnfly_black_v6 hash:net family inet6 maxelem 10000000 timeout 0
fi

# 添加iptables v6
if [[ $(ip6tables -t filter -S INPUT 1 | grep -- '-A INPUT -m set --match-set cdnfly_white_v6 src -j ACCEPT') == "" ]];then
    ip6tables -D INPUT -m set --match-set cdnfly_v6 src -j DROP || true
    ip6tables -D INPUT -m set --match-set cdnfly_black_v6 src -j DROP || true
    ip6tables -D INPUT -m set --match-set cdnfly_white_v6 src -j ACCEPT || true
    

    ip6tables -I INPUT -m set --match-set cdnfly_v6 src -j DROP || true
    ip6tables -I INPUT -m set --match-set cdnfly_black_v6 src -j DROP || true
    ip6tables -I INPUT -m set --match-set cdnfly_white_v6 src -j ACCEPT || true
fi
    
}

update_file() {
cd /opt/$dir_name/
for i in `find ./ | grep -vE "conf/config.py|conf/filebeat.yml|^./agent/conf$|^./$|^./agent$"`;do
    \cp -aT $i /opt/cdnfly/$i
done

}


# 定义版本
version_name="v5.1.5"
version_num="50105"
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



