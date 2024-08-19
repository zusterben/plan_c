#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

LOG_FILE=/tmp/upload/merlinclash_log.txt

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}

yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
me=$(get merlinclash_enable)
d2s=$(get merlinclash_d2s)
d2s_dnsnp=$(get merlinclash_d2s_dnsnp)
d2s_lp=$(get merlinclash_d2s_lp)
socksport=$(cat $yamlpath | awk -F: '/^socks-port/{print $2}' | xargs echo -n)
if [ "$me" == "1" ] && [ "$d2s" == "1" ]; then
    #echo_date "开始检查进程状态..."
    a=$(ps | grep mc_dns2socks | grep -v grep | awk '{print $1}')
    if [ ! -n "$a" ]; then
        logger "[WatchDog]Merlin Clash重启dns2socks"
        echo_date "[WatchDog]Merlin Clash重启dns2socks" >> $LOG_FILE
        /jffs/softcenter/bin/mc_dns2socks 127.0.0.1:${socksport} ${d2s_dnsnp} 127.0.0.1:${d2s_lp} >/dev/null  2>&1 &
    fi
fi
