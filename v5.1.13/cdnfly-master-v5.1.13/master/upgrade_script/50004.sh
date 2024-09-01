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

def is_ip(ip):
    pattern = re.compile(u"^(25[0-5]|2[0-4]\d|[0-1]\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|[0-1]\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|[0-1]\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|[0-1]\d{2}|[1-9]?\d)$")
    return pattern.match(ip.decode('utf8'))    

def escape_re_str(pattern):
    str = '*.?+$^[](){}|\)'
    escape_pattern = ""
    for s in pattern:
        if s in str:
            s = "\\" + s

        escape_pattern += s

    return escape_pattern


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
    nginx_tpl_file = "/opt/cdnfly-master-v5.0.4/master/conf/nginx_global.tpl"
    with open(nginx_tpl_file) as fp:
        nginx_tpl = fp.read()

    template = Template(nginx_tpl)
    value = template.render(config=value)
    
    value = value.replace("__NODE_ID__", str(node_id))
    return json.dumps({"value":value, "orign_value": orign_value})

def render_site(site):
    site_tpl_file = "/opt/cdnfly-master-v5.0.4/master/conf/nginx_http_vhost.tpl"
    with open(site_tpl_file) as fp:
        site_tpl = fp.read()

    template = Template(site_tpl)
    site_id = site['id']
    # http_listen
    site['http_listen'] = json.loads(site['http_listen'])

    # port 
    if site['http_listen']:
        site['http_listen']['ports'] = str(site['http_listen']['port']).split()

    # https_listen
    site['https_listen'] = json.loads(site['https_listen'])

    # port 
    if site['https_listen']:
        site['https_listen']['ports'] = str(site['https_listen']['port']).split()

    # balance_way
    if site['balance_way'] == "url_hash":
        site['balance_way'] = "hash $uri consistent"

    # backend
    backend_ip = []
    site['backend_contain_host'] = False
    backend = json.loads(site['backend'])
    for i in range(len(backend)):
        if backend[i]['state'] == "up":
            backend[i]['state'] = ""

        if not is_ip(backend[i]['addr']):
            site['backend_contain_host'] = True
        else:
            backend_ip.append(backend[i]['addr'])

    # if len(backend) == 1:
    #     backend = backend + backend

    site['backend'] = backend

    # proxy_cache 1.根据no_cache生成site.maps 2. 根据type,content生成location匹配 site.cache
    proxy_cache = json.loads(site['proxy_cache'])
    cache = []
    maps = []
    no_cache_arr = {}
    for i in range(len(proxy_cache)):
        p_type = proxy_cache[i]['type']
        content = proxy_cache[i]['content']
        expire = proxy_cache[i]['expire']
        unit = proxy_cache[i]['unit']
        ignore_arg = proxy_cache[i]['ignore_arg']
        proxy_ignore_headers = proxy_cache[i]['proxy_ignore_headers']
        no_cache = proxy_cache[i]['no_cache']
        # maps
        no_cache_arr[i] = []
        for j in range(len(no_cache)):
            check_var = no_cache[j]['variable']
            match_str = no_cache[j]['string']
            #match_str = re.escape(match_str)

            make_var = "$no_cache_{site_id}_{i}_{j}".format(site_id=site_id, i=i,j=j)
            maps.append({"check_var":check_var,"match_str":match_str,"make_var":make_var.format(site_id=site['id'])})
            no_cache_arr[i].append(make_var)

        # cache
        if p_type == "suffix":
            content = escape_re_str(content)
            uri = "\.({content})$".format(content=content)

        elif p_type == "dir":
            # 转义正则字符及分号,只保留通配符功能
            content = escape_re_str(content)
            content = content.replace(";","\;")
            content = content.replace('\\*','.*?')   
            uri = content

        elif p_type == "full_path":
            # 转义正则字符及分号,只保留通配符功能
            content = escape_re_str(content)
            content = content.replace(";","\;")
            content = content.replace('\\*','.*?')
            uri = "^{content}$".format(content=content)    

        # 允许|
        uri = uri.replace('\\|','|')
        cache.append({"uri":uri,"ignore_arg":int(ignore_arg),"expire":expire,"unit":unit,"proxy_ignore_headers":proxy_ignore_headers, "no_cache":" ".join(no_cache_arr[i])})

    site['maps'] = maps
    site['cache'] = cache

    # resp_header
    resp_header = json.loads(site['resp_header'])
    for i in range(len(resp_header)):
        # 转义\
        resp_header[i]['name'] = resp_header[i]['name'].replace('\\','\\\\')
        resp_header[i]['value'] = resp_header[i]['value'].replace('\\','\\\\')

        # 转义双引号
        resp_header[i]['name'] = resp_header[i]['name'].replace('"','\\"')
        resp_header[i]['value'] = resp_header[i]['value'].replace('"','\\"')

    site['resp_header'] = resp_header
    
    # req_header
    req_header = json.loads(site['req_header'])
    for i in range(len(req_header)):
        # 转义\
        req_header[i]['name'] = req_header[i]['name'].replace('\\','\\\\')
        req_header[i]['value'] = req_header[i]['value'].replace('\\','\\\\')

        # 转义双引号
        req_header[i]['name'] = req_header[i]['name'].replace('"','\\"')
        req_header[i]['value'] = req_header[i]['value'].replace('"','\\"')

    site['req_header'] = req_header

    # cors
    cors = json.loads(site['cors'])
    cors['allow_origin'] = "|".join(cors['allow_origin'].split())
    cors['allow_methods'] = ", ".join(cors['allow_methods'].split())
    cors['allow_headers'] = ", ".join(cors['allow_headers'].split()).replace('\\','\\\\').replace('"','\\"')
    cors['expose_headers'] = ", ".join(cors['expose_headers'].split()).replace('\\','\\\\').replace('"','\\"')

    site['cors'] = cors

    # url_rewrite
    site['url_rewrite'] = json.loads(site['url_rewrite'])
    for i in range(len(site['url_rewrite'])):
        if str(site['url_rewrite'][i]['code']) == "301":
            site['url_rewrite'][i]['code'] = "permanent"
        else:
            site['url_rewrite'][i]['code'] = "redirect"

    # acl
    if not site['acl']:
        site['acl'] = ""
    
    # 分离通配符域名
    non_wildcard_domain = []
    wildcard_domain = []

    for d in site['domain'].split():
        if d.find("*.") > -1:
            wildcard_domain.append(d)
        else:
            non_wildcard_domain.append(d)

    site['non_wildcard_domain'] = " ".join(non_wildcard_domain)
    site['wildcard_domain'] = wildcard_domain

    # cc_switch
    cc_switch = json.loads(site['cc_switch'])
    site['cc_switch'] = cc_switch

    # health_check
    health_check = json.loads(site['health_check'])
    site['health_check'] = health_check
    site['health_check']['upstream'] = "http_{id}_{backend_http_port}".format(id=site['id'],backend_http_port=site['backend_http_port'])
    site['health_check']['status_code'] = [int(i) for i in  site['health_check']['status_code'].split()]
    site['health_check_json'] = json.dumps(site['health_check'])

    # hotlink
    site['hotlink'] = json.loads(site['hotlink'])

    # 如果开启回源端口映射，强制设置回源协议为跟随，回源端口为$server_port
    upstream_http_port = []
    upstream_https_port = []
    if site['backend_port_mapping']:
        site['backend_http_port'] = "$server_port"
        site['backend_https_port'] = "$server_port"
        site['backend_protocol'] = "follow"

        if site['http_listen']:
            upstream_http_port = site['http_listen']['port'].split()

        if site['https_listen']:
            upstream_https_port = site['https_listen']['port'].split()

    else:
        upstream_http_port = [site['backend_http_port']]
        upstream_https_port = [site['backend_https_port']]

    site['upstream_http_port'] = upstream_http_port
    site['upstream_https_port'] = upstream_https_port
    
    with open("/opt/cdnfly/master/agent/" + str(site['id']) + ".conf","w") as fp:
        fp.write(template.render(site=site))

conn = Db()
try:

    # 生成nginx.conf给agent下载
    nodes = conn.fetchall("select * from node")
    for node in nodes:
        node_id = node['id']
        region_id = node['region_id']
        with open("/opt/cdnfly/master/agent/" + str(node_id) + "-nginx.conf","w") as fp:
            fp.write(render_config(region_id, node_id))

    # 生成vhost配置文件给agent下载
    ## 生成
    sites = conn.fetchall("select * from site where enable=1 ")
    for site in sites:
        render_site(site)

    ## 打包
    cmd = "cd /opt/cdnfly/master/agent/ && tar czf vhost.tar.gz *.conf "
    subprocess.check_output(cmd,shell=True)


except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py


}

# 恢复设置的主控证书
restore_cert() {
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
    https_cert = conn.fetchone("select value from config where name='https_cert' and type='system'")['value']
    https_key = conn.fetchone("select value from config where name='https_key' and type='system'")['value']

    if https_cert and https_key:
        with open("/opt/cdnfly/master/conf/ssl.cert","w") as fp:
            fp.write(https_cert)

        with open("/opt/cdnfly/master/conf/ssl.key","w") as fp:
            fp.write(https_key)        

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

}

# 定义版本
version_name="v5.0.4"
version_num="50004"
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

echo "复制config.py配置文件到新版本目录..."
\cp  cdnfly/master/conf/config.py $dir_name/master/conf/config.py
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" $dir_name/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" $dir_name/master/conf/config.py
echo "复制完成"

cd /opt
echo "准备升级数据库..."
upgrade_db
echo "升级数据库完成"

# 还原/opt/cdnfly/master/agent
\cp -a cdnfly/master/agent/* $dir_name/master/agent/

echo "软链接到新版本"
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "恢复主控证书"
restore_cert

echo "开始重启主控..."
supervisorctl restart all
#supervisorctl reload
echo "重启完成"
echo "完成$version_name版本升级"

