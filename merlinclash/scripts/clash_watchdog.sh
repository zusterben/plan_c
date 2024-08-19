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
if [ "$mcenable" == "1" ]; then
    #echo_date "开始检查进程状态..."
    if [ ! -n "$(pidof clash)" ]; then
        #先执行清除缓存
        sync
	    echo 1 > /proc/sys/vm/drop_caches
        sleep 1s
        sh /jffs/softcenter/merlinclash/clashconfig.sh restart >/dev/null 2>&1 &
    #    echo_date "重启 Clash 进程"
    fi
fi
