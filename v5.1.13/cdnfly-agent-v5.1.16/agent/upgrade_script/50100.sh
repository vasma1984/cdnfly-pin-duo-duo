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
# 更新filebeat
sed -i 's/bulk_max_size.*/bulk_max_size: 2000/g' /opt/cdnfly/agent/conf/filebeat.yml 
sed -i 's/harvester_buffer_size.*/harvester_buffer_size: 1638400/g' /opt/cdnfly/agent/conf/filebeat.yml 


eval `grep "ES_PWD" /opt/cdnfly/agent/conf/config.py | sed 's/ //g'`
eval `grep "ES_IP" /opt/cdnfly/agent/conf/config.py | sed 's/ //g'`
log_path=`grep error_log /usr/local/openresty/nginx/conf//nginx.conf | awk '{print $2}' | sed 's#/error.log##'`
if [[ "$log_path" == "" ]];then
    log_path="/"
fi

cat > /opt/cdnfly/agent/conf/filebeat.yml<<EOF
logging.level: info
logging.selectors: [ ]
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat

filebeat.inputs:
# http_access
- type: log
  enabled: true
  paths:
    - $log_path/access.log

  index: http_access

  scan_frequency: 10s
  harvester_buffer_size: 1638400
  tail_files: true
  pipeline: nginx_access_pipeline
  symlinks: true
  publisher_pipeline_disable_host: true

# stream access
- type: log
  enabled: true
  paths:
    - $log_path/stream.log

  index: stream_access

  scan_frequency: 10s
  harvester_buffer_size: 1638400
  tail_files: true
  pipeline: stream_access_pipeline
  symlinks: true
  publisher_pipeline_disable_host: true

- type: httpjson
  url: https://127.0.0.1:5000/monitor/nginx-status
  interval: 60s
  index: nginx_status
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

- type: httpjson
  url: https://127.0.0.1:5000/monitor/sys-load
  interval: 60s
  index: sys_load
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

- type: httpjson
  url: https://127.0.0.1:5000/monitor/tcp-conn
  interval: 60s
  index: tcp_conn
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

- type: httpjson
  url: https://127.0.0.1:5000/monitor/bandwidth
  interval: 60s
  index: bandwidth
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

- type: httpjson
  url: https://127.0.0.1:5000/monitor/disk-usage
  interval: 60s
  index: disk_usage
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

- type: httpjson
  url: https://127.0.0.1:5000/monitor/user-package
  interval: 60s
  index: up_res_usage
  pipeline: monitor_pipeline
  ssl.verification_mode: none
  http_headers:
    agent-pwd: '$ES_PWD'

  processors:
    - decode_json_fields: 
        fields: ["message"]
        target: "json"
    
    - fingerprint: 
        fields: ["json.node_id","json.upid"]
        target_field: "@metadata._id"

    - script:
        lang: javascript
        id: update_instead_of_ignore_same_id
        source: >
          function process(event) {
            event.Put("@metadata.op_type", "index")
          }

output.elasticsearch:
  enabled: true
  hosts: ["$ES_IP:9200"]
  compression_level: 3
  protocol: "http"
  username: "elastic"
  password: "$ES_PWD"
  worker: 2
  max_retries: 3
  bulk_max_size: 2000
  timeout: 90

processors:
  - drop_fields:
      fields: ["event.created", "agent.hostname","agent.name","agent.id","agent.ephemeral_id", "agent.type",  "agent.version","log.file.path","log.offset", "input.type",  "ecs.version",  "host.name","json"]

setup.template.enabled: false
setup.ilm.enabled: false
EOF

# 创建user_package_config.json
data="{"
for i in `grep "\\$upid" /usr/local/openresty/nginx/conf/vhost/*.conf | awk '{print $4}' | grep -oE "[0-9]+" | sort -u`;do
    data=$data"\"$i\":[-1,-1],"
done
data=`echo $data | sed 's/,$//'`
data=$data"}"
echo $data > /usr/local/openresty/nginx/conf/vhost/user_package_config.json 

# 升级openresty
cd /usr/local
if [[ ! -f "/usr/local/openresty/nginx/sbin/nginx.old-20220305" ]]; then
    \cp /usr/local/openresty/nginx/sbin/nginx /usr/local/openresty/nginx/sbin/nginx.old-20220305
fi

## 备份配置文件
\cp /usr/local/openresty/nginx/conf/nginx.conf /tmp/
\cp /usr/local/openresty/nginx/conf/listen_80.conf /tmp/
\cp /usr/local/openresty/nginx/conf/listen_other.conf /tmp/

openresty_tar_name="openresty-$(get_sys_ver)-20220305.tar.gz"
download "https://dl2.cdnfly.cn/cdnfly/$openresty_tar_name" "https://us.centos.bz/cdnfly/$openresty_tar_name" "$openresty_tar_name"

tar xf $openresty_tar_name

## 还原配置文件
\cp /tmp/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
\cp /tmp/listen_80.conf /usr/local/openresty/nginx/conf/listen_80.conf
\cp /tmp/listen_other.conf /usr/local/openresty/nginx/conf/listen_other.conf

# 测试nginx
ret=`/usr/local/openresty/nginx/sbin/nginx -t 2>&1 || true`
if [[ `echo $ret | grep "syntax is ok"` == "" ]];then
    echo $ret
    exit 1
fi

# 平滑重启nginx
supervisorctl stop task
force_restart || supervisorctl start task

}

update_file() {
cd /opt/$dir_name/
for i in `find ./ | grep -vE "conf/config.py|conf/filebeat.yml|^./agent/conf$|^./$|^./agent$"`;do
    \cp -aT $i /opt/cdnfly/$i
done

}


# 定义版本
version_name="v5.1.0"
version_num="50100"
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
#ps aux  | grep [/]usr/local/openresty/nginx/sbin/nginx | awk '{print $2}' | xargs kill -HUP || true
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



