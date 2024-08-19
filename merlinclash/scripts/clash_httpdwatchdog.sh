#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
me=$(get merlinclash_enable)
if [ "$me" == "1" ]; then
    #echo_date "开始检查进程状态..."
    a=$(ps | grep httpd | grep -v grep | grep -v httpds | grep -v httpdb | awk '{print $1}')
    if [ ! -n "$a" ]; then
        logger "[MerlinClash]看门狗重启httpd服务"
        service restart_httpd
    fi
fi
