# -*- coding: utf-8 -*-

import requests
import re
import time
import json

url_list={"baidu":"https://rdnsdb.com/baidu.com/","sogou":"https://rdnsdb.com/sogou.com/","sm":"https://rdnsdb.com/sm.cn/",
            "bing":"https://rdnsdb.com/bing.com/","google":"https://rdnsdb.com/google.com/","toutiao":"https://rdnsdb.com/toutiao.com/"}

spider_list = {}

for name in url_list:
    url = url_list[name]
    r = requests.get(url,headers={"user-agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36"},verify=False)
    content = r.content
    m = re.findall(r'<a href="/(\d+\.\d+\.\d+)\.0/24" target="_blank" rel="nofollow">\d+\.\d+\.\d+\.0/24</a>',content)
    if len(m) == 0:
        print name + " 获取失败"
        break

    spider_list[name] = m
    time.sleep(1)

with open("/root/html/cdnfly/spider_ip.json","w") as fp:
    fp.write(json.dumps(spider_list))


