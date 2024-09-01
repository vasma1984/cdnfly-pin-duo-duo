# -*- coding: utf-8 -*-

import sys
sys.path.append("/opt/cdnfly/master/")
from model.db import Db
from view.util import FileLock
import subprocess
import daemon
import time
import requests
import json
import traceback
import os
reload(sys) 
sys.setdefaultencoding('utf8')

log_file = "/tmp/master_upgrade.log"

class log(object):
    def __init__(self, arg):
        super(log, self).__init__()
        self.arg = arg
    
    @staticmethod
    def error(info):
        print info
        if not info.endswith("\n"):
            info += "\n"        
        with open(log_file,"a") as fp:
            fp.write(u"[ERROR] " + info)

    @staticmethod
    def info(info):
        print info
        if not info.endswith("\n"):
            info += "\n"        
        with open(log_file,"a") as fp:
            fp.write(u"[INFO] " + info)

    @staticmethod
    def warning(info):
        print info
        if not info.endswith("\n"):
            info += "\n"
        with open(log_file,"a") as fp:
            fp.write(u"[WARNING] " + info)

def download_file(url, save_as):
    try:
        r = requests.get(url, data=None, timeout=30)
        content = r.content
        status_code = r.status_code
        if status_code != 200:
            msg = "下载文件状态码非200,{status_code},{content}".format(status_code=status_code,content=content)
            return False, msg

        with open(save_as, "wb") as fp:
            fp.write(content)

        return True, None

    except requests.exceptions.Timeout:
        msg = "连接服务器超时,url: {url}".format(url=url)
        return False, msg

    except requests.exceptions.ConnectionError:
        msg = "连接服务器错误,url: {url}".format(url=url)
        return False, msg


def update(current_version_num):
    # 清空日志
    with open(log_file,"w") as fp:
        fp.write("[INFO] 开始升级.\n")

    # 查询升级信息
    try:
        for host in ["update-us.cdnfly.cn", "update-cn.cdnfly.cn"]:
            url = "https://{host}/master/upgrades?version_num={current_version_num}&op=>&limit=0".format(host=host, current_version_num=current_version_num)
            log.info("请求升级服务器{url}..".format(url=url))
            try:
                r = requests.get(url, data=None, timeout=30)
                status_code = r.status_code
                content = r.content
                if status_code != 200:
                    log.error("升级服务器状态码非200,{status_code},{content},尝试下一个...".format(status_code=status_code,content=content))
                else:
                    break

            except requests.exceptions.Timeout:
                log.error("{url}连接超时,尝试下一个...".format(url=url))

            except requests.exceptions.ConnectionError:
                log.error("{url}连接错误,尝试下一个...".format(url=url))

        else:
            log.error("下载升级脚本失败，请联系管理员修复")
            return

        content = json.loads(content)
        data = content['data']
        data.reverse()
        for d in data:
            version_num = d['version_num']
            version_name = d['version_name']

            done_file = "/tmp/master_upgrade_{version_num}.done".format(version_num=version_num)
            if os.path.exists(done_file):
                log.warning("{version_name}版本的升级脚本已经执行过，忽略.".format(version_name=version_name))
                continue

            # 下载升级脚本
            log.info("开始下载{version_name}版本的升级脚本，url:{url}".format(url=url,version_name=version_name))

            err = ""
            for host in ["dl2.cdnfly.cn","us.centos.bz"]:
                url = "https://{host}/cdnfly/upgrade_script/master/{version_num}.sh".format(host=host,version_num=version_num)
                log.info("开始下载{version_name}版本的升级脚本，url:{url}".format(url=url,version_name=version_name))
                save_as = "/tmp/master_upgrade_{version_num}.bin".format(version_num=version_num)
                ok, err = download_file(url, save_as)
                if ok:
                    break
                else:
                    log.error("{url}下载失败,原因:{err}，尝试下一个...".format(err=err,url=url))
                
            else:
                log.error("下载{version_name}版本升级脚本失败,原因:{err}".format(err=err,version_name=version_name))
                return

            # 添加执行权限
            subprocess.check_output(["chmod", "+x",save_as])

            # 执行升级脚本
            log.info("开始执行{version_name}版本升级脚本".format(version_name=version_name))
            process = subprocess.Popen([save_as], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            while True:
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break

                if output:
                    print output
                    log.info(output)

            if process.returncode != 0:
                log.error("执行脚本{save_as}失败,升级中断".format(save_as=save_as))
                return

            # 标记已执行
            with open(done_file,"w") as fp: fp.write("")
            log.info("执行脚本{save_as}完成".format(save_as=save_as))

        if len(data) == 0:
            log.warning("未找到升级数据")
            return            

        time.sleep(5)

        # 升级agent
        log.info("主控升级完成，开始升级agent.")
        conn = Db()
        auto_upgrade_agent = conn.fetchone("select value from config where name='auto_upgrade_agent' and type='system' ")['value']
        if auto_upgrade_agent == "1":
            try:
                nodes = conn.fetchall("select ip,port from node where pid=0")
                url = "http://127.0.0.1:88/agent/upgrades"
                r = requests.post(url, data=json.dumps(nodes),timeout=30)
                content = r.content
                content = json.loads(content)
                code = content['code']
                msg = content['msg']
                if code != 0:
                    log.error("发送升级命令失败,原因:{msg}".format(msg=msg))
                    return

                log.info("发送agent升级命令完成.")

            except requests.exceptions.Timeout:
                log.error("连接服务器超时,{url}".format(url=url))
                return

            except requests.exceptions.ConnectionError:
                log.error("连接服务器错误,{url}".format(url=url))
                return

            finally:
                conn.close()

        else:
            log.info("您已关闭节点自动升级，请尽快手动升级节点.")

        log.info("升级完成")    

    except ValueError:
        log.error("返回非json数据:{content}".format(content=content))
        return

    except requests.exceptions.Timeout:
        msg = "连接升级服务器超时,url: {url}".format(url=url)
        log.error(msg)
        return

    except requests.exceptions.ConnectionError:
        msg = "连接升级服务器错误,url: {url}".format(url=url)
        log.error(msg)
        return

    except:
        log.error(traceback.format_exc())
        return

def main(current_version_num):
    # 升级运行状态
    lock_file = "/var/run/master_upgrade.lock"
    Lock = FileLock(lock_file)
    try:
        Lock.lock()
        update(current_version_num)

    except IOError:
        pass

    finally:
        Lock.unlock()
    
if __name__ == '__main__':
    current_version_num = sys.argv[1]
    with daemon.DaemonContext():
        main(current_version_num)
