# -*- coding: utf-8 -*-

import requests_unixsocket
import requests
import sys
import time
execfile("/opt/cdnfly/agent/conf/config.py")
import json
import re
import os
import psutil
import threading
import Queue
SHARE_Q = Queue.Queue()  

NOW = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()) 

def nginx_status():
    try:
        with requests_unixsocket.monkeypatch():
            r = requests.get('http+unix://%2Fvar%2Frun%2Fnginx.sock/nginx-status',timeout=3)

        content = r.content.split("\n")
        active_conn_line = content[0]
        reading_conn_line = content[3]
        active_conn = active_conn_line.split(":")[1].strip()

        reading_line = re.match(r"Reading: (\d+) Writing: (\d+) Waiting: (\d+)", reading_conn_line).groups()
        reading = reading_line[0]
        writing = reading_line[1]
        waiting = reading_line[2]
        ret = {"time":NOW, "node_id": NODE_ID, "active_conn":active_conn, "reading":reading, "writing":writing,"waiting":waiting}
        print json.dumps(ret)

    except requests.exceptions.Timeout:
        sys.exit("连接超时")

    except requests.exceptions.ConnectionError:
        sys.exit("连接错误")

def sys_load():
    # cpu %
    cpu = psutil.cpu_percent(interval=5)

    # load
    load = os.getloadavg()[0]

    # mem %
    mem = psutil.virtual_memory()[2]

    ret = {"time":NOW, "node_id": NODE_ID,"cpu":cpu, "load":load, "mem":mem }
    print json.dumps(ret)

def disk_usage():
    for p in psutil.disk_partitions():
        path = p.mountpoint

        # space
        space = psutil.disk_usage(path).percent

        # inode
        inode_stat = os.statvfs(path)
        f_favail = inode_stat.f_favail
        f_files = inode_stat.f_files
        f_fusage = f_files - f_favail
        inode = '{:.1f}'.format(f_fusage*1.0 / f_files*100)

        ret = {"time":NOW, "node_id": NODE_ID,"path":path, "space":space,"inode":inode }
        print json.dumps(ret)

class MyThread(threading.Thread) :

    def __init__(self, func) :
        super(MyThread, self).__init__()
        self.func = func

    def run(self) :
        self.func()

def worker() :
    global SHARE_Q
    sencond = 5
    while not SHARE_Q.empty():
        config = {}
        try:
            nic = SHARE_Q.get(True, 2)
        except Queue.Empty:
            continue
            
        recv_old = psutil.net_io_counters(pernic=True).get(nic).bytes_recv
        sent_old = psutil.net_io_counters(pernic=True).get(nic).bytes_sent
        time.sleep(sencond)
        recv_new = psutil.net_io_counters(pernic=True).get(nic).bytes_recv
        sent_new = psutil.net_io_counters(pernic=True).get(nic).bytes_sent

        inbound = (recv_new - recv_old)*8/sencond
        outbound = (sent_new - sent_old)*8/sencond

        ret = {"time":NOW, "node_id": NODE_ID,"nic":nic, "inbound":inbound,"outbound":outbound }
        print json.dumps(ret)

def bandwidth():
    global SHARE_Q
    for nic in psutil.net_if_addrs():
        if nic == "lo":
            continue

        SHARE_Q.put(nic)

    threads = []
    for i in xrange(len(psutil.net_if_addrs())) :
        thread = MyThread(worker)
        thread.start()
        threads.append(thread)

    for thread in threads :
        thread.join()


def tcp_conn():
    count = 0
    for conn in psutil.net_connections():
        if conn.status == "ESTABLISHED":
            count = count + 1

    ret = {"time":NOW, "node_id": NODE_ID,"conn":count}
    print json.dumps(ret)
        
if __name__ == '__main__':
    if NODE_ID == "":
        pass

    if len(sys.argv) < 2:
        sys.exit("请提供参数")

    cate = sys.argv[1]
    if cate not in globals():
        sys.exit("类别不存在")

    globals()[cate]()