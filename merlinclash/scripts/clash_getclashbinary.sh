#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
if [ -f "/jffs/softcenter/merlinclash/clash_binary_history.txt" ];then 
    ln -s /jffs/softcenter/merlinclash/clash_binary_history.txt /tmp/upload/clash_binary_history.txt 
fi
http_response $1

