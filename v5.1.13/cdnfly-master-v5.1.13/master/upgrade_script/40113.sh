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
# 码支付
cd /opt/
echo 'CODEPAY_GATEWAY="https://api.xiuxiu888.com/creat_order/"' >> $dir_name/master/conf/config.py
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
    # 码支付
    pay_config = json.loads(conn.fetchone("select value from config where id=76")['value'])
    pay_config['wxpay']['subtype'] = "native"
    conn.execute("update config set value=%s where id=76", json.dumps(pay_config))
    conn.commit()



except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 回源数据
# 创建pipeline
eval $(grep "LOG_IP" /opt/cdnfly/master/conf/config.py) 
eval $(grep "LOG_PWD" /opt/cdnfly/master/conf/config.py) 

# pipeline nginx_access_pipeline
curl -u elastic:$LOG_PWD -X PUT "$LOG_IP:9200/_ingest/pipeline/nginx_access_pipeline?pretty" -H 'Content-Type: application/json' -d'
{
  "description" : "nginx access pipeline",
  "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{DATA:nid}\t%{DATA:uid}\t%{DATA:upid}\t%{DATA:time}\t%{DATA:addr}\t%{DATA:method}\t%{DATA:scheme}\t%{DATA:host}\t%{DATA:req_uri}\t%{DATA:protocol}\t%{DATA:status}\t%{DATA:bytes_sent}\t%{DATA:referer}\t%{DATA:user_agent}\t%{DATA:content_type}\t%{DATA:up_resp_time}\t%{DATA:cache_status}\t%{GREEDYDATA:up_recv}"]
        }
      },
      {
          "remove": {
            "field": "message"
          }      
      }       
  ]
}
'

# stream_access_pipeline
curl -u elastic:$LOG_PWD -X PUT "$LOG_IP:9200/_ingest/pipeline/stream_access_pipeline?pretty" -H 'Content-Type: application/json' -d'
{
  "description" : "stream access pipeline",
  "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{DATA:nid}\t%{DATA:uid}\t%{DATA:upid}\t%{DATA:port}\t%{DATA:addr}\t%{DATA:time}\t%{DATA:status}\t%{DATA:bytes_sent}\t%{DATA:bytes_received}\t%{GREEDYDATA:session_time}"]
        }
      },
      {
          "remove": {
            "field": "message"
          }      
      } 
  ]
}
'

# 黑名单同步
curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/black_ip" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "site_id":    { "type": "keyword" },  
      "ip":    { "type": "keyword" },  
      "filter":    { "type": "text" , "index":false }, 
      "uid":  { "type": "keyword"  }, 
      "exp":  { "type": "keyword"  }, 
      "create_at":  { "type": "keyword"  }
    }
  }
}
'

curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/white_ip" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "site_id":    { "type": "keyword" },  
      "ip":    { "type": "keyword" },  
      "exp":  { "type": "keyword"  }, 
      "create_at":  { "type": "keyword"  }
    }
  }
}
'

# 套餐
mysql -N -uroot -p@cdnflypass cdn -e 'show processlist' | awk '{print $1}' | xargs kill || true

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
    sql = '''
      alter table user_package add `traffic` int(11) DEFAULT NULL after package;
      alter table user_package add `domain` int(11) DEFAULT NULL after traffic;
      alter table user_package add `http_port` int(11) DEFAULT NULL after domain;
      alter table user_package add `stream_port` int(11) DEFAULT NULL after http_port;
      alter table user_package add `custom_cc_rule` tinyint(1) DEFAULT NULL after stream_port;
      alter table user_package add `websocket` tinyint(1) after custom_cc_rule;
      alter table user_package add `month_price` bigint(20) DEFAULT NULL after websocket;
      alter table user_package add `quarter_price` bigint(20) DEFAULT NULL after month_price;
      alter table user_package add `year_price` bigint(20) DEFAULT NULL after quarter_price;
    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 填充数据
    sql = '''
      UPDATE user_package u
              INNER JOIN
          package p ON u.package = p.id 
      SET 
          u.traffic = p.traffic,
          u.domain = p.domain,
          u.http_port = p.http_port,
          u.stream_port = p.stream_port,
          u.custom_cc_rule = p.custom_cc_rule,
          u.websocket = p.websocket,
          u.month_price = p.month_price,
          u.quarter_price = p.quarter_price,
          u.year_price = p.year_price

    '''
    conn.execute(sql)
    conn.commit()

    # 身份认证增加biz_code
    config = json.loads(conn.fetchone("select value from config where id=89")['value'])
    if config:
      config['biz_code'] = "FACE"

    conn.execute("update config set value=%s where id=89", json.dumps(config))
    conn.commit()

    # dns type dnsdun，增加gateway="https://api.dnsdun.com/"
    config = json.loads(conn.fetchone("select value from config where id=52")['value'])
    if config:
      config['gateway'] = ""
      if config['dns'] == "dnsdun":
        config['gateway'] = "https://api.dnsdun.com/"

      conn.execute("update config set value=%s where id=52", json.dumps(config))
      conn.commit()

    # 解析保护
    conn.execute("insert into config values (90,'dns_rs_protect','','system',now(),now(),1,null)")
    conn.commit()

    # 套餐cname
    sql = '''
      alter table package add cname_hostname2 varchar(255) default '' after cname_domain;
      alter table package add cname_mode varchar(10) default 'site' after cname_hostname2;

      alter table site add cname_hostname2 varchar(255) default '' after cname_domain;
      alter table site add cname_mode varchar(10) default 'site' after cname_hostname2;

      alter table stream add cname_hostname2 varchar(255) default '' after cname_domain;
      alter table stream add cname_mode varchar(10) default 'site' after cname_hostname2;

      alter table user_package add cname_domain varchar(255) default null after package;
      alter table user_package add cname_hostname2 varchar(255) default '' after cname_domain;
      alter table user_package add cname_hostname varchar(255) default null after cname_hostname2;
      alter table user_package add cname_mode varchar(10) default 'site' after cname_hostname;
      alter table user_package add record_id varchar(255) default null after cname_mode;
    '''

    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 填充数据
    sql = '''
      update user_package set cname_hostname=concat(id,'-u')
    '''
    conn.execute(sql)
    conn.commit()

    main_domain = json.loads(conn.fetchone("select value from config where id=52")['value'])['domain']

    # 填充数据
    sql = '''
      UPDATE user_package u
              INNER JOIN
          package p ON u.package = p.id 
      SET 
          u.cname_domain = if(p.cname_domain = '', %s, p.cname_domain)
    '''
    conn.execute(sql,main_domain)
    conn.commit()




except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 时间
if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
  echo '*/10 * * * * /usr/sbin/ntpdate -u pool.ntp.org > /dev/null 2>&1 || (date_str=`curl update.cdnfly.cn/common/datetime` && timedatectl set-ntp false && echo $date_str && timedatectl set-time "$date_str" )'  >> /var/spool/cron/crontabs/root
  service cron restart
elif check_sys sysRelease centos; then
  echo '*/10 * * * * /usr/sbin/ntpdate -u pool.ntp.org > /dev/null 2>&1 || (date_str=`curl update.cdnfly.cn/common/datetime` && timedatectl set-ntp false && echo $date_str && timedatectl set-time "$date_str" )' >> /var/spool/cron/root
  service crond restart
fi


}
# 定义版本
version_name="v4.1.13"
version_num="40113"
dir_name="cdnfly-master-$version_name"
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
#supervisorctl restart all
supervisorctl reload
echo "重启完成"
echo "完成$version_name版本升级"

