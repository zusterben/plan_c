#!/bin/sh

export KSROOT=/koolshare
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

pid_clash=$(pidof clash)
pid_d2s=$(pidof mc_dns2socks)
#pid_watchdog=$(ps | grep clash_watchdog.sh | grep -v grep | awk '{print $1}')
#pid_watchdog=$(cru l | grep "clash_watchdog")
pid_watchdog=$(perpls | grep clash | grep -Eo "uptime.+-s\ " | awk -F" |:|/" '{print $3}')
date=$(echo_date)
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
lan_ipaddr=$(nvram get lan_ipaddr)
board_port="9990"

starttime=$(get merlinclash_clashstarttime)

if [ -n "$pid_clash" ]; then
    text1="<span style='color: #6C0'>$date Clash 进程运行正常！(PID: $pid_clash)</span>"
    text3="<span style='color: #6C0'>【Clash本次启动时间】：$starttime</span>"
else
    text1="<span style='color: red'>$date Clash 进程未在运行！</span>"
    text3="<span style='color: red'>$date Clash 进程未在运行！</span>"
fi

if [ -n "$pid_watchdog" ]; then
    #text2="<span style='color: #6C0'>$date Clash 看门狗运行正常！</span>"
    text2="<span style='color: #6C0'>$date Clash 进程实时守护中！</span>"
else
    # text2="<span style='color: gold'>$date Clash 看门狗未在运行！</span>"
    text2="<span style='color: gold'>$date Clash 进程守护未在运行！</span>"
fi
if [ -n "$pid_d2s" ]; then
    text4="<span style='color: #6C0'>$date Dns2Socks 进程运行正常！(PID: $pid_d2s)</span>"
else
    text4="<span style='color: gold'>$date Dns2Socks 进程未在运行！</span>"
fi
#补丁包版本
patchver=$(get merlinclash_patch_version)
if [ "$patchver" != "" ] || [ "$patchver" != "0" ]; then
    text5="<span style='display:table-cell;float: middle; color: gold'>【已装补丁版本】：$patchver</span>"
    text6="<span style='display:table-cell;float: middle; color: gold'>P:$patchver</span>"
else    
    text5="<span style='display:none;'>【已装补丁版本】：</span>"
    text6="<span style='display:none;'></span>"
fi
http_response "$text1@$text2@$text3@$text4@$text5@$text6"
