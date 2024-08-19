#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
mcenable=$(get merlinclash_enable)
mcwatchdog=$(get merlinclash_watchdog)
mcwatchdog_dtime=$(get merlinclash_watchdog_delay_time)
if [ "$mcenable" == "1" ] && [ "$mcwatchdog" == "1" ];then
		sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		watcdogtime=$mcwatchdog_dtime
		cru a clash_watchdog "*/$watcdogtime * * * * /bin/sh /jffs/softcenter/scripts/clash_watchdog.sh"
	#	/bin/sh /jffs/softcenter/scripts/clash_watchdog.sh >/dev/null 2>&1 &
else
	#pid_watchdog=$(ps | grep clash_watchdog.sh | grep -v grep | awk '{print $1}')
	#if [ -n "$pid_watchdog" ]; then
	#echo_date 关闭看门狗... >> $LOG_FILE
	# 有时候killall杀不了v2ray进程，所以用不同方式杀两次
	#kill -9 "$pid_watchdog" >/dev/null 2>&1
	sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	#fi
fi
http_response "$1"
