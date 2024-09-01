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

db_done="/tmp/${version_num}_db.done"
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
    
    # 建表
    sql = '''
        alter table site add `backend_port_mapping` boolean default false after proxy_timeout;

        alter table site add extra_cc_rule text after cc_switch;
        update site set extra_cc_rule='[]';

        delete from cc_match where id=5;
        insert into cc_match values (5, null, '匹配内置资源', '内置匹配器', '{"uri":{"operator":"AC","value":["/_guard/slide.js", "/_guard/captcha.png","/_guard/verify-captcha","/_guard/encrypt.js","favicon.ico"]}}',now(),now(),1,1,null,1);


    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 遍历所有规则组的所有规则，删除content_type的规则，如果content_type的过滤器有非请求频率的，添加一条匹配所有，过滤器为非请求频率的规则。如果都是请求频率的话，添加一条匹配所有，过滤器为9的规则
    rules = conn.fetchall("select id, data from cc_rule")
    for r in rules:
        rid = r['id']
        rdata = json.loads(r['data'])
        has_content_type = False
        new_filter1 = "9"
        new_rules = []
        for j in rdata:
            matcher = j['matcher']
            filter1 = j['filter1']
            matcher_data = json.loads(conn.fetchone("select data from cc_match where id=%s", matcher)['data'])
            filter_data = conn.fetchone("select name,type from cc_filter where id=%s", filter1)
            filter1_type = filter_data['type']
            filter1_name = filter_data['name']
            if "content_type" in matcher_data:
                has_content_type = True
            else:
                new_rules.append(j)

            if filter1_type != "req_rate":
                new_filter1 = filter1

        if has_content_type:
            new_rules.append({"matcher": "3", "action": "ipset", "state": True, "filter1": new_filter1, "filter2_name": "", "filter2": "", "matcher_name": "匹配所有资源", "filter1_name": filter1_name})
            conn.execute("update cc_rule set data=%s where id=%s",(json.dumps(new_rules),rid ,) )
            conn.commit()

    # 临时白名单
    conn.execute('''update cc_rule set data='[{"matcher": "3", "matcher_name": "匹配所有资源", "state": true, "filter1": "11", "filter2_name": "", "filter2": "", "action": "ipset", "filter1_name": "临时白名单专用1"}]' where id=3''')
    conn.commit()

    # 内置保护过滤器
    conn.execute("delete from cc_filter where id=4")
    conn.execute("insert into cc_filter VALUES (4,NULL,'内置请求保护60-20-15','内置过滤器','req_rate',60,20,15,'{}',now(),now(),1,1,NULL,1);")
    conn.commit()

    # 删除匹配器有content_type的匹配器
    cc_matchs = conn.fetchall("select id, data from cc_match")
    for c in cc_matchs:
        data = json.loads(c['data'])
        rid = c['id']
        if "content_type" in data:
            conn.execute("delete from cc_match where id=%s", rid)
            conn.commit()


except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

if [[ ! -f $db_done ]]; then
    /opt/venv/bin/python /tmp/_db.py
    touch $db_done
fi
    

}

# 定义版本
version_name="v4.1.3"
version_num="40103"
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

