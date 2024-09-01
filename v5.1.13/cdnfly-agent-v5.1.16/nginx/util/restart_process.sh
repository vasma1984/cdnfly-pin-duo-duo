#!/bin/bash

ps aux | grep block_ip_by_iptables.sh | grep -v grep | awk '{print $2}' | xargs kill
