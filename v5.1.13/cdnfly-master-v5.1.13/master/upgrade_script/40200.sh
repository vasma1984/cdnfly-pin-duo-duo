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
eval `grep MYSQL_PASS /opt/cdnfly/master/conf/config.py`
mysql -N -uroot -p$MYSQL_PASS cdn -e 'show processlist' | awk '{print $1}' | xargs kill || true


# 检查是否冲突
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
  sites = conn.fetchall("select id,http_listen,https_listen from site")
  port_protocol = {}
  for site in sites:
    http_listen = json.loads(site['http_listen'])
    https_listen = json.loads(site['https_listen'])
    if http_listen:
      for p in http_listen['port'].split():
        if str(p) in port_protocol:
          if port_protocol[str(p)] != "http":
            print "端口{p}存在http https协议冲突".format(p=p)
            sys.exit(1)

        else:
          port_protocol[str(p)] = "http"

    if https_listen:
      for p in https_listen['port'].split():
        if str(p) in port_protocol:
          if port_protocol[str(p)] != "https":
            print "端口{p}存在http https协议冲突".format(p=p)
            sys.exit(1)

        else:
          port_protocol[str(p)] = "https"

  stream_port_protocol = {}
  streams = conn.fetchall("select id,listen from stream")
  for stream in streams:
    listen = json.loads(stream['listen'])
    for l in listen:
      port = l['port']
      protocol = l['protocol']
      if str(port) in stream_port_protocol:
        if stream_port_protocol[str(port)] == protocol:
          print "转发端口{port}存在重复监听协议".format(port=port)
          sys.exit(1)

      else:
        stream_port_protocol[str(port)] = protocol


      if str(port) in port_protocol:
        print "端口{port}在网站和四层转发重复监听".format(port=port)
        sys.exit(1)
  

except:
    conn.rollback()
    raise

finally:
    conn.close()


EOF

/opt/venv/bin/python /tmp/_db.py


# 开始升级数据库
cat > /tmp/_db.py <<'EOF'
# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from conf.config import LOG_PWD
import pymysql
import json
reload(sys) 
sys.setdefaultencoding('utf8')

conn = Db()
try:
    # 区域
    sql = '''
        # region表
        create table `region` (`id` int(11) not null AUTO_INCREMENT,`name` varchar(255),`des` varchar(255),`create_at` datetime,`update_at` datetime,primary KEY `id` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        insert into `tlock` values ("region");
        insert into region values (1,'默认','',now(),now());

        # node表
        alter table node add `region_id` int(11) after pid;
        update node set region_id=1;
        alter table node add CONSTRAINT `region_ibfk_1` foreign key(`region_id`) REFERENCES region(id);

        # node_group表
        alter table node_group add `region_id` int(11) after id;
        update node_group set region_id=1;
        alter table node_group add CONSTRAINT `region_ibfk_2` foreign key(`region_id`) REFERENCES region(id);

        # merge_node_group
        drop table merge_node_group;

        # package
        alter table package add `region_id` int(11) after des;
        update package set region_id=1;
        alter table package add CONSTRAINT `region_ibfk_3` foreign key(`region_id`) REFERENCES region(id);
        alter table package drop record_id;

        # user_package
        alter table user_package add `region_id` int(11) after package;
        update user_package set region_id=1;
        alter table user_package add CONSTRAINT `region_ibfk_6` foreign key(`region_id`) REFERENCES region(id);

        # site表
        alter table site add `region_id` int(11) after user_package;
        update site set region_id=1;
        alter table site add CONSTRAINT `region_ibfk_4` foreign key(`region_id`) REFERENCES region(id);

        # stream
        alter table stream add `region_id` int(11) after user_package;
        update stream set region_id=1;
        alter table stream add CONSTRAINT `region_ibfk_5` foreign key(`region_id`) REFERENCES region(id);

        # user_package node_group_id
        alter table user_package add `node_group_id` int(11) after region_id;
        alter table user_package add CONSTRAINT `node_group_ibfk_1` foreign key(`node_group_id`) REFERENCES node_group(id);
        UPDATE user_package u INNER JOIN package p ON u.package = p.id SET u.node_group_id = p.node_group_id;

        # site node_group_id
        alter table site add node_group_id int(11) after region_id;
        UPDATE site s INNER JOIN user_package u ON u.id = s.user_package SET s.node_group_id = u.node_group_id;

        # stream node_group_id
        alter table stream add node_group_id int(11) after region_id;
        UPDATE stream s INNER JOIN user_package u ON u.id = s.user_package SET s.node_group_id = u.node_group_id;

        # site cname_task_id
        alter table site add cname_task_id int(11) after task_id;
        alter table site add CONSTRAINT `task_ibfk_19` foreign key(`cname_task_id`) REFERENCES task(id);

        # stream cname_task_id
        alter table stream add cname_task_id int(11) after task_id;
        alter table stream add CONSTRAINT `task_ibfk_20` foreign key(`cname_task_id`) REFERENCES task(id);

        # config
        alter table config add scope_id int(11) after type;
        alter table config add scope_name varchar(10) after scope_id;
        alter table config drop id;
        update config set scope_name='global';
        update config set scope_id=0;
        alter table config modify name varchar(50);
        alter table config modify `type` varchar(30);
        ALTER TABLE `config` ADD unique (`name`, `type`, `scope_id`,`scope_name`);
        update config set type='error_page' where type='error-page';


    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()

    # type: nginx_config name: nginx-config-file 增加 http.proxy_cache_dir : /data/nginx/cache/
    config = json.loads(conn.fetchone("select value from config where name='nginx-config-file' and type='nginx_config' ")['value'])
    config['http']['proxy_cache_dir'] = "/data/nginx/cache/"
    conn.execute("update config set value=%s where name='nginx-config-file' and type='nginx_config' ", json.dumps(config))
    conn.commit()


    # 公告栏
    sql = '''
        create table `message` (`id` bigint not null AUTO_INCREMENT,`type` varchar(20),`pub_user` int(11),`receive` int(11),`title` varchar(255),`content` text,`phone_content` text,`event_id` varchar(32),`is_show` boolean,`is_red` boolean,`is_bold` boolean,`is_external` boolean,`is_popup` boolean,`email_need_send` boolean,`phone_need_send` boolean,`email_is_sent` boolean,`phone_is_sent` boolean,`url` varchar(255),`sort` int(11),`create_at` datetime,`update_at` datetime,primary KEY `id` (`id`),index event_id_idx(event_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        create table message_read (`uid` int(11),`msg_id` bigint,`create_at` datetime,CONSTRAINT `message_ibfk_1` FOREIGN KEY (`msg_id`) REFERENCES `message` (`id`),CONSTRAINT `user_ibfk_10` FOREIGN KEY (`uid`) REFERENCES `user` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        insert into `tlock` values ("message");   
    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()    

    # openresty.json加key 改captcha_html
    config = json.loads(conn.fetchone("select value from config where name='openresty-config' and type='openresty_config' ")['value'])
    config['key'] = LOG_PWD
    config['captcha_html'] = "<!doctype html>\n<html>\n<head>\n<html lang=\"zh-CN\">\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, user-scalable=no\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"format-detection\" content=\"telephone=no\">\n<title>CC LOCK</title>\n<link rel=\"stylesheet\" href=\"//apps.bdimg.com/libs/bootstrap/3.3.4/css/bootstrap.min.css\">\n<script type=\"text/javascript\" src=\"//apps.bdimg.com/libs/jquery/1.7.2/jquery.min.js\"></script>\n<style>\nbody{ margin:auto; padding:0;font-family: \"Microsoft Yahei\",Hiragino Sans GB, WenQuanYi Micro Hei, sans-serif; background:#f9f9f9}\n.main{width:560px;margin:auto; margin-top:140px}\n@media screen and (max-width: 560px) { \n.main {max-width:100%;} \n} \n.panel-footer{ text-align: center}\n.txts{ text-align:center; margin-top:40px}\n.bds{ line-height:40px; border-left:#CCC 1px solid; padding-left:20px}\n.panel{ margin-top:30px}\n</style>\n<!--[if lt IE 9]>\n<style>\n.row\n{\n    height: 100%;\n    display: table-row;\n}\n.col-md-3\n{\n    display: table-cell;\n}\n\n.col-md-9\n{\n    display: table-cell;\n}\n</style>\n<![endif]-->\n</head>\n\n<body>\n<div class=\"main\">\n<div class=\"alert alert-success\" role=\"alert\">\n  <span class=\"glyphicon glyphicon-exclamation-sign\" aria-hidden=\"true\"></span>\n  <span class=\"sr-only\">Error:</span>\n  &nbsp;网站当前访问量较大，请输入验证码后继续访问\n</div>\n<form class=\"form-inline\">\n<div class=\"panel panel-success\">\n  <div class=\"panel-body\">\n  <div class=\"row\">\n  <div class=\"col-md-3\"><div class=\"txts\">请输入验证码</div></div>\n  <div class=\"col-md-9\">\n  <div class=\"bds row\">\n  请输入图片中的验证码，不区分大小写<br>\n  <input type=\"text\" name=\"response\" class=\"form-control\" id=\"response\"  style=\"width:40%;display:inline;\">&nbsp;\n  <span style=\"width:60px\" id=\"captcha\" class=\"yz\"  alt=\"Captcha image\"><img class=\"captcha-code\" src=\"/_guard/captcha.png\"></span>&nbsp;<span><a class=\"refresh-captcha-code\">换一个</a></span>\n  <p><span style=\"color:red\" id=\"notice\"></span></p>\n  </div>\n  </div>\n  </div> \n  </div>\n   <div class=\"panel-footer\"><input id=\"access\" type=\"botton\" class=\"btn btn-success\" value=\"进入网站\" /></div>\n</div>\n</form>\n</div>\n<script language=\"javascript\" type=\"text/javascript\">\n\n    $(\".refresh-captcha-code\").click(function() {\n        $(\".captcha-code\").attr(\"src\",\"/_guard/captcha.png?r=\" + Math.random());\n    });\n\n    $(\"#access\").click(function(e){\n      var response = $(\"#response\").val();\n      document.cookie = \"guardret=\"+response\n      window.location.reload();\n    });\n\n</script>\n</body>\n</html>"
    conn.execute("update config set value=%s where name='openresty-config' and type='openresty_config' ",json.dumps(config))
    conn.commit()

    # 过期提醒
    sql = '''
        create table message_sub (`uid` int(11),`msg_type` varchar(50),`phone` boolean,`email` boolean,CONSTRAINT `user_ibfk_19` FOREIGN KEY (`uid`) REFERENCES `user` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        # 系统设置
        insert into config values ("notification-period","8-22","system","0", "global",now(),now(),1,null);
        insert into config values ("traffic-exceed-notify",' {"state":true,"notify-times":"2","interval":"24","phone-templ":"【cdnfly】尊敬的{{username}}，您的套餐流量（ID: {{package_id}}，名称:{{package_name}}）已用尽，系统已暂停您的服务。您可随时升级恢复服务。","email-templ":"cdnfly套餐流量用尽提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐流量（ID: {{package_id}}，名称:{{package_name}}）已用尽，系统已暂停您的服务。您可随时升级恢复服务。</p>"}',"system","0", "global",now(),now(),1,null);
        insert into config values ("traffic-exceeding-notify",'{"state":true,"notify-times":"2","less":"10","interval":"24","phone-templ":"【cdnfly】尊敬的{{username}}，您的套餐流量（ID: {{package_id}}，名称:{{package_name}}）仅剩余{{traffic_remain}}GB，为避免影响您的服务，请及时升级。","email-templ":"cdnfly套餐流量不足提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐流量（ID: {{package_id}}，名称:{{package_name}}）仅剩余{{traffic_remain}}GB，为避免影响您的服务，请及时升级。</p>"}',"system","0", "global",now(),now(),1,null);
        insert into config values ("package-expire-notify",'{"state":true,"notify-times":"2","interval":"24","phone-templ":"【cdnfly】尊敬的{{username}}，您的套餐（ID: {{package_id}}，名称:{{package_name}}）已过期，系统已暂停您的服务。您可随时续费恢复服务。","email-templ":"cdnfly套餐过期提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐（ID: {{package_id}}，名称:{{package_name}}）已过期，系统已暂停您的服务。您可随时续费恢复服务。</p>"}',"system","0", "global",now(),now(),1,null);
        insert into config values ("package-expiring-notify",'{"state":true,"notify-times":"2","less":"7","interval":"24","phone-templ":"【cdnfly】尊敬的{{username}}，您的套餐（ID: {{package_id}}，名称:{{package_name}}）即期过期，仅剩余{{remain_days}}天，为避免影响您的服务，请及时续费。","email-templ":"cdnfly套餐即将过期提醒！\\\\n<p>尊敬的{{username}}:</p>\\\\n<p>您的套餐（ID: {{package_id}}，名称:{{package_name}}）即期过期，仅剩余{{remain_days}}天，为避免影响您的服务，请及时续费。</p>"}',"system","0", "global",now(),now(),1,null);
        insert into config values ("notify-method",'{"email":true,"phone":true}',"system","0", "global",now(),now(),1,null);
        create table message_send (`id` bigint not null AUTO_INCREMENT,`uid` int(11),`msg_id` int(11),`media` varchar(10),`failed_times` int(11),`state` varchar(10),`ret` text,`create_at` datetime,primary KEY `id` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    '''
    for s in sql.split("\n"):
        if s.strip() == "":
            continue

        conn.execute(s.strip())
        conn.commit()    

    # 根据user表补充数据,注册时也插入
    users = conn.fetchall("select id from user")
    for user in users:
      conn.execute("insert into message_sub values (%s,'package-expire',1,1)",user['id'])
      conn.execute("insert into message_sub values (%s,'traffic-exceed',1,1)",user['id'])
      conn.commit()

    # 增加定时修复开关
    conn.execute("insert into config values ('record-repair-enable','1','system','0','global',now(),now(),1,null)")
    conn.commit()  

    # 解析权重
    conn.execute('alter table line add weight varchar(4) default "" after line_name')
    conn.commit()  

    # 放宽超时值
    conn.execute('alter table site modify proxy_timeout varchar(3);')
    conn.commit()  

    # config
    conn.execute('alter table config modify value MEDIUMTEXT')
    conn.commit()  


  
    

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 增加auto_switch
eval `grep LOG_PWD /opt/cdnfly/master/conf/config.py`
eval `cat /opt/cdnfly/master/conf/config.py | grep LOG_IP`
curl -u elastic:$LOG_PWD  -X PUT "$LOG_IP:9200/auto_switch" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "host":  { "type": "text" , "index":false },
      "rule":  { "type": "text" , "index":false },
      "end_at":  { "type": "integer", "index":true }
    }
  }
}
'




}
# 定义版本
version_name="v4.2.0"
version_num="40200"
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
#supervisorctl reload
echo "重启完成"
echo "完成$version_name版本升级"

