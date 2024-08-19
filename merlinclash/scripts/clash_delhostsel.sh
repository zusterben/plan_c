#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/tmp/yaml_online_del.lock
fp=/jffs/softcenter/merlinclash/yaml_basic/host

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
start_online_del(){
    rm -rf $LOG_FILE
    echo_date "定位Hosts文件" >> $LOG_FILE

    #delpath1=/jffs/softcenter/merlinclash
    delpath1=/jffs/softcenter/merlinclash/yaml_basic/host
    hostname=$(get merlinclash_hostsel)

    rm -rf $delpath1/$hostname.yaml
  
    echo_date "删除文件" >> $LOG_FILE
    echo_date "重建Hosts文件列表" >> $LOG_FILE

    rm -rf $fp/hosts.txt
    rm /tmp/upload/hosts.txt
    find $fp  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $fp/hosts.txt
    ln -sf $fp/hosts.txt /tmp/upload/hosts.txt
    echo_date "Hosts文件删除完毕" >>"$LOG_FILE"
}

case $2 in
32)
    set_lock
	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "删除Hosts文件" >> $LOG_FILE
	start_online_del >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
	unset_lock
	;;
esac
