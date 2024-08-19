#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

#echo_date "download" >> $LOG_FILE
#echo_date "定位文件" >> $LOG_FILE


backup_conf(){
	dbus list merlinclash_nokpacl_ |  sed 's/=/=\"/' | sed 's/$/\"/g'|sed 's/^/dbus set /' | sed '1 isource /jffs/softcenter/scripts/base.sh' |sed '1 i#!/bin/sh' > /tmp/upload/clash_passdevicebackup.sh
}

remove_silent(){
	echo_date 先清除已有的参数... >> $LOG_FILE

	nokpacls=`dbus list merlinclash_nokpacl_ | cut -d "=" -f 1`
	for nokpacl in $nokpacls
	do
		echo_date 移除$nokpacl 
		dbus remove $nokpacl
	done
	echo_date "--------------------"
}

restore_sh(){
	echo_date 检测到绕行设置备份文件... >> $LOG_FILE
	echo_date 开始恢复... >> $LOG_FILE
	chmod +x /tmp/upload/clash_passdevicebackup.sh
	sh /tmp/upload/clash_passdevicebackup.sh
	echo_date 配置恢复成功！>> $LOG_FILE
}
restore_now(){
	[ -f "/tmp/upload/clash_passdevicebackup.sh" ] && restore_sh
	echo_date 一点点清理工作... >> $LOG_FILE
	rm -rf /tmp/upload/clash_passdevicebackup.sh
	echo_date 完成！>> $LOG_FILE
}

case $2 in
1)
	backup_conf
	http_response "$1"
	;;
24)
	echo "还原绕行设置" > $LOG_FILE
	http_response "$1"
	remove_silent 
	restore_now 
	echo BBABBBBC >>  $LOG_FILE
	;;
esac
