# -*- coding: utf-8 -*-

from flask.views import View, MethodView 
from flask import Flask, jsonify, request,Response, send_from_directory, redirect, abort, g, make_response
import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from view.util import decrypt,get_machine_code, rand_string, is_ipv6, client_error, AESCipher, http_request, FileLock, admin_required, login_required, is_number, is_email, is_empty, Op, is_wildcard_domain, is_name, is_des, is_server_name, is_key_cert_valid, is_domain, is_ip, is_url, is_port,get_site_relate_max_allow, lock,is_port_allow,client_success
import json
import random
import datetime
import OpenSSL
import re
import time
from captcha import get_verify_code
from io import BytesIO
from conf.config import VERSION_NAME, VERSION_NUM, LOG_PWD, LOG_IP
import requests
import Queue
import threading
import subprocess
import os

reload(sys) 
sys.setdefaultencoding('utf8')

SHARE_Q = Queue.Queue()  
_WORKER_THREAD_NUM = 10
THREAD_LOCK = threading.Lock()
NODE_VERSION = []

NUMBER_ARR = ["0","1","2","3","4","5","6","7","8","9"]
# 0:"a"
# 1:"b"
# 2:"c"
# 3:"d"
# 4:"e"
# 5:"f"
# 6:"g"
# 7:"h"
# 8:"i"
# 9"j"
# 10:"k"
# 11:"l"
# 12:"m"
# 13:"n"
# 14:"o"
# 15:"p"
# 16:"q"
# 17:"r"
# 18:"s"
# 19:"t"
# 20:"u"
# 21:"v"
# 22:"w"
# 23:"x"
# 24:"y"
# 25:"z"
LETTER_ARR = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
UPPER_LETTER_ARR = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
OTHER_ARR = [".","/",":"]

class MyThread(threading.Thread) :

    def __init__(self, func) :
        super(MyThread, self).__init__()
        self.func = func

    def run(self) :
        self.func()

def get_node_version() :
    global SHARE_Q
    global NODE_VERSION

    while not SHARE_Q.empty():
        try:
            node = SHARE_Q.get(True, 2)
        except Queue.Empty:
            continue
            
        ip = node['ip']
        port = node['port']
        host = node['host']
        http_proxy = json.loads(node['http_proxy'])
        ip_req = ip
        if is_ipv6(ip): ip_req = "["+ip+"]"

        url = "https://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
        method = "get"

        # 获取agent运行状态及版本
        proxies = {}
        if http_proxy:
            proxies = {"https": "http://{user}:{password}@{ip}:{port}".format(user=http_proxy['user'],password=http_proxy['password'],ip=http_proxy['ip'],port=http_proxy['port'])}

        headers = {}
        if host:
            headers = {"Host": host}

        ok, ret = http_request(url, method, None, 5,proxies=proxies,headers=headers)
        if not ok:
            url = "http://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
            ok, ret = http_request(url, method, None, 5,proxies=proxies,headers=headers)

        if ok:
            node['version_name'] = ret['version_name']
            node['version_num'] = ret['version_num']
            node['upgrade_run'] = ret['upgrade_run']
            node['success'] = True

        else:
            node['version_name'] = ret
            node['version_num'] = ret
            node['upgrade_run'] = ret
            node['success'] = False

        with THREAD_LOCK:
            NODE_VERSION.append(node)

def request_node_upgrade() :
    global SHARE_Q

    while not SHARE_Q.empty():
        try:
            node = SHARE_Q.get(True, 2)
        except Queue.Empty:
            continue
            
        ip = node['ip']
        port = node['port']
        conn = Db()
        try:
            node_row = conn.fetchone("select * from node where ip=%s and port=%s and pid=0",(ip,port,))
        finally:
            conn.close()

        http_proxy = json.loads(node_row['http_proxy'])
        host = node_row['host']
        proxies = {}
        if http_proxy:
            proxies = {"https": "http://{user}:{password}@{ip}:{port}".format(user=http_proxy['user'],password=http_proxy['password'],ip=http_proxy['ip'],port=http_proxy['port'])}        


        headers = {}
        if host:
            headers = {"Host": host}

        require_version_num = node['require_version_num']
        ip_req = ip
        if is_ipv6(ip): ip_req = "["+ip+"]"

        url = "https://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
        method = "post"

        data = json.dumps({"require_version_num": require_version_num})

        # 发送升级请求
        ok, ret = http_request(url, method, data, 60,proxies=proxies,headers=headers)
        if not ok:
            url = "http://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
            http_request(url, method, data, 60,proxies=proxies,headers=headers)

class MasterUpgradeAPI(MethodView):
    decorators = [admin_required]

    def get(self, para):
        # 升级运行状态
        lock_file = "/var/run/master_upgrade.lock"
        Lock = FileLock(lock_file)
        try:
            Lock.lock()
            upgrade_run = False
            Lock.unlock()

        except IOError:
            upgrade_run = True

        # 当前版本
        version_name = VERSION_NAME
        version_num = VERSION_NUM

        # 最新版本
        cert_path = OTHER_ARR[1] + LETTER_ARR[14]+ LETTER_ARR[15]+ LETTER_ARR[19]+OTHER_ARR[1]+ LETTER_ARR[2]+ LETTER_ARR[3]+ LETTER_ARR[13]+ LETTER_ARR[5]+ LETTER_ARR[11]+ LETTER_ARR[24]+OTHER_ARR[1]+ LETTER_ARR[12]+ LETTER_ARR[0]+ LETTER_ARR[18]+ LETTER_ARR[19]+LETTER_ARR[4]+ LETTER_ARR[17]+OTHER_ARR[1]+ LETTER_ARR[15]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[4]+ LETTER_ARR[11]+OTHER_ARR[1]+ LETTER_ARR[18]+ LETTER_ARR[17]+ LETTER_ARR[2]+OTHER_ARR[1]+ LETTER_ARR[21]+ LETTER_ARR[8]+ LETTER_ARR[4]+ LETTER_ARR[22]+ LETTER_ARR[18]+OTHER_ARR[1]+ LETTER_ARR[5]+ LETTER_ARR[8]+ LETTER_ARR[13]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[2]+ LETTER_ARR[4]+OTHER_ARR[1]+ LETTER_ARR[17]+ LETTER_ARR[4]+ LETTER_ARR[2]+ LETTER_ARR[7]+ LETTER_ARR[0]+ LETTER_ARR[17]+ LETTER_ARR[6]+ LETTER_ARR[4]+OTHER_ARR[1]+OTHER_ARR[0]+ LETTER_ARR[2]+ LETTER_ARR[4]+ LETTER_ARR[17]+ LETTER_ARR[19]            

        try:
            # https://update.cdnfly.cn/master/upgrades
            url = LETTER_ARR[7]+LETTER_ARR[19]+LETTER_ARR[19]+LETTER_ARR[15]+LETTER_ARR[18]+OTHER_ARR[2]+OTHER_ARR[1]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[3]+LETTER_ARR[0]+LETTER_ARR[19]+LETTER_ARR[4]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[3]+LETTER_ARR[13]+LETTER_ARR[5]+LETTER_ARR[11]+LETTER_ARR[24]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[13]+OTHER_ARR[1]+LETTER_ARR[12]+LETTER_ARR[0]+LETTER_ARR[18]+LETTER_ARR[19]+LETTER_ARR[4]+LETTER_ARR[17]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[6]+LETTER_ARR[17]+LETTER_ARR[0]+LETTER_ARR[3]+LETTER_ARR[4]+LETTER_ARR[18]

            cert="JMyTPE35AXiNvpeGgU3LjA5Naei8Qpqoz4wSCMGYDUEG7+4bXqxgh5zeePdeRCG8HvjAbbyMTQA975vAytbNNaffGJ0uk76eW73Vfr+adWUIUhqTos/cY+Kyh+XnJmqct05ieqi5w6BDmDjtpMp5w23fGRjBPCWPHK0Sr2o71r1+kHgxTxkZCxrm0P1B3SLv9rBa//eMrbqUNnZz/cMNKUQi5rUKClX3Khh0zsGq8wpZEP/JM9Mm7jxAPNHZvb9++Qjf1QYRaTONzBVLUR4+SYefXo46QYv+6WO8NtVv3SxwgYAUaEawk3aJ8sXShaqLvVjCKYRMNEcwwB0hhzAWBMJbPNRJL60u0bhC2w9ofvUzlBI/FIN3BBWJjEdmD81ibyGHt9TCy/rJF+JWCtRBq6EKcoyCKBNNBN80ycf9xIm/5vfTK+L+/4Uv9W4qfDfVh+LoRJ7qGu6DDJuvzeUPpC5j173I/ppKFvXSuQHa2sh1FgrQexux5+mAOXIhJyCT7RyvwOeF6xNKnTLy7F5HXGf0W98kQ4BLzq0980q6R+vsC1UfwJVVCDBFWkfSIMIGGa0kfyVrQhmamqqD2OMqhqNzP7HPyoKNMRIZT4OPEosOmDtQrwE4cAC8eZ9r46iM1276b8cpF7rhFqIQFM02Yotw9F6I0S5Qvzt1t/z+/Rq1Gm+7MCfnxlqmS1Rw8mglUtgSfAQJsFrja1RJNOSTlDEULHxTeIgUS17vDvDkiBe3eZCSpefd/4tD2cpWJFuWgOYB7oKqsnfzNZiUOlL/dg6/XPSxXki1vHtn2lNkaJw+8dGr4qSY8Ai30JmD83VaH/SfqdpxS5CzdKiBwqP2HnKDTee1tx5qANf6iCRFEJUtjbrefylGnvd0IwchP5d+LZ7nzEOK6pQjv4OnUItaoJ71TTSGnAJzYmc2NOchkELIByZJRjT7f1BL+Wgw3o95DvBgm0lI/dlHujSVwIWQ9rMz62YhTiucH6Tg5bQGNpEep3lK9wb63iFJF95c8I2dkvRZ08yH1i6xle+tzn1bOy5INxYbYw7tMZlX0H7V5z33kWGuk1mYRU5yyQXm9S6jsi62J1a/6Do1pEGkSj9O4W6LRM3tAcppZSnahJBqJ1i8Ka79oURaZqmso4Xkw2jqXtojs2iisadwdw63SIA3tY9xP30hm9vf1ztl2NbRKi7Y/VPQn9hymTSMvqRXOC79dvy5cuac9xcMyq5c4vpSLC4Qt2YWr6OYHNGc+WxJKn9nkt1A7jf6Y68AVZBWlS9kNqeLEd2iSHCN+iC9i784vb2QQ5gMRe0Psg0CrV5/4LyFvGSZmKDzfKKVsWMEPrePD/BdpXZMiei+aNGkUcglAD4kSNbezhBdERSy3dQf1Sj9UlBcbLPEvbShmmdYhbAYAv1q7TnQcyi0CNpUZKAiBvMBuGbTEHtJ8HG6LBy7Sv8JPEqyAJohN17/xtpgaivooLzbfnwoWp8zWKMj6TFEnBGVYzp/dfEvW5jAZuqYLIQ8MGkA94qHb7EjGL5ZfL1RJOBZDn7AF8F0p65sbNZPBAlKhp9VbdxAvzfrpJk1d13JyuuwaWfA5j8RkgaYdVbPvRZuNuh43hcM1KOviI5bK1J8pCYdaCVhmMOm+hl5CjHLY0Oa1mwPt/P63OIKNRmNhlv5m3LyFv05gsL5Cybl2JWCVKrhj0U2XBIRwHkA9RQl7+PL/Rjj7wFJTrrqbXWXQd6rES11P9SkUr8P8mAknGlyaH3T6WhYYJF40FvAx21ElTzgAQflSdQ528DIWllO"
            cert_key = LETTER_ARR[10]+UPPER_LETTER_ARR[16]+NUMBER_ARR[3]+LETTER_ARR[21]+LETTER_ARR[0]+UPPER_LETTER_ARR[11]+UPPER_LETTER_ARR[6]+LETTER_ARR[13]+UPPER_LETTER_ARR[25]+NUMBER_ARR[8]+LETTER_ARR[18]+LETTER_ARR[6]+LETTER_ARR[24]+LETTER_ARR[3]+NUMBER_ARR[5]+UPPER_LETTER_ARR[19]
            with open(cert_path,"w+") as fp:
                fp.write(decrypt(cert, cert_key))

            r = requests.get(url, timeout=10,verify=cert_path)

            status_code = r.status_code
            content = r.content
            # 非200状态码表示错误
            if status_code != 200:
                client_error("升级服务器出错,状态码:{status_code},内容:{content}".format(status_code=status_code, content=content),"master_upgrade-3")
            
            # json解析
            try:
                content = json.loads(content)

            except ValueError:
                client_error("非json内容,{content}".format(content=content),"master_upgrade-4")

            code = content['code']
            data = content['data']
            ip = content['ip']

            if code != 0:
                msg = content['msg']
                client_error("获取最新版本出错,{msg}".format(msg=msg),"master_upgrade-5")


            latest_version_name = data[0]['version_name']
            latest_version_num = data[0]['version_num']

        except requests.exceptions.Timeout:
            client_error("连接升级服务器超时","master_upgrade-1")

        except requests.exceptions.ConnectionError:
            client_error("连接升级服务器错误","master_upgrade-2")     
        
        finally:
            if os.path.exists(cert_path):
                os.remove(cert_path)

        # 当前版本要求的agent_ver
        cert_path = OTHER_ARR[1] + LETTER_ARR[14]+ LETTER_ARR[15]+ LETTER_ARR[19]+OTHER_ARR[1]+ LETTER_ARR[2]+ LETTER_ARR[3]+ LETTER_ARR[13]+ LETTER_ARR[5]+ LETTER_ARR[11]+ LETTER_ARR[24]+OTHER_ARR[1]+ LETTER_ARR[12]+ LETTER_ARR[0]+ LETTER_ARR[18]+ LETTER_ARR[19]+LETTER_ARR[4]+ LETTER_ARR[17]+OTHER_ARR[1]+ LETTER_ARR[15]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[4]+ LETTER_ARR[11]+OTHER_ARR[1]+ LETTER_ARR[18]+ LETTER_ARR[17]+ LETTER_ARR[2]+OTHER_ARR[1]+ LETTER_ARR[21]+ LETTER_ARR[8]+ LETTER_ARR[4]+ LETTER_ARR[22]+ LETTER_ARR[18]+OTHER_ARR[1]+ LETTER_ARR[5]+ LETTER_ARR[8]+ LETTER_ARR[13]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[2]+ LETTER_ARR[4]+OTHER_ARR[1]+ LETTER_ARR[17]+ LETTER_ARR[4]+ LETTER_ARR[2]+ LETTER_ARR[7]+ LETTER_ARR[0]+ LETTER_ARR[17]+ LETTER_ARR[6]+ LETTER_ARR[4]+OTHER_ARR[1]+OTHER_ARR[0]+ LETTER_ARR[2]+ LETTER_ARR[4]+ LETTER_ARR[17]+ LETTER_ARR[19]
        try:
            # https://update.cdnfly.cn/master/upgrades
            part_url = LETTER_ARR[7]+LETTER_ARR[19]+LETTER_ARR[19]+LETTER_ARR[15]+LETTER_ARR[18]+OTHER_ARR[2]+OTHER_ARR[1]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[3]+LETTER_ARR[0]+LETTER_ARR[19]+LETTER_ARR[4]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[3]+LETTER_ARR[13]+LETTER_ARR[5]+LETTER_ARR[11]+LETTER_ARR[24]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[13]+OTHER_ARR[1]+LETTER_ARR[12]+LETTER_ARR[0]+LETTER_ARR[18]+LETTER_ARR[19]+LETTER_ARR[4]+LETTER_ARR[17]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[6]+LETTER_ARR[17]+LETTER_ARR[0]+LETTER_ARR[3]+LETTER_ARR[4]+LETTER_ARR[18]

            cert="JMyTPE35AXiNvpeGgU3LjA5Naei8Qpqoz4wSCMGYDUEG7+4bXqxgh5zeePdeRCG8HvjAbbyMTQA975vAytbNNaffGJ0uk76eW73Vfr+adWUIUhqTos/cY+Kyh+XnJmqct05ieqi5w6BDmDjtpMp5w23fGRjBPCWPHK0Sr2o71r1+kHgxTxkZCxrm0P1B3SLv9rBa//eMrbqUNnZz/cMNKUQi5rUKClX3Khh0zsGq8wpZEP/JM9Mm7jxAPNHZvb9++Qjf1QYRaTONzBVLUR4+SYefXo46QYv+6WO8NtVv3SxwgYAUaEawk3aJ8sXShaqLvVjCKYRMNEcwwB0hhzAWBMJbPNRJL60u0bhC2w9ofvUzlBI/FIN3BBWJjEdmD81ibyGHt9TCy/rJF+JWCtRBq6EKcoyCKBNNBN80ycf9xIm/5vfTK+L+/4Uv9W4qfDfVh+LoRJ7qGu6DDJuvzeUPpC5j173I/ppKFvXSuQHa2sh1FgrQexux5+mAOXIhJyCT7RyvwOeF6xNKnTLy7F5HXGf0W98kQ4BLzq0980q6R+vsC1UfwJVVCDBFWkfSIMIGGa0kfyVrQhmamqqD2OMqhqNzP7HPyoKNMRIZT4OPEosOmDtQrwE4cAC8eZ9r46iM1276b8cpF7rhFqIQFM02Yotw9F6I0S5Qvzt1t/z+/Rq1Gm+7MCfnxlqmS1Rw8mglUtgSfAQJsFrja1RJNOSTlDEULHxTeIgUS17vDvDkiBe3eZCSpefd/4tD2cpWJFuWgOYB7oKqsnfzNZiUOlL/dg6/XPSxXki1vHtn2lNkaJw+8dGr4qSY8Ai30JmD83VaH/SfqdpxS5CzdKiBwqP2HnKDTee1tx5qANf6iCRFEJUtjbrefylGnvd0IwchP5d+LZ7nzEOK6pQjv4OnUItaoJ71TTSGnAJzYmc2NOchkELIByZJRjT7f1BL+Wgw3o95DvBgm0lI/dlHujSVwIWQ9rMz62YhTiucH6Tg5bQGNpEep3lK9wb63iFJF95c8I2dkvRZ08yH1i6xle+tzn1bOy5INxYbYw7tMZlX0H7V5z33kWGuk1mYRU5yyQXm9S6jsi62J1a/6Do1pEGkSj9O4W6LRM3tAcppZSnahJBqJ1i8Ka79oURaZqmso4Xkw2jqXtojs2iisadwdw63SIA3tY9xP30hm9vf1ztl2NbRKi7Y/VPQn9hymTSMvqRXOC79dvy5cuac9xcMyq5c4vpSLC4Qt2YWr6OYHNGc+WxJKn9nkt1A7jf6Y68AVZBWlS9kNqeLEd2iSHCN+iC9i784vb2QQ5gMRe0Psg0CrV5/4LyFvGSZmKDzfKKVsWMEPrePD/BdpXZMiei+aNGkUcglAD4kSNbezhBdERSy3dQf1Sj9UlBcbLPEvbShmmdYhbAYAv1q7TnQcyi0CNpUZKAiBvMBuGbTEHtJ8HG6LBy7Sv8JPEqyAJohN17/xtpgaivooLzbfnwoWp8zWKMj6TFEnBGVYzp/dfEvW5jAZuqYLIQ8MGkA94qHb7EjGL5ZfL1RJOBZDn7AF8F0p65sbNZPBAlKhp9VbdxAvzfrpJk1d13JyuuwaWfA5j8RkgaYdVbPvRZuNuh43hcM1KOviI5bK1J8pCYdaCVhmMOm+hl5CjHLY0Oa1mwPt/P63OIKNRmNhlv5m3LyFv05gsL5Cybl2JWCVKrhj0U2XBIRwHkA9RQl7+PL/Rjj7wFJTrrqbXWXQd6rES11P9SkUr8P8mAknGlyaH3T6WhYYJF40FvAx21ElTzgAQflSdQ528DIWllO"
            cert_key = LETTER_ARR[10]+UPPER_LETTER_ARR[16]+NUMBER_ARR[3]+LETTER_ARR[21]+LETTER_ARR[0]+UPPER_LETTER_ARR[11]+UPPER_LETTER_ARR[6]+LETTER_ARR[13]+UPPER_LETTER_ARR[25]+NUMBER_ARR[8]+LETTER_ARR[18]+LETTER_ARR[6]+LETTER_ARR[24]+LETTER_ARR[3]+NUMBER_ARR[5]+UPPER_LETTER_ARR[19]
            with open(cert_path,"w+") as fp:
                fp.write(decrypt(cert, cert_key))

            url = part_url + "?version_num={version_num}&op==".format(version_num=version_num)
            r = requests.get(url, timeout=10,verify=cert_path)

            status_code = r.status_code
            content = r.content
            # 非200状态码表示错误
            if status_code != 200:
                client_error("升级服务器出错,状态码:{status_code},内容:{content}".format(status_code=status_code, content=content),"master_upgrade-7")
            
            # json解析
            try:
                content = json.loads(content)

            except ValueError:
                client_error("非json内容,{content}".format(content=content),"master_upgrade-8")

            code = content['code']
            data = content['data']
            if code != 0:
                msg = content['msg']
                client_error("获取最新版本出错,{msg}".format(msg=msg),"master_upgrade-9")


            agent_ver = data[0]['agent_ver']

        except requests.exceptions.Timeout:
            client_error("连接升级服务器超时","master_upgrade-10")

        except requests.exceptions.ConnectionError:
            client_error("连接升级服务器错误","master_upgrade-11")     
        
        finally:
            if os.path.exists(cert_path):
                os.remove(cert_path)

        es_ip = LOG_IP
        if es_ip == "127.0.0.1":
            es_ip = ip

        ret = {"es_pwd":LOG_PWD, "ip":ip,"es_ip":es_ip, "upgrade_run":upgrade_run, "version_name": version_name, "version_num":version_num, "latest_version_name":latest_version_name, "latest_version_num":latest_version_num,"agent_ver":agent_ver}
        client_success("获取成功", ret)

    def post(self, para):
        lock_file = "/var/run/master_upgrade.lock"
        Lock = FileLock(lock_file)
        try:
            Lock.lock()
                    
        except IOError:
            client_error("升级程序已经在运行了","master_upgrade-6")

        finally:
            Lock.unlock()

        subprocess.check_output(["/opt/venv/bin/python","/opt/cdnfly/master/tasks/upgrade.py", str(VERSION_NUM) ],shell=False)
        client_success("执行成功")

class MasterUpgradeLogAPI(MethodView):
    decorators = [admin_required]

    def get(self, para):
        log_file = "/tmp/master_upgrade.log"
        output = subprocess.check_output(["tail","-n" , "1000", log_file])
        client_success("获取成功", output)

class AgentUpgradeAPI(MethodView):
    decorators = [admin_required]

    def get(self, para):
        global SHARE_Q
        global NODE_VERSION
        NODE_VERSION = []

        # 获取所有agent 升级运行状态及版本号
        conn = Db()
        nodes = conn.fetchall("select id,name,ip,port,http_proxy,host from node where pid=0")
        for node in nodes:
            SHARE_Q.put(node)

        threads = []
        for i in xrange(len(nodes)) :
            thread = MyThread(get_node_version)
            thread.start()
            threads.append(thread)

        for thread in threads :
            thread.join()

        client_success("获取成功", NODE_VERSION)

    def post(self, para):
        global SHARE_Q

        # 获取当前master要求的agent版本
        cert_path = OTHER_ARR[1] + LETTER_ARR[14]+ LETTER_ARR[15]+ LETTER_ARR[19]+OTHER_ARR[1]+ LETTER_ARR[2]+ LETTER_ARR[3]+ LETTER_ARR[13]+ LETTER_ARR[5]+ LETTER_ARR[11]+ LETTER_ARR[24]+OTHER_ARR[1]+ LETTER_ARR[12]+ LETTER_ARR[0]+ LETTER_ARR[18]+ LETTER_ARR[19]+LETTER_ARR[4]+ LETTER_ARR[17]+OTHER_ARR[1]+ LETTER_ARR[15]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[4]+ LETTER_ARR[11]+OTHER_ARR[1]+ LETTER_ARR[18]+ LETTER_ARR[17]+ LETTER_ARR[2]+OTHER_ARR[1]+ LETTER_ARR[21]+ LETTER_ARR[8]+ LETTER_ARR[4]+ LETTER_ARR[22]+ LETTER_ARR[18]+OTHER_ARR[1]+ LETTER_ARR[5]+ LETTER_ARR[8]+ LETTER_ARR[13]+ LETTER_ARR[0]+ LETTER_ARR[13]+ LETTER_ARR[2]+ LETTER_ARR[4]+OTHER_ARR[1]+ LETTER_ARR[17]+ LETTER_ARR[4]+ LETTER_ARR[2]+ LETTER_ARR[7]+ LETTER_ARR[0]+ LETTER_ARR[17]+ LETTER_ARR[6]+ LETTER_ARR[4]+OTHER_ARR[1]+OTHER_ARR[0]+ LETTER_ARR[2]+ LETTER_ARR[4]+ LETTER_ARR[17]+ LETTER_ARR[19]            
        try:
            # https://update.cdnfly.cn/master/upgrades
            part_url = LETTER_ARR[7]+LETTER_ARR[19]+LETTER_ARR[19]+LETTER_ARR[15]+LETTER_ARR[18]+OTHER_ARR[2]+OTHER_ARR[1]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[3]+LETTER_ARR[0]+LETTER_ARR[19]+LETTER_ARR[4]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[3]+LETTER_ARR[13]+LETTER_ARR[5]+LETTER_ARR[11]+LETTER_ARR[24]+OTHER_ARR[0]+LETTER_ARR[2]+LETTER_ARR[13]+OTHER_ARR[1]+LETTER_ARR[12]+LETTER_ARR[0]+LETTER_ARR[18]+LETTER_ARR[19]+LETTER_ARR[4]+LETTER_ARR[17]+OTHER_ARR[1]+LETTER_ARR[20]+LETTER_ARR[15]+LETTER_ARR[6]+LETTER_ARR[17]+LETTER_ARR[0]+LETTER_ARR[3]+LETTER_ARR[4]+LETTER_ARR[18]

            cert="JMyTPE35AXiNvpeGgU3LjA5Naei8Qpqoz4wSCMGYDUEG7+4bXqxgh5zeePdeRCG8HvjAbbyMTQA975vAytbNNaffGJ0uk76eW73Vfr+adWUIUhqTos/cY+Kyh+XnJmqct05ieqi5w6BDmDjtpMp5w23fGRjBPCWPHK0Sr2o71r1+kHgxTxkZCxrm0P1B3SLv9rBa//eMrbqUNnZz/cMNKUQi5rUKClX3Khh0zsGq8wpZEP/JM9Mm7jxAPNHZvb9++Qjf1QYRaTONzBVLUR4+SYefXo46QYv+6WO8NtVv3SxwgYAUaEawk3aJ8sXShaqLvVjCKYRMNEcwwB0hhzAWBMJbPNRJL60u0bhC2w9ofvUzlBI/FIN3BBWJjEdmD81ibyGHt9TCy/rJF+JWCtRBq6EKcoyCKBNNBN80ycf9xIm/5vfTK+L+/4Uv9W4qfDfVh+LoRJ7qGu6DDJuvzeUPpC5j173I/ppKFvXSuQHa2sh1FgrQexux5+mAOXIhJyCT7RyvwOeF6xNKnTLy7F5HXGf0W98kQ4BLzq0980q6R+vsC1UfwJVVCDBFWkfSIMIGGa0kfyVrQhmamqqD2OMqhqNzP7HPyoKNMRIZT4OPEosOmDtQrwE4cAC8eZ9r46iM1276b8cpF7rhFqIQFM02Yotw9F6I0S5Qvzt1t/z+/Rq1Gm+7MCfnxlqmS1Rw8mglUtgSfAQJsFrja1RJNOSTlDEULHxTeIgUS17vDvDkiBe3eZCSpefd/4tD2cpWJFuWgOYB7oKqsnfzNZiUOlL/dg6/XPSxXki1vHtn2lNkaJw+8dGr4qSY8Ai30JmD83VaH/SfqdpxS5CzdKiBwqP2HnKDTee1tx5qANf6iCRFEJUtjbrefylGnvd0IwchP5d+LZ7nzEOK6pQjv4OnUItaoJ71TTSGnAJzYmc2NOchkELIByZJRjT7f1BL+Wgw3o95DvBgm0lI/dlHujSVwIWQ9rMz62YhTiucH6Tg5bQGNpEep3lK9wb63iFJF95c8I2dkvRZ08yH1i6xle+tzn1bOy5INxYbYw7tMZlX0H7V5z33kWGuk1mYRU5yyQXm9S6jsi62J1a/6Do1pEGkSj9O4W6LRM3tAcppZSnahJBqJ1i8Ka79oURaZqmso4Xkw2jqXtojs2iisadwdw63SIA3tY9xP30hm9vf1ztl2NbRKi7Y/VPQn9hymTSMvqRXOC79dvy5cuac9xcMyq5c4vpSLC4Qt2YWr6OYHNGc+WxJKn9nkt1A7jf6Y68AVZBWlS9kNqeLEd2iSHCN+iC9i784vb2QQ5gMRe0Psg0CrV5/4LyFvGSZmKDzfKKVsWMEPrePD/BdpXZMiei+aNGkUcglAD4kSNbezhBdERSy3dQf1Sj9UlBcbLPEvbShmmdYhbAYAv1q7TnQcyi0CNpUZKAiBvMBuGbTEHtJ8HG6LBy7Sv8JPEqyAJohN17/xtpgaivooLzbfnwoWp8zWKMj6TFEnBGVYzp/dfEvW5jAZuqYLIQ8MGkA94qHb7EjGL5ZfL1RJOBZDn7AF8F0p65sbNZPBAlKhp9VbdxAvzfrpJk1d13JyuuwaWfA5j8RkgaYdVbPvRZuNuh43hcM1KOviI5bK1J8pCYdaCVhmMOm+hl5CjHLY0Oa1mwPt/P63OIKNRmNhlv5m3LyFv05gsL5Cybl2JWCVKrhj0U2XBIRwHkA9RQl7+PL/Rjj7wFJTrrqbXWXQd6rES11P9SkUr8P8mAknGlyaH3T6WhYYJF40FvAx21ElTzgAQflSdQ528DIWllO"
            cert_key = LETTER_ARR[10]+UPPER_LETTER_ARR[16]+NUMBER_ARR[3]+LETTER_ARR[21]+LETTER_ARR[0]+UPPER_LETTER_ARR[11]+UPPER_LETTER_ARR[6]+LETTER_ARR[13]+UPPER_LETTER_ARR[25]+NUMBER_ARR[8]+LETTER_ARR[18]+LETTER_ARR[6]+LETTER_ARR[24]+LETTER_ARR[3]+NUMBER_ARR[5]+UPPER_LETTER_ARR[19]
            with open(cert_path,"w+") as fp:
                fp.write(decrypt(cert, cert_key))

            url = part_url + "?version_num={version_num}&op==".format(version_num=VERSION_NUM)
            r = requests.get(url, timeout=20,verify=cert_path)

            status_code = r.status_code
            content = r.content
            # 非200状态码表示错误
            if status_code != 200:
                client_error("升级服务器出错,状态码:{status_code},内容:{content}".format(status_code=status_code, content=content),"agent_upgrade-3")
            
            # json解析
            try:
                content = json.loads(content)

            except ValueError:
                client_error("非json内容,{content}".format(content=content),"agent_upgrade-4")

            code = content['code']
            data = content['data']
            if len(data) == 0:
                client_error("找不到升级数据,url:{url}".format(url=url),"agent_upgrade-6")

            if code != 0:
                msg = content['msg']
                client_error("获取最新版本出错,{msg}".format(msg=msg),"agent_upgrade-5")

            agent_ver = data[0]['agent_ver']

        except requests.exceptions.Timeout:
            client_error("连接升级服务器超时","agent_upgrade-1")

        except requests.exceptions.ConnectionError:
            client_error("连接升级服务器错误","agent_upgrade-2")     
        
        finally:
            if os.path.exists(cert_path):
                os.remove(cert_path)

        content = request.get_json(silent=True,force=True)
        for c in content:
            if "ip" not in c:
                client_error("找不到ip","agent_upgrade-7")

            if "port" not in c:
                client_error("找不到port","agent_upgrade-8")

        # 如果只升级一个节点，就不使用多线程了
        if len(content) == 1:
            node = content[0]
            ip = node['ip']
            port = node['port']
            ip_req = ip
            if is_ipv6(ip): ip_req = "["+ip+"]"


            # 根据ip,port查询node
            conn = Db()
            try:
                node_row = conn.fetchone("select * from node where ip=%s and port=%s and pid=0 limit 1",(ip,port,))
            
            finally:
                conn.close()  

            http_proxy = json.loads(node_row['http_proxy'])
            host = node_row['host']
            proxies = {}
            if http_proxy:
                proxies = {"https": "http://{user}:{password}@{ip}:{port}".format(user=http_proxy['user'],password=http_proxy['password'],ip=http_proxy['ip'],port=http_proxy['port'])}

            headers = {}
            if host:
                headers = {"Host": host}

            http_url = "https://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
            method = "post"
            data = json.dumps({"require_version_num": agent_ver})

            # 发送升级请求
            ok, ret = http_request(http_url, method, data, 60,proxies=proxies,headers=headers)
            if not ok:
                https_url = "http://{ip}:{port}/upgrades".format(ip=ip_req,port=port)
                ok, ret2 = http_request(https_url, method, data, 60,proxies=proxies,headers=headers)
                if not ok:
                    client_error("发送升级指令失败,原因:{ret} {ret2}".format(ret=ret,ret2=ret2),"agent_upgrade-9")

        else:
            for c in content:
                c["require_version_num"] = agent_ver
                SHARE_Q.put(c)

            threads = []
            for i in xrange(_WORKER_THREAD_NUM) :
                thread = MyThread(request_node_upgrade)
                thread.start()
                threads.append(thread)

            for thread in threads :
                thread.join()

        client_success("发送成功")    

class AgentUpgradeLogAPI(MethodView):
    decorators = [admin_required]

    def get(self, para):
        node_id = para['node_id']
        conn = Db()
        try:
            node = conn.fetchone("select * from node where id=%s", node_id)
            ip = node['ip']
            ip_req = ip
            if is_ipv6(ip): ip_req = "["+ip+"]"

            url = "https://{ip}:{port}/upgrades/log".format(ip=ip_req,port=node['port'])
            print url
            method = "get"
            http_proxy = json.loads(node['http_proxy'])
            host = node['host']
            proxies = {}
            if http_proxy:
                proxies = {"https": "http://{user}:{password}@{ip}:{port}".format(user=http_proxy['user'],password=http_proxy['password'],ip=http_proxy['ip'],port=http_proxy['port'])}

            headers = {}
            if host:
                headers = {"Host": host}

            ok, ret = http_request(url, method, None, 20,proxies=proxies,headers=headers)
            if not ok:
                url = "http://{ip}:{port}/upgrades/log".format(ip=ip_req,port=node['port'])
                ok, ret = http_request(url, method, None, 20,proxies=proxies,headers=headers)
                if not ok:
                    client_error("获取日志失败,原因:{ret}".format(ret=ret),"agent_upgrade_log-1")

            client_success("获取成功", ret)
            
        finally:
            conn.close()
