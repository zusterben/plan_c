#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval `dbus export merlinclash`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
mkdir -p /tmp/upload
LOG_FILE=/tmp/upload/merlinclash_log.txt
rm -rf $LOG_FILE
echo "" > /tmp/upload/merlinclash_log.txt
http_response "$1"

restart_dnsmasq() {
	rm -rf /tmp/etc/dnsmasq.user/dns_custom.conf >/dev/null 2>&1
	local LOCAL_DNSISP_DNS1=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
    #local LOCAL_DNSISP_DNS2=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 2p | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
	if [ -n "$LOCAL_DNSISP_DNS1" ]; then
		cat >/etc/resolv.conf <<-EOF
			nameserver $LOCAL_DNSISP_DNS1
		EOF
	else
		cat >/etc/resolv.conf <<-EOF
			nameserver 223.5.5.5
		EOF

	fi
	# Restart dnsmasq
	echo_date "重启dnsmasq服务..."
	service restart_dnsmasq >/dev/null 2>&1 &
	dnsmasqpid=$(pidof dnsmasq)
	for d in $dnsmasqpid; do
		dns_procs=$((procs+1))  
	done
	if [ "${dns_procs}" -gt "1" ]; then
		service restart_dnsmasq >/dev/null 2>&1
	fi
}

prepare_dnsmasq(){
	rm -rf /jffs/scripts/dnsmasq.postconf
	[ -n "`cat /etc/dnsmasq.conf|grep no-resolv`" ] && sed -i '/no-resolv/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep servers-file`" ] && sed -i '/servers-file/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br1`" ] && sed -i '/dhcp-option-force=br1/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br2`" ] && sed -i '/dhcp-option-force=br2/d' /etc/dnsmasq.conf
	#sed -i '$a no-resolv' /etc/dnsmasq.conf
	#sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
}

start_rebuild(){

	echo_date "重建yaml文件列表" >> $LOG_FILE
	find /jffs/softcenter/merlinclash/yaml_bak -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
	echo_date "下拉列表重建完成" >> $LOG_FILE
}

start_hot_off(){
	echo_date "MC开始热关闭" >> $LOG_FILE
	sh /jffs/softcenter/merlinclash/clashconfig.sh stop stop
	echo_date "MC热关闭结束" >> $LOG_FILE
}

start_cool_off(){
	echo_date "MC开始冷关闭" >> $LOG_FILE
	dbus set merlinclash_enable=0
	prepare
	restart_dnsmasq
	echo_date "已经关闭Magic Catling开机启动，5秒后重启路由器！！！" >> $LOG_FILE
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

