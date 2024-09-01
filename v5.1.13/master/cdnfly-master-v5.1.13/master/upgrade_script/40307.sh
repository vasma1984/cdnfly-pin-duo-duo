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

# 更新白名单到openresty
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
    conn.execute("insert into config values ('https_cert','-----BEGIN CERTIFICATE-----\nMIIFljCCBH6gAwIBAgIQBL/rK+7F4CpsSmlMHSvE6TANBgkqhkiG9w0BAQsFADBy\nMQswCQYDVQQGEwJDTjElMCMGA1UEChMcVHJ1c3RBc2lhIFRlY2hub2xvZ2llcywg\nSW5jLjEdMBsGA1UECxMURG9tYWluIFZhbGlkYXRlZCBTU0wxHTAbBgNVBAMTFFRy\ndXN0QXNpYSBUTFMgUlNBIENBMB4XDTE5MDgyOTAwMDAwMFoXDTIwMDgyODEyMDAw\nMFowFzEVMBMGA1UEAxMMdi54bW15YnV5LmNuMIIBIjANBgkqhkiG9w0BAQEFAAOC\nAQ8AMIIBCgKCAQEAvklonZm10SOgrFkH8ftzzLmcqRts+GwZthSpqC6iVuKrbJ8P\nwUpuW7NeK1bqzBN6Dfq+M2wvqwnjreUPD8+yrh1SM942wAEoMh2V4ozTZ3j1a99E\nzVxF1XB5Lj0mz49/0Xx0cUBnP9gCS3QZFixvxDLYcOKar43FC3nRxzA9kkyqB1t+\ndTCjnag7txFV38ta0rCGFMZBP4k8Uv36Lbjmy6vYSqqyV7nbwba9YhdfWQRdHU2k\nNxl3WB23V9jzH8vXvT8ZdLJhL78Xa1NE6riD7dMOWQ5PAafUBJVHS5QZpDwQ57s9\nV5izozmOkxtore8oh00JmDZRSIrVWhxUPc3gxwIDAQABo4ICgTCCAn0wHwYDVR0j\nBBgwFoAUf9OZ86BHDjEAVlYijrfMnt3KAYowHQYDVR0OBBYEFNC7hqpkdbYsSxAH\n8gwqcDRX87KpMBcGA1UdEQQQMA6CDHYueG1teWJ1eS5jbjAOBgNVHQ8BAf8EBAMC\nBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMEwGA1UdIARFMEMwNwYJ\nYIZIAYb9bAECMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNv\nbS9DUFMwCAYGZ4EMAQIBMIGSBggrBgEFBQcBAQSBhTCBgjA0BggrBgEFBQcwAYYo\naHR0cDovL3N0YXR1c2UuZGlnaXRhbGNlcnR2YWxpZGF0aW9uLmNvbTBKBggrBgEF\nBQcwAoY+aHR0cDovL2NhY2VydHMuZGlnaXRhbGNlcnR2YWxpZGF0aW9uLmNvbS9U\ncnVzdEFzaWFUTFNSU0FDQS5jcnQwCQYDVR0TBAIwADCCAQMGCisGAQQB1nkCBAIE\ngfQEgfEA7wB1AKS5CZC0GFgUh7sTosxncAo8NZgE+RvfuON3zQ7IDdwQAAABbN1d\n8dIAAAQDAEYwRAIgKjX5TCYDTKSldG2mUsiG4WnxImZOsSaVkxU1+CLPBOcCIAQi\nusi7GvFs4xrtrhvOwTGFxGDXY+6S0SUz8zJmrKzcAHYAXqdz+d9WwOe1Nkh90Eng\nMnqRmgyEoRIShBh1loFxRVgAAAFs3V3xYgAABAMARzBFAiBtc5xBBPtKTdOFKva1\nJRaE8J5NGd92sSRPi/wxmfUeBAIhAOiLc4fRh9GW1SCc+JCkdqZ5siLUy3n6e87u\npMDtKJpbMA0GCSqGSIb3DQEBCwUAA4IBAQBz/ONP/OqmV4FZe3ealUfOwYk0Y2lr\noB2IrO5pLl+hUBIaoTxcxa8prfWL3658b+l+fe5q/oeA9y5mFaH6SBHFCDMnpJqq\n1dLQ3HtcdQI65uKXLmNDUpA/t1VGRexTqpAp2tpPyGcYf2MDMztpdwh/ap67pgfd\najY+++Pfl3uJW8SODFUiR9mnX20o6X1gPXAYI6Oo8NauM5/Uw/W5cDe8lqEa0T7J\nGxh9ytzM1LZbWTpdsnDcpV6yMRuJ7Z2Kkz74m5ljoDSU3Wj5xbLG8HSG3DwjEEd+\nj5Seof4jYe3eHrOqm/y0GumtFQ26RLcFq4092SipfO7BVFX0qfbmEzor\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nMIIErjCCA5agAwIBAgIQBYAmfwbylVM0jhwYWl7uLjANBgkqhkiG9w0BAQsFADBh\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD\nQTAeFw0xNzEyMDgxMjI4MjZaFw0yNzEyMDgxMjI4MjZaMHIxCzAJBgNVBAYTAkNO\nMSUwIwYDVQQKExxUcnVzdEFzaWEgVGVjaG5vbG9naWVzLCBJbmMuMR0wGwYDVQQL\nExREb21haW4gVmFsaWRhdGVkIFNTTDEdMBsGA1UEAxMUVHJ1c3RBc2lhIFRMUyBS\nU0EgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCgWa9X+ph+wAm8\nYh1Fk1MjKbQ5QwBOOKVaZR/OfCh+F6f93u7vZHGcUU/lvVGgUQnbzJhR1UV2epJa\ne+m7cxnXIKdD0/VS9btAgwJszGFvwoqXeaCqFoP71wPmXjjUwLT70+qvX4hdyYfO\nJcjeTz5QKtg8zQwxaK9x4JT9CoOmoVdVhEBAiD3DwR5fFgOHDwwGxdJWVBvktnoA\nzjdTLXDdbSVC5jZ0u8oq9BiTDv7jAlsB5F8aZgvSZDOQeFrwaOTbKWSEInEhnchK\nZTD1dz6aBlk1xGEI5PZWAnVAba/ofH33ktymaTDsE6xRDnW97pDkimCRak6CEbfe\n3dXw6OV5AgMBAAGjggFPMIIBSzAdBgNVHQ4EFgQUf9OZ86BHDjEAVlYijrfMnt3K\nAYowHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUwDgYDVR0PAQH/BAQD\nAgGGMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjASBgNVHRMBAf8ECDAG\nAQH/AgEAMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au\nZGlnaWNlcnQuY29tMEIGA1UdHwQ7MDkwN6A1oDOGMWh0dHA6Ly9jcmwzLmRpZ2lj\nZXJ0LmNvbS9EaWdpQ2VydEdsb2JhbFJvb3RDQS5jcmwwTAYDVR0gBEUwQzA3Bglg\nhkgBhv1sAQIwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29t\nL0NQUzAIBgZngQwBAgEwDQYJKoZIhvcNAQELBQADggEBAK3dVOj5dlv4MzK2i233\nlDYvyJ3slFY2X2HKTYGte8nbK6i5/fsDImMYihAkp6VaNY/en8WZ5qcrQPVLuJrJ\nDSXT04NnMeZOQDUoj/NHAmdfCBB/h1bZ5OGK6Sf1h5Yx/5wR4f3TUoPgGlnU7EuP\nISLNdMRiDrXntcImDAiRvkh5GJuH4YCVE6XEntqaNIgGkRwxKSgnU3Id3iuFbW9F\nUQ9Qqtb1GX91AJ7i4153TikGgYCdwYkBURD8gSVe8OAco6IfZOYt/TEwii1Ivi1C\nqnuUlWpsF1LdQNIdfbW3TSe0BhQa7ifbVIfvPWHYOu3rkg1ZeMo6XRU9B4n5VyJY\nRmE=\n-----END CERTIFICATE-----\n','system','0','global', now(),now(),1,null); ")
    conn.execute("insert into config values ('https_key','-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC+SWidmbXRI6Cs\nWQfx+3PMuZypG2z4bBm2FKmoLqJW4qtsnw/BSm5bs14rVurME3oN+r4zbC+rCeOt\n5Q8Pz7KuHVIz3jbAASgyHZXijNNnePVr30TNXEXVcHkuPSbPj3/RfHRxQGc/2AJL\ndBkWLG/EMthw4pqvjcULedHHMD2STKoHW351MKOdqDu3EVXfy1rSsIYUxkE/iTxS\n/fotuObLq9hKqrJXudvBtr1iF19ZBF0dTaQ3GXdYHbdX2PMfy9e9Pxl0smEvvxdr\nU0TquIPt0w5ZDk8Bp9QElUdLlBmkPBDnuz1XmLOjOY6TG2it7yiHTQmYNlFIitVa\nHFQ9zeDHAgMBAAECggEAHQwPVwYondvJQks27hvwgd8QSIo3Y2FRDXKbBrbTsN1a\nG13ZOwGAgNQL0HmB+b68DNfqt+Z7DP9t9392Afe2cri8HHnT3rxueolPS4LWyelK\nLCTWwl3PCoq9nNmDNqpU8dFZ5GiB5QTgLiIeADyun62+oitylHuDiZcXdvITZrpf\nbKGe1d2O0tbz1razZTzDR4E50ZS7+ck/TUS+Ciyq76WFaFY+Mhd3TbQS21tHVHId\nBr3F7eoXrZvXZ9J/C/2pmCbiK6rPzTlR1sLDFN2wH2ARUICfVCSctampGRxSKZQW\nQrGMmGInaueqmQqHEBl02WHb6WPhXnIeicCSB1PGYQKBgQDnM6YIqsfJC6qMECL3\nglj1dseWRY3Y1HVQ49gkwk7MFqnx4ZQKdMI3T88+MnnoUK6YsJA9imX1nXaTCUsy\n4umRd+i608RyXLrtwuezU4ejKdAK47Y/SFGaF18pvsNiQWWb2FMyOSWqYFj8e1Mx\nicYnlZiGNzoiM4V/RsFU7tf/YQKBgQDSslBH3d99WddEiP2XawSYjnLfP+OLLTW6\nvdRhEj48st8utVHOAqoFEOGVikHxtwN5AhfHOy6cRMVWPYFUpdVMa9qqsz5J2mmp\nRi0GHNU3n297Wv0UHlkVUGP00VQcUTi7pCUh+ejxs1K6mYrbp/dRrJMQjrBPJU8K\n3zBWQmWZJwKBgF9dFmcMyktK3JXZMhMVWMwmqjx5hACj4Z/z2vuOiiH0VzTF7uJB\nNrrJ2Jm3CEGixeGFMnmv1E5zHK2Zb8MVhXHTG9Oz9ZuWVCQt+JQnKBNM89sKAeoo\nUkBU05PMc5rbjqWxnN9iYv7brti1paMRSQKa2cbCkN/6kF3nOWdm/QEBAoGAQNau\n7e7Rf/nNzUF7CMXePDRaFWnL1GCtUDJq0RSUIonJNM6HxiX7vGNdiG9rq77uSqbi\nOmV0CpL/R3LWAf6mjUYDnNRcLs4QBg+ae28UDnH6FLQDfdV5BJ4gpI5mm/BCzTvO\nUY5eqULOCq6FlOMzsOayuz2t9C0/DdFxRppYObECgYEAofQzjUVlXo9oI00L2d9l\nSl8MWSv/vMV+wlB4/eqw3zOhhCMWv78e/diREHJTWPcbitILE245BBrRHyESUwbu\nsVK/EcJODLumVfH5b8hGbobHAjBTaZ18+w0+Ei58Px3B2BBZCfiwEJBNk6b5KUan\n7+zsTxUmCSpgtqOlvMIwSoM=\n-----END PRIVATE KEY-----\n','system','0','global', now(),now(),1,null);")
    conn.commit()


except:
    conn.rollback()
    raise

finally:
    conn.close()
EOF

/opt/venv/bin/python /tmp/_db.py

}
# 定义版本
version_name="v4.3.7"
version_num="40307"
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

echo "软链接到新版本"
rm -f cdnfly
ln -s $dir_name cdnfly
echo "链接完成"

echo "开始重启主控..."
#supervisorctl restart all
supervisorctl reload
echo "重启完成"
echo "完成$version_name版本升级"

