#!/bin/bash
#
#**************************************************
#FileName：                 check.sh
## -------------------粗体-----------------------
## \E[0m 重置颜色
## \E[1;31m 红色
## \E[1;32m 绿色
## \E[1;33m 黄色
## \E[1;34m 蓝色
## \E[1;35m 紫色
## \E[1;36m 青色
## \E[1;37m 白色
#**************************************************
echo -e "\e[1;32m-----------系统信息----------\e[0m"
echo -e "\e[1;34m主机名称 : \e[1;31m`hostname`\e[0m"

echo -e "\e[1;34m系统版本 : \e[1;31m`cat /etc/os-release | grep -w "PRETTY_NAME" | cut -d= -f2 | tr -d '"' | sed 's/\s*(\([^)]*\))//g'| sed 's/Stream //g'| sed 's/Linux //g'`\e[0m"

echo -e "\e[1;34m内核版本 : \e[1;31m`uname -r`\e[0m"

echo -e "\e[1;34m编码格式 : \e[1;31m${LANG}\e[0m"

echo -e "\e[1;32m-----------CPU 信息----------\e[0m"
echo -e "\e[1;34mCPU 架构 : \e[1;31m`uname -m`\e[0m"

echo -e "\e[1;34mCPU 型号 :\e[1;31m`cat /proc/cpuinfo | grep "model name" | head -1 | awk -F: '{print $2}'`\e[0m"

echo -e "\e[1;34mCPU 核心 : \e[1;31m`cat /proc/cpuinfo | grep processor | wc -l | awk '{print $1" 核"}'`\e[0m"

echo -e "\e[1;34mCPU 负载 :\e[1;31m $(awk '{printf "%.2f", $3}' /proc/loadavg)\e[0m"

echo -e "\e[1;34mCPU 占用 : \e[1;31m`top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -c 1-2 | awk '{printf("%.2f%%\n", $1/100*100)}'`\e[0m"

echo -e "\e[1;32m-----------网络信息----------\e[0m"
echo -e "\e[1;34mIPV4内网 : \e[1;31m`hostname -i`\e[0m"

echo -e "\e[1;34mIPV4公网 : \e[1;31m$(curl -4 -s ifconfig.co)\e[0m"

echo -e "\e[1;34m默认网关 : \e[1;31m$(ip route show default | awk '/default/ {print $3}')\e[0m"

if (ping -c2 -w2 www.baidu.com &>/dev/null);then
    echo -e "\e[1;34m网络连通 : \e[1;31m是\e[0m"
else
    echo -e "\e[1;34m网络连通 : \e[1;31m否\e[0m"
fi

echo -e "\e[1;32m-----------磁盘信息----------\e[0m"
echo -e "\e[1;34m磁盘占用 : \e[1;31m`df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}'`\e[0m"

echo -e  "\E[1;34mNFS 挂载 : \E[1;31m`echo "" && df -hT /mnt/* | grep "10.10.10.*:/mnt/*"`\E[0m"

# 获取当前时间
start_time=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "\e[1;34m当前时间 ：\e[1;31m$start_time\e[0m"

echo -e "\e[1;34m运行时间 : \e[1;31m$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')\e[0m"

echo -e "\e[1;32m-----------------------------\e[0m"