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
version_name="v4.0.4"
version_num="40004"
dir_name="cdnfly-master-$version_name"
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

echo "复制config.py配置文件到新版本目录..."
\cp  cdnfly/master/conf/config.py $dir_name/master/conf/config.py
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" $dir_name/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" $dir_name/master/conf/config.py
echo "复制完成"

echo "准备升级数据库..."
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from view.util import create_node_task
import pymysql
import json
reload(sys) 
sys.setdefaultencoding('utf8')

conn = Db()
try:
    sql = '''
        delete from cc_rule where id <=7;
        delete from cc_filter where id <= 12;

        insert into cc_filter VALUES (1,NULL,'302跳转60-5','内置过滤器','302_challenge',60,5,0,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (2,NULL,'滑动过滤60-5','内置过滤器','slide_filter',60,5,0,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (3,NULL,'验证码60-5','内置过滤器','captcha_filter',60,5,0,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (4,NULL,'内置请求保护60-5','内置过滤器','req_rate',60,5,0,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (5,NULL,'请求速率5-20-10','内置过滤器','req_rate',5,20,10,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (6,NULL,'请求速率5-15-10','内置过滤器','req_rate',5,15,10,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (7,NULL,'请求速率5-100-10','内置过滤器','req_rate',5,100,10,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (8,NULL,'浏览器识别60-5','内置过滤器','browser_verify_auto',60,5,0,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (9,NULL,'请求速率5-120-25','内置过滤器','req_rate',5,120,25,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (10,NULL,'请求速率5-50-20','内置过滤器','req_rate',5,50,20,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (11,NULL,'临时白名单专用1','内置过滤器','req_rate',5,120,15,now(),now(),1,1,NULL,1);
        insert into cc_filter VALUES (12,NULL,'临时白名单专用2','内置过滤器','req_rate',5,50,15,now(),now(),1,1,NULL,1);

        insert into cc_rule VALUES (1,NULL,'浏览器识别','内置规则','[{"matcher": "2", "action": "ipset", "state": true, "filter1": "6", "filter2_name": "", "filter2": "", "matcher_name": "匹配非html资源", "filter1_name": "请求速率5-15-10"}, {"matcher": "1", "action": "ipset", "state": true, "filter1": "8", "filter2_name": "", "filter2": "", "matcher_name": "匹配html资源", "filter1_name": "浏览器识别60-5"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (2,NULL,'滑动验证','内置规则','[{"matcher": "2", "action": "ipset", "state": true, "filter1": "6", "filter2_name": "", "filter2": "", "matcher_name": "匹配非html资源", "filter1_name": "请求速率5-15-10"}, {"matcher": "1", "action": "ipset", "state": true, "filter1": "2", "filter2_name": "", "filter2": "", "matcher_name": "匹配html资源", "filter1_name": "滑动过滤60-5"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (3,NULL,'临时白名单','内置规则','[{"matcher": "2", "matcher_name": "匹配非html资源", "state": true, "filter1": "11", "filter2_name": "", "filter2": "", "action": "ipset", "filter1_name": "临时白名单专用1"}, {"matcher": "1", "matcher_name": "匹配html资源", "state": true, "filter1": "12", "filter2_name": "", "filter2": "", "action": "ipset", "filter1_name": "临时白名单专用2"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (4,NULL,'验证码','内置规则','[{"matcher": "2", "action": "ipset", "state": true, "filter1": "6", "filter2_name": "", "filter2": "", "matcher_name": "匹配非html资源", "filter1_name": "请求速率5-15-10"}, {"matcher": "1", "action": "ipset", "state": true, "filter1": "3", "filter2_name": "", "filter2": "", "matcher_name": "匹配html资源", "filter1_name": "验证码60-5"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (5,NULL,'302跳转','内置规则','[{"matcher": "3", "action": "ipset", "state": true, "filter1": "1", "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": "302跳转60-5"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (6,NULL,'宽松模式','内置规则','[{"matcher": "2", "action": "ipset", "state": true, "filter1": "9", "filter2_name": "", "filter2": "", "matcher_name": "匹配非html资源", "filter1_name": "请求速率5-120-25"}, {"matcher": "1", "action": "ipset", "state": true, "filter1": "10", "filter2_name": "验证码60-5", "filter2": "3", "matcher_name": "匹配html资源", "filter1_name": "请求速率5-50-20"}]',now(),now(),1,1,NULL,1);
        insert into cc_rule VALUES (7,NULL,'请求频率','内置规则','[{"matcher": "2", "matcher_name": "匹配非html资源", "state": true, "filter1": "7", "filter2_name": "", "filter2": "", "action": "ipset", "filter1_name": "请求速率5-100-10"}, {"matcher": "1", "action": "ipset", "state": true, "filter1": "5", "filter2_name": "滑动过滤60-5", "filter2": "2", "matcher_name": "匹配html资源", "filter1_name": "请求速率5-20-10"}]',now(),now(),1,1,NULL,1);

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())

    conn.commit()

    # 创建任务
    task_id = create_node_task(conn, "cc_rule", "同步", "同步cc_rule 1-7", "1,2,3,4,5,6,7", 0)
    conn.execute("update cc_rule set task_id=%s where id<=7",task_id)
    conn.commit()
    

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF
/opt/venv/bin/python /tmp/_db.py
echo "升级数据库完成"

echo "软链接到新版本"
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启主控..."
supervisorctl restart all
echo "重启完成"
echo "完成$version_name版本升级"

