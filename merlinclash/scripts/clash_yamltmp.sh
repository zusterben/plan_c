#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
pid_clash=$(pidof clash)
#pid_watchdog=$(ps | grep clash_watchdog.sh | grep -v grep | awk '{print $1}')
pid_watchdog=$(cru l | grep "clash_watchdog")
date=$(echo_date)
yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
lan_ipaddr=$(nvram get lan_ipaddr)




yamlsel_tmp2=$yamlname

[ ! -L "/tmp/upload/yacd" ] && ln -sf /jffs/softcenter/merlinclash/dashboard/yacd /tmp/upload/
[ ! -L "/tmp/upload/razord" ] && ln -sf /jffs/softcenter/merlinclash/dashboard/razord /tmp/upload/



http_response "$yamlsel_tmp2@"
