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
    # 修改表结构
    sql = '''
        alter table node add pid int(11) default 0 after id;
        alter table line add node_id int(11) after node_group_id;
        alter table line add CONSTRAINT `node_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `node` (`id`);
        alter table line add node_ip_id int(11) after node_id;
        alter table line add CONSTRAINT `node_ibfk_3` FOREIGN KEY (`node_ip_id`) REFERENCES `node` (`id`);
        alter table line add `line_id` varchar(255) after node_ip_id;
        alter table line add `line_name` varchar(255) after line_id;
        alter table line add task_id int(11) after record_id;
        alter table line add CONSTRAINT `task_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`);
        alter table line add enable boolean after task_id;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 由node_line得出node表数据
    node_lines = conn.fetchall("select node_id, ip from node_line group by ip")
    for l in node_lines:
        node_id = l['node_id']
        ip = l['ip']
        if not conn.fetchone("select * from node where id=%s and ip=%s and pid=0",(node_id,ip,) ):
            conn.execute("insert into node values (null,%s,null,null,%s,null,null,null,1,null,null,null,null)",(node_id,ip,) )

    conn.commit()

    # 由node_line得出line表数据
    lines = conn.fetchall("select l.node_group_id, l.id,nl.node_id,nl.line_id,nl.line_name,nl.ip,nl.enable from line l left join node_line nl on nl.id = l.node_line_id")
    for l in lines:
        id = l['id']
        node_id = l['node_id']
        line_id = l['line_id']
        line_name = l['line_name']
        ip = l['ip']
        enable = l['enable']
        if enable:
            node_ip_id = conn.fetchone("select id from node where ip=%s", ip)['id']
            conn.execute("update line set node_id=%s,line_id=%s,line_name=%s,node_ip_id=%s,enable=1 where id=%s",(node_id,line_id,line_name,node_ip_id,id,) )

    conn.commit()

    # 删除node_line表
    sql = '''
        alter table line drop FOREIGN KEY `node_line_ibfk_1`;
        alter table line drop node_line_id;
        drop table node_line;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 支付宝的当面付
    config = conn.fetchone("select value from config where id=76")['value']
    config = config.replace('""default-pay"','"default-pay"')
    config = json.loads(config)
    config['alipay']['subtype'] = "pc"
    conn.execute("update config set value=%s where id=76",(json.dumps(config)) )
    conn.commit()

    # 优化套餐 套餐列表可排序 分配套餐给用户
    sql = '''
        create table `package_group` (`id` int(11) not null AUTO_INCREMENT,`name` varchar(255),`des` varchar(255),`sort` int(11),`create_at` datetime,`update_at` datetime,primary KEY `id` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        create table `merge_package_group` (`package_id` int(11),`package_group_id` int(11),CONSTRAINT `package_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `package` (`id`),CONSTRAINT `package_group_ibfk_1` FOREIGN KEY (`package_group_id`) REFERENCES `package_group` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        alter table package add sort int(11) default 100 after update_at;
        alter table package add owner varchar(255) after sort;
        insert into `tlock` values ("package_group");    
        insert into `tlock` values ("merge_package_group");   
        insert into config values (84,'delete_config_delayed','','system',now(),now(),1,null);

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # 设置默认套餐组
    conn.execute("insert into package_group values (null,'默认','',100,now(),now())")
    group_id = conn.insert_id()
    conn.commit()

    packages = conn.fetchall("select * from package")
    for p in packages:
        id = p['id']
        conn.execute("insert into merge_package_group values (%s,%s)",(id,group_id,))

    conn.commit()

    # 自定义默认页面 开启默认页面防御
    config = json.loads(conn.fetchone("select value from config where id=46")['value'])
    config['host_not_found'] = "域名未配置"
    config['access_ip_not_allow'] = "不允许直接访问节点IP"
    conn.execute("update config set value=%s where id=46",json.dumps(config))
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
version_name="v4.1.5"
version_num="40105"
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
supervisorctl restart all
echo "重启完成"
echo "完成$version_name版本升级"

