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
    # 升级包绑定基础套餐
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'package_up' AND column_name = 'bind_package';"):
        sql = '''
            alter table package_up add bind_package varchar(255) default "" after amount;
            alter table site modify block_region text;
            delete from site_conf_cache;
        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()   

    # 升级包绑定基础套餐
    if not conn.fetchone("SELECT column_name FROM information_schema.columns WHERE table_schema='cdn' and table_name = 'node' AND column_name = 'is_mgmt';"):
        sql = '''
            alter table node add is_mgmt boolean default true after http_proxy;

        '''

        for s in sql.split("\n"):
            if s.strip() == "":
                continue

            conn.execute(s.strip())
            conn.commit()   

    # 转换block_region extra_cc_rule
    sites = conn.fetchall("select * from site where block_region is not null and block_region != '' ")
    for site in sites:
        # block_region
        block_region = site['block_region']
        site_id = site['id']

        if block_region == "abrord_inc":
            block_region = "hk,mo,tw,mn,kp,kr,jp,vn,la,kh,th,mm,my,sg,id,bn,ph,tl,in,bd,bt,np,pk,lk,mv,sa,qa,bh,kw,ae,om,ye,ge,lb,sy,il,ps,jo,iq,ir,af,cy,az,tm,tj,kg,uz,kz,dz,ao,bj,bw,bf,bi,cm,cv,cf,td,km,ci,cd,dj,eg,gq,er,et,ga,gm,gh,gn,gw,ke,ls,lr,ly,mg,mw,ml,mr,mu,ma,mz,na,ne,ng,cg,rw,st,sn,sc,sl,so,za,sd,ss,tz,tg,tn,ug,zm,zw,ag,bs,bb,bz,ca,cr,cu,dm,do,sv,ai,bm,gl,gd,gp,gt,ht,hn,jm,mq,mx,ms,aw,cw,ni,pa,kn,lc,vc,tt,tc,us,mf,pr,bl,sx,ar,bo,br,cl,co,ec,gy,py,pe,sr,uy,ve,al,ad,am,at,by,be,ba,bg,hr,cz,dk,ee,fi,fr,de,gr,hu,is,ie,it,lv,li,lt,lu,mk,mt,md,mc,me,nl,no,pl,pt,ro,ru,sm,rs,sk,si,es,se,ch,tr,ua,uk,va,au,pg,nz,fj,sb,pf,nc,vu,ws,gu,fm,to,ki,as,pw,wf,nr,tv,nu,tk"
        elif block_region == "abrord_no_inc":
            block_region = "mn,kp,kr,jp,vn,la,kh,th,mm,my,sg,id,bn,ph,tl,in,bd,bt,np,pk,lk,mv,sa,qa,bh,kw,ae,om,ye,ge,lb,sy,il,ps,jo,iq,ir,af,cy,az,tm,tj,kg,uz,kz,dz,ao,bj,bw,bf,bi,cm,cv,cf,td,km,ci,cd,dj,eg,gq,er,et,ga,gm,gh,gn,gw,ke,ls,lr,ly,mg,mw,ml,mr,mu,ma,mz,na,ne,ng,cg,rw,st,sn,sc,sl,so,za,sd,ss,tz,tg,tn,ug,zm,zw,ag,bs,bb,bz,ca,cr,cu,dm,do,sv,ai,bm,gl,gd,gp,gt,ht,hn,jm,mq,mx,ms,aw,cw,ni,pa,kn,lc,vc,tt,tc,us,mf,pr,bl,sx,ar,bo,br,cl,co,ec,gy,py,pe,sr,uy,ve,al,ad,am,at,by,be,ba,bg,hr,cz,dk,ee,fi,fr,de,gr,hu,is,ie,it,lv,li,lt,lu,mk,mt,md,mc,me,nl,no,pl,pt,ro,ru,sm,rs,sk,si,es,se,ch,tr,ua,uk,va,au,pg,nz,fj,sb,pf,nc,vu,ws,gu,fm,to,ki,as,pw,wf,nr,tv,nu,tk"
        elif block_region == "china_inc":
            block_region = "cn,hk,mo,tw"
        elif block_region == "china_not_inc":
            block_region = "cn"

        conn.execute("update site set block_region=%s where id=%s ",(block_region, site_id,) )
        conn.commit()

    sites = conn.fetchall("select * from site where extra_cc_rule != '[]' and extra_cc_rule not regexp 'within_second' ")
    for site in sites:
        # extra_cc_rule
        site_id = site['id']
        extra_cc_rule = json.loads(site['extra_cc_rule'])
        new_extra_cc_rule = []
        if extra_cc_rule:
            # 原[{"within": "10", "max_req": "111", "uri": "/dir"}]  
            # 新[{"filter": {"within_second": 10, "extra": {}, "type": "req_rate", "max_per_uri": 12, "max_challenge": 11}, "matcher": {"ip": {"operator": "=", "value": "111"}}}]

            for r in extra_cc_rule:
                within = r["within"]
                max_req = r["max_req"]
                uri = r["uri"]
                value = "\n".join(uri.split(","))
                new_extra_cc_rule.append({"filter": {"within_second": within, "extra": {}, "type": "req_rate", "max_per_uri": max_req, "max_challenge": max_req}, "matcher": {"uri": {"operator": "contain", "value": value}}})

        conn.execute("update site set extra_cc_rule=%s where id=%s ",(json.dumps(new_extra_cc_rule), site_id,) )
        conn.commit()

    # acl转换 
    # 原data: [{"acl_action": "allow", "acl_matcher": {"ip": {"operator": "AC", "value": ["aa","bb"]}}}]
    # 新data: [{"acl_action": "allow", "acl_matcher": {"ip": {"operator": "contain", "value": "aa\nbb" }}}]
    acls = conn.fetchall("select * from acl")
    for acl in acls:
        acl_id = acl['id']
        data = json.loads(acl['data'])
        for i in range(len(data)):
            acl_matcher = data[i]["acl_matcher"]
            for item in acl_matcher:
                operator = acl_matcher[item]["operator"]
                value = acl_matcher[item]["value"]
                if operator in ["AC","!AC"]:
                    operator = operator.replace("AC","contain")
                    value = "\n".join(value)
                
                data[i]["acl_matcher"][item]["operator"] = operator
                data[i]["acl_matcher"][item]["value"] = value

        conn.execute("update acl set data=%s where id=%s ", (json.dumps(data),acl_id,) )
        conn.commit()

    # cc_match转换
    # 原{"uri":{"operator":"AC","value":["/_guard/click.js","/_guard/slide.js", "/_guard/captcha.png","/_guard/verify-captcha","/_guard/encrypt.js","favicon.ico"]}}
    # 新{"uri":{"operator":"contain","value":"/_guard/click.js\n/_guard/slide.js", "/_guard/captcha.png\n/_guard/verify-captcha\n/_guard/encrypt.js\nfavicon.ico"}}

    cc_matchs = conn.fetchall("select * from cc_match")
    for cc_match in cc_matchs:
        match_id = cc_match['id']
        if not cc_match['data']:
            continue

        data = json.loads(cc_match['data'])
        for item in data:
            operator = data[item]["operator"]
            value = data[item]["value"]
            if operator in ["AC","!AC"]:
                operator = operator.replace("AC","contain")
                value = "\n".join(value)
            
            data[item]["operator"] = operator
            data[item]["value"] = value
        
        conn.execute("update cc_match set data=%s where id=%s ", (json.dumps(data),match_id,) )
        conn.commit()        

except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

# 更新panel或conf

flist='master/panel/console/index.html
master/panel/src/views/config/default/index.html
master/panel/src/views/finance/order/index.html
master/panel/src/views/node/group/index.html
master/panel/src/views/node/node/index.html
master/panel/src/views/node/region/index.html
master/panel/src/views/package/basic/addform.html
master/panel/src/views/package/basic/index.html
master/panel/src/views/package/buy/index.html
master/panel/src/views/package/group/index.html
master/panel/src/views/package/my/index.html
master/panel/src/views/package/my/up_down.html
master/panel/src/views/package/sold/index.html
master/panel/src/views/package/upgrade/addform.html
master/panel/src/views/package/upgrade/index.html
master/panel/src/views/site/acl/acl-add.html
master/panel/src/views/site/acl/acllist-add.html
master/panel/src/views/site/acl/index.html
master/panel/src/views/site/cc/filter-add.html
master/panel/src/views/site/cc/match-add.html
master/panel/src/views/site/cc/matchlist-add.html
master/panel/src/views/site/cc/rule.html
master/panel/src/views/site/cert/cert.html
master/panel/src/views/site/cert/dnsapi-add.html
master/panel/src/views/site/cert/dnsapi.html
master/panel/src/views/site/group/index.html
master/panel/src/views/site/monitor/access-log.html
master/panel/src/views/site/site/edit.html
master/panel/src/views/site/site/index.html
master/panel/src/views/site/site/update_form.html
master/panel/src/views/site/site/url_ratelimit_form.html
master/panel/src/views/stream/group/index.html
master/panel/src/views/stream/stream/index.html
master/panel/src/views/system/announcement/index.html
master/panel/src/views/system/log/backup.html
master/panel/src/views/system/log/login.html
master/panel/src/views/system/log/op.html
master/panel/src/views/system/task/index.html
master/conf/nginx_http_default.tpl
master/conf/nginx_http_vhost.tpl
master/conf/nginx_stream_vhost.tpl
master/conf/supervisor_master.conf
'

for f in `echo $flist`;do
\cp /opt/$dir_name/$f /opt/cdnfly/$f
done

}

update_file() {
cd /opt/$dir_name/master/
for i in `find ./ | grep -vE "^./$|^./agent$|^./conf$|conf/config.py|conf/nginx_global.tpl|conf/nginx_http_default.tpl|conf/nginx_http_vhost.tpl|conf/nginx_stream_vhost.tpl|conf/ssl.cert|conf/ssl.key|^./panel"`;do
    \cp -aT $i /opt/cdnfly/master/$i
done

}

# 定义版本
version_name="v5.1.3"
version_num="50103"
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

cd /opt
echo "准备升级数据库..."
upgrade_db
echo "升级数据库完成"

echo "更新文件..."
update_file
echo "更新文件完成."

echo "修改config.py版本..."
sed -i "s/VERSION_NAME=.*/VERSION_NAME=\"$version_name\"/" /opt/cdnfly/master/conf/config.py
sed -i "s/VERSION_NUM=.*/VERSION_NUM=\"$version_num\"/" /opt/cdnfly/master/conf/config.py
echo "修改完成"

echo "开始重启主控..."
supervisorctl restart all
#supervisorctl reload
echo "重启完成"


echo "清理文件"
rm -rf /opt/$dir_name
rm -f /opt/$tar_gz_name
echo "清理完成"

echo "完成$version_name版本升级"