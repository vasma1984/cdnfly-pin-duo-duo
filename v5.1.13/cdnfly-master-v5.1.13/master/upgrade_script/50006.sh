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
# 生成nginx.conf
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
import pymysql
import json
from jinja2 import Template
import re
reload(sys) 
import subprocess
sys.setdefaultencoding('utf8')

def render_config(region_id, node_id):
    config_type = 'nginx_config'
    config_name = 'nginx-config-file'
    ## 全局配置
    value = json.loads(conn.fetchone("select name, value, type from config where type=%s and name=%s and scope_name='global' ", (config_type,config_name,) )['value'])
    
    ## 区域配置
    region_config = conn.fetchone("select name, value, type from config where type=%s and name=%s and scope_name='region' and scope_id=%s ", (config_type,config_name,region_id, ) )
    if region_config:
        region_config = json.loads(region_config['value'])
        for k in region_config:
            v = region_config[k]
            if isinstance(v,dict):
                for k2 in v:
                    v2 = v[k2]
                    if not v2:
                        continue

                    value[k][k2] = v2

                if not value[k]:
                    continue

                v = value[k]

            if not v:
                continue

            value[k] = v

    ## 节点配置
    node_config = conn.fetchone("select name, value, type from config where type=%s and name=%s and scope_name='node' and scope_id=%s ", (config_type,config_name,node_id, ) )
    if node_config:
        node_config = json.loads(node_config['value'])
        
        for k in node_config:
            v = node_config[k]
            if isinstance(v,dict):
                for k2 in v:
                    v2 = v[k2]
                    if not v2:
                        continue

                    value[k][k2] = v2

                if not value[k]:
                    continue

                v = value[k]

            if not v:
                continue

            value[k] = v

    
    orign_value = value

    # 生成配置
    nginx_tpl_file = "/opt/cdnfly-master-v5.0.6/master/conf/nginx_global.tpl"
    with open(nginx_tpl_file) as fp:
        nginx_tpl = fp.read()

    template = Template(nginx_tpl)
    value = template.render(config=value)
    
    value = value.replace("__NODE_ID__", str(node_id))
    return json.dumps({"value":value, "orign_value": orign_value})


conn = Db()
try:
    # server，把CDNFly改了
    nginx_config = json.loads(conn.fetchone("select value from config where name='nginx-config-file' and scope_name='global' ")['value'])
    if nginx_config['http']['server'] == "CDNFly":
        nginx_config['http']['server'] = "cdn"

    nginx_config['http']['server_names_hash_bucket_size'] = "128"

    conn.execute("update config set value=%s where name='nginx-config-file' and scope_name='global' ",json.dumps(nginx_config))
    conn.commit()

    # 生成nginx.conf给agent下载
    nodes = conn.fetchall("select * from node")
    for node in nodes:
        node_id = node['id']
        region_id = node['region_id']
        with open("/opt/cdnfly/master/agent/" + str(node_id) + "-nginx.conf","w") as fp:
            fp.write(render_config(region_id, node_id))

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 更新es
eval `grep "LOG_IP" /opt/cdnfly/master/conf/config.py`
eval `grep "LOG_PWD" /opt/cdnfly/master/conf/config.py`

curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/_template/http_access_template" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "nid":    { "type": "keyword" },  
      "uid":    { "type": "keyword" },  
      "upid":    { "type": "keyword" },  
      "time":   { "type": "date"  ,"format":"dd/MMM/yyyy:HH:mm:ss Z"},
      "addr":  { "type": "keyword"  }, 
      "method":  { "type": "text" , "index":false }, 
      "scheme":  { "type": "keyword"  }, 
      "host":  { "type": "keyword"  }, 
      "server_port":  { "type": "keyword"  }, 
      "req_uri":  { "type": "keyword"  }, 
      "protocol":  { "type": "text" , "index":false }, 
      "status":  { "type": "keyword"  }, 
      "bytes_sent":  { "type": "integer"  }, 
      "referer":  { "type": "keyword"  }, 
      "user_agent":  { "type": "text" , "index":false }, 
      "content_type":  { "type": "text" , "index":false }, 
      "up_resp_time":  { "type": "float" , "index":false,"ignore_malformed": true }, 
      "cache_status":  { "type": "keyword"  }, 
      "up_recv":  { "type": "integer", "index":false,"ignore_malformed": true  }
    }
  },  
  "index_patterns": ["http_access-*"], 
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "index.lifecycle.name": "access_log_policy", 
    "index.lifecycle.rollover_alias": "http_access"
  }
}
'         

curl -u elastic:$LOG_PWD  -X PUT "localhost:9200/http_access/_mapping?pretty" -H 'Content-Type: application/json' -d'
{
  "properties": {
    "server_port": {
      "type": "keyword"
    }
  }
}
'

curl -u elastic:$LOG_PWD -X PUT "$LOG_IP:9200/_ingest/pipeline/nginx_access_pipeline?pretty" -H 'Content-Type: application/json' -d'
{
  "description" : "nginx access pipeline",
  "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{DATA:nid}\t%{DATA:uid}\t%{DATA:upid}\t%{DATA:time}\t%{DATA:addr}\t%{DATA:method}\t%{DATA:scheme}\t%{DATA:host}\t%{DATA:server_port}\t%{DATA:req_uri}\t%{DATA:protocol}\t%{DATA:status}\t%{DATA:bytes_sent}\t%{DATA:referer}\t%{DATA:user_agent}\t%{DATA:content_type}\t%{DATA:up_resp_time}\t%{DATA:cache_status}\t%{GREEDYDATA:up_recv}","%{DATA:nid}\t%{DATA:uid}\t%{DATA:upid}\t%{DATA:time}\t%{DATA:addr}\t%{DATA:method}\t%{DATA:scheme}\t%{DATA:host}\t%{DATA:req_uri}\t%{DATA:protocol}\t%{DATA:status}\t%{DATA:bytes_sent}\t%{DATA:referer}\t%{DATA:user_agent}\t%{DATA:content_type}\t%{DATA:up_resp_time}\t%{DATA:cache_status}\t%{GREEDYDATA:up_recv}"]        }
      },
      {
          "remove": {
            "field": "message"
          }      
      }       
  ]
}
'

# 增加字段和设置cert_default_config
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
        alter table site add acme_proxy_to_orgin boolean default false after websocket_enable;  
        insert into config values ('cert_default_type','lets','cert_default_config','0','global', now(),now(),1,null); 
  
    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()   

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 更新acme
cd /tmp
download "https://dl2.cdnfly.cn/cdnfly/acme.sh-3.0.1.zip" "https://us.centos.bz/cdnfly/acme.sh-3.0.1.zip" "acme.sh-3.0.1.zip"
unzip acme.sh-3.0.1.zip
cd acme.sh-3.0.1
./acme.sh --install --nocron --home /root/.acme.sh/

# 更新panel
flist='master/panel/src/controller/node_senior.js
master/panel/src/controller/senior.js
master/panel/src/controller/site-usage-senior.js
master/panel/src/controller/stream_senior.js
master/panel/src/lib/view.js
master/panel/src/views/config/default/index.html
master/panel/src/views/config/nginx/index.html
master/panel/src/views/finance/balance/index.html
master/panel/src/views/node/dns/index.html
master/panel/src/views/node/group/index.html
master/panel/src/views/node/group/line.html
master/panel/src/views/node/monitor/top-res.html
master/panel/src/views/node/node/index.html
master/panel/src/views/package/buy/index.html
master/panel/src/views/site/cert/addform.html
master/panel/src/views/site/cert/cert.html
master/panel/src/views/site/monitor/access-log.html
master/panel/src/views/site/monitor/attack-rank.html
master/panel/src/views/site/monitor/blackip.html
master/panel/src/views/site/monitor/domain-rank.html
master/panel/src/views/site/monitor/realtime.html
master/panel/src/views/site/monitor/top-res.html
master/panel/src/views/site/monitor/usage.html
master/panel/src/views/site/site/addform.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/site/site/index.html
master/panel/src/views/stream/monitor/top-res.html
master/panel/src/views/stream/monitor/usage.html
master/panel/src/views/system/config/index.html
master/panel/src/views/finance/balance/return.html
master/panel/src/views/node/group/groupform.html
master/panel/src/views/node/group/index.html'

for f in `echo $flist`;do
\cp /opt/$dir_name/$f /opt/cdnfly/$f
done

}

update_file() {
cd /opt/$dir_name/master/
for i in `find ./ | grep -vE "^./$|^./agent$|^./conf$|conf/config.py|conf/ssl.cert|conf/ssl.key|^./panel"`;do
    \cp -aT $i /opt/cdnfly/master/$i
done

}

# 定义版本
version_name="v5.0.6"
version_num="50006"
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

echo "修改config.py版本..."
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" /opt/cdnfly/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" /opt/cdnfly/master/conf/config.py
echo "修改完成"

cd /opt
echo "准备升级数据库..."
upgrade_db
echo "升级数据库完成"

echo "更新文件..."
update_file
echo "更新文件完成."

echo "开始重启主控..."
supervisorctl restart all
#supervisorctl reload
echo "重启完成"

echo "清理文件"
rm -rf /opt/$dir_name
rm -f /opt/$tar_gz_name
echo "清理完成"

echo "完成$version_name版本升级"