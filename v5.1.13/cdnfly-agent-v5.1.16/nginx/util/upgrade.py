#!/usr/bin/env python

#coding=utf-8

import os
import sys
import json
import shutil

def copy_captcha(install_location):
    old_captcha_dir = install_location + "/httpguard/lua/conf/captcha/"
    new_captcha_dir = "../conf/captcha/"
    print("copy captcha...")
    shutil.copytree(old_captcha_dir, new_captcha_dir, True)
    print("copy done.")

def v1_0_0_beta1(install_location):
    config_path = install_location + "/httpguard/lua/conf/config.json"
    with open(config_path, "r") as fp:
        config_str = fp.read()

    config_loads = json.loads(config_str)
    config_loads["matcher"]["captcha_slide_matcher"] = {'req_uri': {'operator': '~', 'value': '(captcha\\.png|verify-captcha|verify-slide|get-sid)$'}}
    config_loads["rules"]["tmp_whitelist_rules"] = 'tmp_whitelist'
    config_loads["rules"]["tmp_whitelist"] = [{'action': 'exit_code_action', 'matcher': 'static_file_mathcer', 'state': True, 'filter': 'req_rate_filter_200'}, {'action': 'exit_code_action', 'matcher': 'match_all', 'state': True, 'filter': 'req_rate_filter_50'}]
    config_loads["filter"]["req_rate_filter_200"] = {'within_seconds': 10, 'type': 'req_rate', 'max_challenge': 200}
    default_rules = config_loads["rules"]["default"]
    config_loads["rules"][default_rules].insert(0, {'action': 'exit_code_action', 'matcher': 'captcha_slide_matcher', 'state': True, 'filter': 'req_rate_filter_50'})
    config_loads["version"] = "v1.0.0-beta1"

    with open("../conf/config.json", "w") as fp:
        fp.write(json.dumps(config_loads, indent=4))
    copy_captcha(install_location)

def v1_0_0_beta2(install_location):
    config_path = install_location + "/httpguard/lua/conf/config.json"
    with open(config_path, "r") as fp:
        config_str = fp.read()
    config_loads = json.loads(config_str)
    config_loads["version"] = "v1.0.0-beta2"
    with open("../conf/config.json", "w") as fp:
        fp.write(json.dumps(config_loads, indent=4))

    os.system('./restart_process.sh')        
    copy_captcha(install_location)

def main():
    while True:
        install_location = raw_input("Please enter your httpguard location(ie. /home/httpguard): ")
        config_path = install_location + "/httpguard/lua/conf/config.json"
        if not os.path.exists(config_path):
            print("config file " + config_path + " not found,please reinput.")
            continue

        break    

    with open(config_path, "r") as fp:
        config_str = fp.read()

    try:
        config_loads = json.loads(config_str)
    except ValueError:
        sys.exit("maybe config file " +  config_path + " is invalid json file.")

    try:
        version = config_loads["version"]
    except KeyError:
        sys.exit("version not found.")

    print("your current version: " + version)
    if version == "v1.0.0-beta":
        v1_0_0_beta1(install_location)
        v1_0_0_beta2(install_location)

    if version == "v1.0.0-beta1":
        v1_0_0_beta2(install_location)

    print("upgrade done.")    

main()
