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
mcenable=$(get merlinclash_enable)

dnslistenport=$(cat $yamlpath | awk -F: '/listen/{print $3}' | xargs echo -n)

detect_ip(){	
	IPADDR=$1
	regex_v4="\b(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\b"
	regex_v6="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"
	ckStep4=`echo $1 | egrep $regex_v4 | wc -l`
	ckStep6=`echo $1 | egrep $regex_v6 | wc -l`
	if [ $ckStep4 -eq 0 ]; then
		if [ $ckStep6 -eq 0 ]; then
			return 1
		else
			return 6
		fi
	else
		return 4
	fi
}

restart_dnsmasq() {
    # Restart dnsmasq
	rm -rf /tmp/etc/dnsmasq.user/dns_custom.conf >/dev/null 2>&1
	if [ "$mcenable" == "1" ]; then
		echo_date "当前Clash已开启，改写resolv.dnsmasq文件" >> $LOG_FILE
		echo "server=127.0.0.1#${dnslistenport}" > /tmp/resolv.dnsmasq
		if [ "$dnsplan" == "fi" ]; then	
			echo_date "当前为Fake-IP模式，创建/tmp/etc/dnsmasq.user/dns_custom.conf文件" >> $LOG_FILE		
			nameservers=$(cat /tmp/resolv.conf | awk -F " " '/nameserver/{print $2}')
			for nameserver in $nameservers; do
			    detect_ip ${nameserver}
				b=$?
					if [ "$b" == "4" ]; then
					#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
					echo "dhcp-option-force=br1,6,"${nameserver} >> /tmp/etc/dnsmasq.user/dns_custom.conf
				    echo "dhcp-option-force=br2,6,"${nameserver} >> /tmp/etc/dnsmasq.user/dns_custom.conf
					fi
			done
		fi 
	else
		echo_date "当前Clash未开启，从resolv.conf取值还原resolv.dnsmasq文件" >> $LOG_FILE
		rm -rf /tmp/resolv.dnsmasq
		nameservers=$(cat /tmp/resolv.conf | awk -F " " '/nameserver/{print $2}')
		for nameserver in $nameservers; do
			echo "server=$nameserver" >> /tmp/resolv.dnsmasq
		done

	fi
	echo_date "resolv.dnsmasq文件处理完成..." >> $LOG_FILE
    echo_date "重启 dnsmasq..." >> $LOG_FILE
    service restart_dnsmasq >/dev/null 2>&1
}

restart_dnsmasq
