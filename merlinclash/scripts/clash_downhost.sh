#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

echo_date "下载Hosts文件" >> $LOG_FILE
echo_date "定位Hosts文件" >> $LOG_FILE
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
hostsel=$(get merlinclash_hostsel)
filepath=/jffs/softcenter/merlinclash/yaml_basic/host/$hostsel.yaml
tmp_path=/tmp/upload

rm -rf $tmp_path/$hostsel.yaml
cp -rf $filepath $tmp_path/$hostsel.yaml
if [ -f $tmp_path/$hostsel.yaml ]; then
   echo_date "文件已复制" >> $LOG_FILE
   http_response "$hostsel.yaml"
else
    echo_date "文件复制失败" >> $LOG_FILE
fi

