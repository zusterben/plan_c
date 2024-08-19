#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

rm -rf /tmp/upload/clash_ipsetproxyarround.log
rm -rf /tmp/upload/clash_ipsetproxyarround.txt
rm -rf /tmp/upload/clash_kpipsetarround.log
rm -rf /tmp/upload/clash_kpipsetarround.txt
b(){
	if [ -f "/bin/base64" ]; then #HND是这个
		base=base64
		echo "$base -d"
	elif [ -f "/jffs/softcenter/bin/base64_decode" ]; then #HND有这个
		base=base64_decode
		echo $base
	elif [ -f "/sbin/base64" ]; then
		base=base64
		echo "$base -d"
	else
		echo_date "【错误】固件缺少base64decode文件，无法正常订阅，直接退出" >> $LOG_FILE
		echo_date "解决办法请查看MerlinClash Wiki" >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}
detect_domain() {
	domain1=$(echo $1 | grep -E "^https://|^http://")
	domain2=$(echo $1 | grep -E "\.")
	if [ -n "$domain1" ] || [ -z "$domain2" ]; then
		return 1
	else
		return 0
	fi
}
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
decode_url_link(){
	local link=$1
	local len=$(echo $link | wc -L)
	local mod4=$(($len%4))
	b64=$(b)
#	echo_date "b64=$b64" >> LOG_FILE
	if [ "$mod4" -gt "0" ]; then
		local var="===="
		local newlink=${link}${var:$mod4}
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	fi
}
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
dnslistenport=$(cat $yamlpath | awk -F: '/listen/{print $3}' | xargs echo -n)
restart_dnsmasq() {
    # Restart dnsmasq
	echo_date "重启 dnsmasq..." >> $LOG_FILE
    service restart_dnsmasq >/dev/null 2>&1
}
apply_dnsmasq(){
	sed -i '/^ *$/d' /jffs/softcenter/merlinclash/yaml_basic/$1.yaml
	case $1 in
	kpipsetarround)
		ipset -F white_koolproxy >/dev/null 2>&1
		if [ -s "/jffs/softcenter/merlinclash/yaml_basic/kpipsetarround.yaml" ]; then
			if [ "$2" != "kp" ]; then
				echo_date "创建KP自定义绕行规则集" > $LOG_FILE
			fi
			rm -rf /tmp/kpipsetarround.list
			cp -rf /jffs/softcenter/merlinclash/yaml_basic/kpipsetarround.yaml /tmp/kpipsetarround.list 2>/dev/null
			rm -rf /tmp/clash_kpipsetarround_tmp.txt
			rm -rf /tmp/clash_kpipsetarround_tmp2.txt
			rm -rf /jffs/softcenter/merlinclash/conf/kpipsetarround.conf
			
			lines=$(cat /tmp/kpipsetarround.list | awk '{print $0}')
			for line in $lines
			do
				#先检测是否为IP格式
				detect_ip ${line}
				e=$?
				if [ "$e" == "4" ]; then
					echo_date "${line}为合法IPv4格式，进行处理" >> $LOG_FILE
					ipset -! add white_koolproxy ${line} >/dev/null 2>&1
				elif [ "$e" == "6" ]; then
					echo_date "${line}为合法IPv6格式，目前未支持IPV6地址，略过" >> $LOG_FILE
					continue
				else
					echo_date "${line}不为IP格式，检查是否为域名地址" >> $LOG_FILE
					detect_domain ${line}
					if [ "$?" == "0" ]; then
						echo_date "${line}为合法域名格式，进行处理" >> $LOG_FILE
						nslookup "${line}" 127.0.0.1:${dnslistenport} > /tmp/clash_kpipsetarround_tmp.txt
						cat /tmp/clash_kpipsetarround_tmp.txt | grep -n "^Address" | awk -F " " '{print $3}' | grep -v "127.0.0.1" > /tmp/clash_kpipsetarround_tmp2.txt #域名解析结果可能含有V4跟V6地址。下一步再进行筛选
						lines=$(cat /tmp/clash_kpipsetarround_tmp2.txt | awk '{print $0}')
						for line2 in $lines
						do
							detect_ip ${line2}
							f=$?
							if [ "$f" == "4" ]; then
								#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
								ipset -! add white_koolproxy ${line2} >/dev/null 2>&1
							elif [ "$f" == "6" ]; then
								#echo_date "为合法IPV6格式，进行处理" >> $LOG_FILE
								continue
							fi
						done
						
						echo "$line" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_koolproxy/g" >> /jffs/softcenter/merlinclash/conf/kpipsetarround.conf
					else
						echo_date "格式有误，略过" >> $LOG_FILE
					fi
				fi
			done
		else
			rm -rf /jffs/softcenter/merlinclash/conf/kpipsetarround.conf
		fi
		rm -rf /tmp/etc/dnsmasq.user/kpipsetarround.conf >/dev/null 2>&1
		if [ -f "/jffs/softcenter/merlinclash/conf/kpipsetarround.conf" ]; then
			ln -sf /jffs/softcenter/merlinclash/conf/kpipsetarround.conf /tmp/etc/dnsmasq.user/kpipsetarround.conf >/dev/null 2>&1
			echo_date "【完成】/jffs/softcenter/merlinclash/conf/kpipsetarround.conf文件创建成功！" >> $LOG_FILE
		fi
		if [ "$2" != "kp" ]; then
			restart_dnsmasq
		fi
		;;
	ipsetproxyarround)
		ipset -F ipset_proxyarround >/dev/null 2>&1
		if [ -s "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml" ]; then
			if [ "$2" != "ip" ]; then
				echo_date "创建强制绕行Clash的ipset规则集" > $LOG_FILE
			fi
			rm -rf /tmp/ipset_proxyarround.list
			cp -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml /tmp/ipset_proxyarround.list 2>/dev/null
			#rm -rf /tmp/clash_ipsetproxyarround.txt
			#rm -rf /tmp/clash_ipsetproxyarround6.txt
			rm -rf /tmp/clash_ipsetproxyarround_tmp.txt
			rm -rf /tmp/clash_ipsetproxyarround_tmp2.txt
			rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf
			
			lines=$(cat /tmp/ipset_proxyarround.list | awk '{print $0}')
			for line in $lines
			do
				#先检测是否为IP格式
				detect_ip ${line}
				a=$?
				if [ "$a" == "4" ]; then
					echo_date "${line}为合法IPv4格式，进行处理" >> $LOG_FILE
					#echo ${line} >> /tmp/clash_ipsetproxyarround.txt
					ipset -! add ipset_proxyarround ${line} >/dev/null 2>&1
				elif [ "$a" == "6" ]; then
					echo_date "${line}为合法IPv6格式，进行处理" >> $LOG_FILE
					#echo ${line} >> /tmp/clash_ipsetproxyarround6.txt
					ipset -! add ipset_proxyarround6 ${line} >/dev/null 2>&1
				else
					echo_date "${line}不为IP格式，检查是否为域名地址" >> $LOG_FILE
					detect_domain ${line}
					if [ "$?" == "0" ]; then
						echo_date "${line}为合法域名格式，进行处理" >> $LOG_FILE
						nslookup "${line}" 127.0.0.1:${dnslistenport} > /tmp/clash_ipsetproxyarround_tmp.txt
						cat /tmp/clash_ipsetproxyarround_tmp.txt | grep -n "^Address" | awk -F " " '{print $3}' | grep -v "127.0.0.1" > /tmp/clash_ipsetproxyarround_tmp2.txt #域名解析结果可能含有V4跟V6地址。下一步再进行筛选
						lines=$(cat /tmp/clash_ipsetproxyarround_tmp2.txt | awk '{print $0}')
						for line2 in $lines
						do
							detect_ip ${line2}
							b=$?
							if [ "$b" == "4" ]; then
								#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
								#echo ${line2} >> /tmp/clash_ipsetproxyarround.txt
								ipset -! add ipset_proxyarround ${line2} >/dev/null 2>&1
							elif [ "$b" == "6" ]; then
								#echo_date "为合法IPV6格式，进行处理" >> $LOG_FILE
								#echo ${line2} >> /tmp/clash_ipsetproxyarround6.txt
								ipset -! add ipset_proxyarround6 ${line2} >/dev/null 2>&1
							fi
						done
						
						echo "$line" | sed "s/^/ipset=&\/./g" | sed "s/$/\/ipset_proxyarround/g" >> /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf
					else
						echo_date "格式有误，略过" >> $LOG_FILE
					fi
				fi
			done
		else
			rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf
		fi
		rm -rf /tmp/etc/dnsmasq.user/ipsetproxyarround.conf >/dev/null 2>&1
		if [ -f "/jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf" ]; then
			ln -sf /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf /tmp/etc/dnsmasq.user/ipsetproxyarround.conf >/dev/null 2>&1
			echo_date "【完成】/jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf文件创建成功！" >> $LOG_FILE
		fi
		if [ "$2" != "ip" ]; then
			restart_dnsmasq
		fi
		;;
	esac
}
case $2 in
koolproxy)
	mkpiec=$(get merlinclash_koolproxy_ipsetarround_edit_content1)
	kpipsetproxyarround=$(decode_url_link $mkpiec)
	echo -e "$kpipsetproxyarround" > /jffs/softcenter/merlinclash/yaml_basic/kpipsetarround.yaml
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/kpipsetarround.yaml /tmp/upload/clash_kpipsetarround.txt

	echo_date "生成koolproxy-ipset集文件" >> /tmp/upload/clash_kpipsetarround.log
	apply_dnsmasq "kpipsetarround"
	echo BBABBBBC >> $LOG_FILE
	;;
kp)
	apply_dnsmasq "kpipsetarround" "kp"
	;;
ipsetproxy)
	miec=$(get merlinclash_ipsetproxyarround_edit_content1)

	ipsetproxyarround=$(decode_url_link $miec)

	echo -e "$ipsetproxyarround" > /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml /tmp/upload/clash_ipsetproxyarround.txt

	echo_date "生成ipset集文件" >> /tmp/upload/clash_ipsetproxyarround.log
	apply_dnsmasq "ipsetproxyarround"
	echo BBABBBBC >> $LOG_FILE
	;;
ip)
	apply_dnsmasq "ipsetproxyarround" "ip"
	;;
esac


if [ "$1" != "ip" ] && [ "$1" != "kp" ]; then
	http_response "$1"
fi
