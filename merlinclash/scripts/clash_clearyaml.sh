#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

rm -rf $LOG_FILE
echo_date "清空yaml/ini/list文件" >> $LOG_FILE
tmp_path=/tmp/upload

rm -rf $tmp_path/*.yaml
rm -rf $tmp_path/*.ini
rm -rf $tmp_path/*.list

http_response "success"
