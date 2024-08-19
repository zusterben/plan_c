#!/bin/sh

source /jffs/softcenter/scripts/base.sh
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

eval `dbus export merlinclash_`

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
mscr=$(get merlinclash_select_clash_restart)
mscrm=$(get merlinclash_select_clash_restart_minute)
mscrh=$(get merlinclash_select_clash_restart_hour)
mscrw=$(get merlinclash_select_clash_restart_week)
mscrd=$(get merlinclash_select_clash_restart_day)
mscrm_2=$(get merlinclash_select_clash_restart_minute_2)
remove_clash_restart_regularly(){
	if [ -n "$(cru l|grep clash_restart)" ]; then
		
		sed -i '/clash_restart/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}
start_clash_restart_regularly_day(){
	remove_clash_restart_regularly
	cru a clash_restart ${mscrm} ${mscrh}" * * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
}
start_clash_restart_regularly_week(){
	remove_clash_restart_regularly
	cru a clash_restart ${mscrm} ${mscrh}" * * "${mscrw}" /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
}
start_clash_restart_regularly_month(){
	remove_clash_restart_regularly
	cru a clash_restart ${mscrm} ${mscrh} ${mscrd}" * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"

}
start_clash_restart_regularly_mhour(){
	remove_clash_restart_regularly
	if [ "$mscrm_2" == "2" ] || [ "$mscrm_2" == "5" ] || [ "$mscrm_2" == "10" ] || [ "$mscrm_2" == "15" ] || [ "$mscrm_2" == "20" ] || [ "$mscrm_2" == "25" ] || [ "$mscrm_2" == "30" ]; then
		cru a clash_restart "*/"${mscrm_2}" * * * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
	fi
	if [ "$mscrm_2" == "1" ] || [ "$mscrm_2" == "3" ] || [ "$mscrm_2" == "6" ] || [ "$mscrm_2" == "12" ]; then
		cru a clash_restart "0 */"${mscrm_2} "* * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
	fi
}

case $mscr in
1)
	remove_clash_restart_regularly
	http_response "close"
	;;
2)
	start_clash_restart_regularly_day
	http_response "open"
	;;
3)
	start_clash_restart_regularly_week
	http_response "open"
	;;
4)
	start_clash_restart_regularly_month
	http_response "open"
	;;
5)
	start_clash_restart_regularly_mhour
	http_response "open"
	;;
*)
	remove_clash_restart_regularly
	http_response "close"
	;;
esac
