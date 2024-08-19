#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/tmp/ipdb_update.lock
rm -rf $LOG_FILE



start_geoip_update(){
    sleep 1
    
    echo_date "下载更新GeoIP数据库..." >> $LOG_FILE
    sh /jffs/softcenter/scripts/clash_update_ipdb_sub.sh down #>/dev/null 2>&1 &
    
}

set_lock(){
	exec 233>"$LOCK_FILE"
	flock -n 233 || {
		echo_date "数据库升级已经在运行，请稍候再试！" >> $LOG_FILE	
		unset_lock
	}
}

unset_lock(){
	flock -u 233
	rm -rf "$LOCK_FILE"
}

case $2 in
5)
	set_lock

	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "数据库更新" >> $LOG_FILE
	start_geoip_update >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
	unset_lock
	;;
esac
