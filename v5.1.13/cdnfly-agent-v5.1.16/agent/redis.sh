#!/bin/bash -x

set -o errexit

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

sync_time(){
    echo "start to sync time and add sync command to cronjob..."

    # 时区
    rm -f /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

    if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
        apt-get -y update
        apt-get -y install ntpdate wget
        /usr/sbin/ntpdate -u pool.ntp.org
    elif check_sys sysRelease centos; then
        yum -y install ntpdate wget
        /usr/sbin/ntpdate -u pool.ntp.org
    fi
    if /sbin/hwclock -w;then
        return
    fi 


}

sync_time

if check_sys sysRelease ubuntu;then
    apt-get -y install  automake make gcc wget 
elif check_sys sysRelease centos;then
    yum install -y  automake  gcc wget
fi    

cd /tmp
wget http://10268950.d.cturls.net/down/10268950/cdnfly/redis-5.0.8.tar.gz
tar xf redis-5.0.8.tar.gz
cd redis-5.0.8
make
make PREFIX=/usr/local/redis install



