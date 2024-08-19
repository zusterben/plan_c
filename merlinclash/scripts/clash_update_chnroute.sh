#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/var/lock/chnroute_update.lock
rm -rf $LOG_FILE



start_chnroute_update(){
    sleep 1
    
    echo_date "下载更新大陆白名单规则..." >> $LOG_FILE
    sh /jffs/softcenter/scripts/clash_update_chnroute_sub.sh down #>/dev/null 2>&1 &
    
}

set_lock(){
	exec 233>"$LOCK_FILE"
	flock -n 233 || {
		echo_date "大陆白名单规则更新已经在运行，请稍候再试！" >> $LOG_FILE	
		unset_lock
	}
}

unset_lock(){
	flock -u 233
	rm -rf "$LOCK_FILE"
}

case $2 in
25)
	set_lock

	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "大陆白名单更新" >> $LOG_FILE
	start_chnroute_update >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
	unset_lock
	;;
esac
