#!/bin/bash

get_pids() {
    ps aux | grep [n]ginx: | grep -E "/+usr/+local/+openresty/+nginx/+sbin/+nginx|nobody" | awk '{print $2}'
}

get_master_id() {
    # 如果找到了两个pid，先退出，下次再查
    pid=`ps aux | grep nginx | grep [m]aster | grep -E "/+usr/+local/+openresty/+nginx/+sbin/+nginx" | grep root | awk '{print $2}'`
    if [[ `echo $pid | grep " "` != "" ]];then
        echo "err"
    else
        echo $pid
    fi
}

kill_timeout_shutting() {
    # 定义变量
    pid_file="/tmp/nginx_shutting_pid"
    timeout_pid_file="/tmp/nginx_shutting_pid_timeout"
    touch $pid_file
    ((timeout=`grep worker_shutdown_timeout /usr/local/openresty/nginx/conf/nginx.conf | grep -oE '[0-9]+'` + 20))

    # 删除未存在的进程记录
    while read pid start;do
        if [[ ! -d /proc/$pid ]];then
            sed -i "/$pid /d" $pid_file
        fi
    done < $pid_file

    # 记录shutting pid
    now=`date +%s`
    shutting_pid=`ps aux | grep "[w]orker process is shutting down" | awk '{print $2}'`
    for p in `echo "$shutting_pid"`;do
        if [[ `grep "^$p " $pid_file` == "" ]];then
            echo "$p $now" >> $pid_file
        fi
    done

    # 找出超时的进程
    rm -f $timeout_pid_file
    touch $timeout_pid_file
    while read pid start;do
        ((duration=$now-$start))
        if [[ $duration -gt $timeout ]];then
            echo "$pid" >> $timeout_pid_file
        fi
    done < $pid_file

    # 开始kill nginx，超时为30秒
    kill_timeout=30
    start=0
    while true; do
        # 超时时，强制退出
        if [[ $start -gt $kill_timeout ]]; then
            cat $timeout_pid_file | xargs kill -9
            break
        fi

        # 检查是否还有进程
        if [[ `cat $timeout_pid_file` == "" ]]; then
            break
        fi

        cat $timeout_pid_file | xargs kill
        ((start=$start+1))

        # 删除已被kill的进程记录
        while read pid;do
            if [[ ! -d /proc/$pid ]];then
                sed -i "/$pid/d" $timeout_pid_file
            fi
        done < $timeout_pid_file
        sleep 1
    done
}

restart_nginx() {
    # 开始kill nginx，超时为30秒
    timeout=30
    start=0
    while true; do
        # 超时时，强制退出
        if [[ $start -gt $timeout ]]; then
            get_pids | xargs kill -9
            break
        fi

        # 检查进程是否还在
        if [[ `get_pids` == "" ]]; then
            break
        fi

        get_pids | xargs kill
        ((start=$start+1))
        sleep 1

    done

    # 开始启动
    start_nginx

}

start_nginx() {
    rm -f /var/run/nginx.sock 
    
    # 解决conf错误
    source /opt/venv/bin/activate
    cd /opt/cdnfly/agent/
    python -c "import util;util.resolve_conf_err()" 
    deactivate

    # 启动
    ulimit -n 51200 && /usr/local/openresty/nginx/sbin/nginx

}

# 确保nginx worker进程数与配置的一样
check_worker_num() {
    need_restart=true
    for i in `seq 10`;do
        cpu_num=`cat /proc/cpuinfo| grep "processor" | grep -v "model name" | wc -l`
        worker_num_curr=`ps aux | grep "[n]ginx: worker process" |grep nobody | grep -vc "is shutting down"` 
        worker_config=`awk '/worker_processes/{gsub(";","",$2);print $2}' /usr/local/openresty/nginx/conf/nginx.conf`
        worker_num_config=""
        if [[ $worker_config == "auto" ]];then
            worker_num_config=$cpu_num
        elif [[ $i =~ ^[0-9]+$ ]];then
            worker_num_config=$worker_config
        fi

        # 当前worker进程数跟配置中的不一样，需要重启nginx
        if [[ $worker_num_config == $worker_num_curr ]];then
            need_restart=false
            break
        fi
        log "worker_num_config:$worker_num_config worker_num_curr:$worker_num_curr"
        log "need restart $i"
        sleep 5
    done

    if [[ $need_restart == true ]];then
        log "start restart"
        restart_nginx
    fi
}

# 确保nginx.pid存在
check_nginx_pid_file() {
    logs_path=`awk '/error_log/{print $2}'  /usr/local/openresty/nginx/conf/nginx.conf | sed 's/error.log//'`
    if [[ $logs_path == "" ]];then
        return
    fi

    if [[ `echo $logs_path | grep ^/` == "" ]];then
        return
    fi

    pid_path="$logs_path/nginx.pid"
    master_pid=`get_master_id`
    if [[ $master_pid == "err" ]];then
        exit 0
    fi

    if [[ $master_pid == "" ]];then
        return
    fi

    if [[ ! -e $pid_path ]];then 
        echo $master_pid > $pid_path
        return
    fi

    ! grep -q $master_pid $pid_path && echo $master_pid > $pid_path

}


function log() {
    datetime=`date`
    echo "$datetime $1" >> $LOG_PATH
    echo "$1"
}


LOG_PATH="/tmp/guard_nginx.log"

# 判断nginx是否已经初始化，初始化才检测
if ! grep -q "/var/run/nginx.sock" /usr/local/openresty/nginx/conf/nginx.conf;then
    log "nginx未初始化，忽略"
    exit 0
fi

# 判断是否有openresty.json
if [[ ! -f "/usr/local/openresty/nginx/conf/vhost/openresty.json" ]];then
    log "nginx未初始化，忽略"
    exit 0
fi

# 检查master进程是否存在, 不存在则重启
master_pid=`get_master_id`
if [[ "$master_pid" == "err" ]]; then
    exit 0
fi

if [[ "$master_pid" == "" ]]; then
    log "nginx master not found,restarting..."
    restart_nginx
    exit 0
else  # 存在则检查ulimit
    max_open_files=`cat /proc/$master_pid/limits  | grep "Max open files" | awk '{print $4}'`
    if [[ $max_open_files != "" && $max_open_files -lt 51200 ]];then
        log "nginx master max_open_files less than 51200,restarting "
        restart_nginx
        exit 0
    fi
fi

# 测试nginx，测试3次
max_try=3
for i in `seq $max_try`;do
    status_code=`curl -m 5 -s --unix-socket /var/run/nginx.sock http://localhost/nginx-status -o /dev/null -w %{http_code}`
    if [[ $status_code == "200" ]]; then
        echo "nginx正常"
        kill_timeout_shutting
        check_nginx_pid_file
        check_worker_num
        exit 0
    fi
    sleep 1
done

# 不正常时，判断是否有nginx进程，没有就启动
if [[ `get_pids` == "" ]]; then
    start_nginx
    exit 0
fi

# 重启
restart_nginx