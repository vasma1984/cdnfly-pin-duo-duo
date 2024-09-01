# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from view.util import sync_global_config, is_ipv6, lock, set_task_start, set_task_failed, set_task_done, cancel_task, is_cert_expiring,create_node_task, decrease_task_pry, set_main_task_state, http_request, render_listen_conf
import importlib
import subprocess
import datetime
import os
import json
import threading
import Queue
import time
import zlib
from jinja2 import Template
import base64

SHARE_Q = Queue.Queue()  
_WORKER_THREAD_NUM = 10

class MyThread(threading.Thread) :

    def __init__(self, func) :
        super(MyThread, self).__init__()
        self.func = func

    def run(self) :
        self.func()

def worker() :
    global SHARE_Q
    while not SHARE_Q.empty():
        config = {}
        try:
            task = SHARE_Q.get(True, 2)
        except Queue.Empty:
            continue
            
        task_id = task['task_id']
        node_id = task['node_id']
        node_port = task['port']
        host = task['host']
        http_proxy = json.loads(task['http_proxy'])
        conn = Db()
            
        try:
            node = conn.fetchone("select * from node where enable=1 and (id=%s or pid=%s) and is_mgmt=1 order by rand() limit 1",(node_id,node_id,) )
            if not node:
                cancel_task(conn,task_id,'没有可用IP')
                continue

            ip = node['ip']
            ip_req = ip
            if is_ipv6(ip): ip_req = "["+ip+"]"            
            url = "https://{ip}:{port}/agent/status".format(ip=ip_req, port=node_port)
            method = "get"
            # 子任务开始
            set_task_start(conn, task_id)
            data = None

            # 发请求
            proxies = {}
            if http_proxy:
                proxies = {"https": "http://{user}:{password}@{ip}:{port}".format(user=http_proxy['user'],password=http_proxy['password'],ip=http_proxy['ip'],port=http_proxy['port'])}

            headers = {}
            if host:
                headers = {"Host": host}

            ok, msg = http_request(url, method, data, 120,proxies=proxies,headers=headers)
            if not ok:
                if msg == "连接openresty错误":
                    # 创建差量同步任务
                    config_task_id = []
                    conn.execute("insert into task values (null, 0, 20, '节点差量同步','diff_sync',%s,null,null,now(),null,null,null,1,'pending',0,null,null)", node_id)
                    diff_sync_task_id = conn.insert_id()
                    config_task_id.append(str(diff_sync_task_id))

                    # 公共配置同步
                    global_config_task_id = sync_global_config(conn, node_id)
                    config_task_id += global_config_task_id

                    # 设置节点任务id
                    conn.execute("update node set config_task=%s where id=%s",(",".join(config_task_id),node_id,) )                    

                set_task_failed(conn, task_id, msg)
                continue

            set_task_done(conn, task_id)

        except:
            conn.rollback()
            raise

        finally:
            conn.close()

def create_task(conn):
    conn.execute("insert into job values (null,null,'agent检查',null,null,null,now(),null)")
    job_id = conn.insert_id()

    task_id = create_node_task(conn, "agent检查", "同步", "agent检查", job_id, 0 )

    conn.execute("update job set task_id=%s where id=%s",(task_id,job_id,) )
    conn.commit()
    return task_id

def main():
    sleep_time = 10
    global SHARE_Q
    conn = Db()
    try:
        # 节点为空时跳过
        if conn.fetchone("select count(1) as count from node where enable=1 and pid=0")['count'] == 0:
            return sleep_time

        main_task = conn.fetchone("select j.task_id,t.state,t.end_at from job j left join task t on j.task_id = t.id where j.type='agent检查' and t.enable=1 order by t.id desc limit 1 ")
        if main_task and main_task['task_id']:      
            # 非pending的任务，要看间隔时间
            if main_task['state'] != "pending":
                end_at = main_task['end_at']
                now = datetime.datetime.now()
                # 间隔时间小于300秒，退出
                if end_at and (now - end_at).total_seconds() < 300:
                    return sleep_time
                else:
                    # 超过300秒，创建一个
                    task_id = create_task(conn)
                    main_task = {"task_id": task_id}

        else:
            # 找不到任务，就创建一个
            task_id = create_task(conn)
            main_task = {"task_id": task_id}

        task_id = main_task['task_id']

        # 开始执行任务
        sql = '''
            SELECT 
                t.id AS task_id,
                t.type AS task_type,
                n.id AS node_id,
                n.ip,
                n.port,
                n.http_proxy,
                n.host,
                n.enable as node_enable
            FROM
                task t
                    LEFT JOIN
                node n ON t.data = n.id
            WHERE
                t.pid = %s AND t.enable = 1
                    AND t.state != 'done';
        '''
        sub_tasks = conn.fetchall(sql, task_id)     
        

        # 没有子任务，标记成功
        if not sub_tasks:
            set_task_done(conn, task_id)
            return sleep_time

        for t in sub_tasks:
            SHARE_Q.put(t)

        # 设置开始任务
        set_task_start(conn, task_id)

        threads = []
        _WORKER_THREAD_NUM = len(sub_tasks)
        for i in xrange(_WORKER_THREAD_NUM) :
            thread = MyThread(worker)
            thread.start()
            threads.append(thread)

        for thread in threads :
            thread.join()

        # 设置主任务状态
        set_main_task_state(task_id)

    except:
        conn.rollback()
        raise

    finally:
        conn.close()    

    return sleep_time

if __name__ == '__main__':
    main()
