#!/bin/bash

# 检查是否在凌晨3点之后
curr_hour=$(date +%k)
if [[ $curr_hour -lt 3 ]];then
    exit 0
fi

log_dir="/usr/local/openresty/nginx/logs/"

conf_log_dir=`awk '/error_log/{print $2}'  /usr/local/openresty/nginx/conf/nginx.conf | sed 's/error.log//'`
if [[ $conf_log_dir == "" ]];then
    exit 1
fi

if [[ `echo $conf_log_dir | grep ^/` != "" ]];then
    log_dir=$conf_log_dir
fi

logs="access.log\nstream.log\nerror.log"
one_day_ago=$(date -d "-1 day" +%Y%m%d)
two_day_ago=$(date -d "-2 day" +%Y%m%d)


cd $log_dir
for log in `echo -e $logs`;do
    one_day_ago_log="${log}-$one_day_ago"
    two_day_ago_log="${log}-$two_day_ago"
    if [[ -f "$one_day_ago_log" ]]; then
        if [[ -f "$two_day_ago_log" ]]; then
            gzip $two_day_ago_log
        fi
    else
        mv $log $one_day_ago_log
        ps aux | grep nginx | grep [m]aster | awk '{print $2}' | xargs kill -1
    fi

done    


# 清除旧的
touch $log_dir/foo.gz
find $log_dir/*.gz -mtime +3 -exec rm -f  {} \; 


# 清除/var/log/cdnfly/
cd /var/log/cdnfly/
for log in `ls`;do 
    cat /dev/null > $log
done