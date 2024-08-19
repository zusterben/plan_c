#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

#echo_date "download" >> $LOG_FILE
#echo_date "定位文件" >> $LOG_FILE

cp -rf /tmp/clash_run.log /tmp/upload/clash_run.log

http_response "$1"




