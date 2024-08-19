#!/bin/sh

source /jffs/softcenter/scripts/base.sh
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/var/lock/merlinclash.lock
eval `dbus export merlinclash`
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
msrm=$(get merlinclash_select_regular_minute)
msrh=$(get merlinclash_select_regular_hour)
msrw=$(get merlinclash_select_regular_week)
msrd=$(get merlinclash_select_regular_day)
msrm_2=$(get merlinclash_select_regular_minute_2)
remove_regular_subscribe(){
	if [ -n "$(cru l|grep regular_subscribe)" ]; then
		
		sed -i '/regular_subscribe/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}
start_regular_subscribe_day(){
	remove_regular_subscribe
	cru a regular_subscribe ${msrm} ${msrh}" * * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
}
start_regular_subscribe_week(){
	remove_regular_subscribe
	cru a regular_subscribe ${msrm} ${msrh}" * * "${msrw}" /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
}
start_regular_subscribe_month(){
	remove_regular_subscribe
	cru a regular_subscribe ${msrm} ${msrh} ${msrd}" * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"

}
start_regular_subscribe_mhour(){
	remove_regular_subscribe
	if [ "$msrm_2" == "2" ] || [ "$msrm_2" == "5" ] || [ "$msrm_2" == "10" ] || [ "$msrm_2" == "15" ] || [ "$msrm_2" == "20" ] || [ "$msrm_2" == "25" ] || [ "$msrm_2" == "30" ]; then
		cru a regular_subscribe "*/"${msrm_2}" * * * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
	fi
	if [ "$msrm_2" == "1" ] || [ "$msrm_2" == "3" ] || [ "$msrm_2" == "6" ] || [ "$msrm_2" == "12" ]; then
		cru a regular_subscribe "0 */"${msrm_2} "* * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
	fi
}

case $merlinclash_select_regular_subscribe in
1)
	remove_regular_subscribe
	http_response "close"
	;;
2)
	start_regular_subscribe_day
	http_response "open"
	;;
3)
	start_regular_subscribe_week
	http_response "open"
	;;
4)
	start_regular_subscribe_month
	http_response "open"
	;;
5)
	start_regular_subscribe_mhour
	http_response "open"
	;;
*)
	remove_regular_subscribe
	http_response "close"
	;;
esac
