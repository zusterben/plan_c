#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval `dbus export merlinclash`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
mkdir -p /tmp/upload
LOG_FILE=/tmp/upload/merlinclash_log.txt
SIMLOG_FILE=/tmp/upload/merlinclash_simlog.txt
rm -rf $LOG_FILE
rm -rf $SIMLOG_FILE
echo "" > /tmp/upload/merlinclash_log.txt
echo "" > $SIMLOG_FILE
http_response "$1"

prepare(){
	[ -n "`cat /etc/dnsmasq.conf|grep no-resolv`" ] && sed -i '/no-resolv/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep servers-file`" ] && sed -i '/servers-file/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br1`" ] && sed -i '/dhcp-option-force=br1/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br2`" ] && sed -i '/dhcp-option-force=br2/d' /etc/dnsmasq.conf
}

start_rebuild(){

	echo_date "重建yaml文件列表" >> $LOG_FILE
	find /jffs/softcenter/merlinclash/yaml_bak  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
	#
	echo_date "重建Hosts文件列表" >> $LOG_FILE
	find /jffs/softcenter/merlinclash/yaml_basic/host  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_basic/host/hosts.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/host/hosts.txt /tmp/upload/hosts.txt

	echo_date "下拉列表重建完成" >> $LOG_FILE
}

start_hot_off(){
	echo_date "MC开始热关闭" >> $LOG_FILE
	rm -rf /jffs/scripts/dnsmasq.postconf
	prepare
	sed -i '$a no-resolv' /etc/dnsmasq.conf
	sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
	sh /jffs/softcenter/merlinclash/clashconfig.sh stop
	echo_date "MC热关闭结束" >> $LOG_FILE
}

start_cool_off(){
	echo_date "MC开始冷关闭" >> $LOG_FILE
	rm -rf /jffs/scripts/dnsmasq.postconf
	prepare
	sed -i '$a no-resolv' /etc/dnsmasq.conf
	sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
	dbus set merlinclash_enable=0
	echo_date "已经关闭Merlin Clash开机启动，5秒后重启路由器！！！" >> $LOG_FILE
	sleep 5
	reboot
}

case $2 in
rebuild)
	start_rebuild
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
hot_off_mc)
	start_hot_off
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
cool_off_mc)
	start_cool_off
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
esac
