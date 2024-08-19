#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

rm -rf /tmp/upload/clash_ipsetproxy.log
rm -rf /tmp/upload/clash_ipsetproxy.txt
rm -rf /tmp/upload/clash_kpipset.log
rm -rf /tmp/upload/clash_kpipset.txt
b(){
	if [ -f "/jffs/softcenter/bin/base64_decode" ]; then #HND有这个
		base=base64_decode
		echo $base
	elif [ -f "/bin/base64" ]; then #HND是这个
		base=base64
		echo "$base -d"
	elif [ -f "/sbin/base64" ]; then
		base=base64
		echo "$base -d"
	else
		echo_date "固件缺少base64decode，无法正常订阅，直接退出" >> $LOG_FILE
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
	echo_date "b64=$b64" >> LOG_FILE
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
	kpipset)
		ipset -F black_koolproxy >/dev/null 2>&1
		if [ -s "/jffs/softcenter/merlinclash/yaml_basic/kpipset.yaml" ]; then
			if [ "$2" != "kp" ]; then
				echo_date "创建KP自定义过滤规则集" > $LOG_FILE
			fi
			rm -rf /tmp/kpipset.list
			cp -rf /jffs/softcenter/merlinclash/yaml_basic/kpipset.yaml /tmp/kpipset.list 2>/dev/null
			rm -rf /tmp/clash_kpipset_tmp.txt
			rm -rf /tmp/clash_kpipset_tmp2.txt
			rm -rf /jffs/softcenter/merlinclash/conf/kpipset.conf
			
			lines=$(cat /tmp/kpipset.list | awk '{print $0}')
			for line in $lines
			do
				#先检测是否为IP格式
				detect_ip ${line}
				c=$?
				if [ "$c" == "4" ]; then
					echo_date "${line}为合法IPv4格式，进行处理" >> $LOG_FILE
					ipset -! add black_koolproxy ${line} >/dev/null 2>&1
				elif [ "$c" == "6" ]; then
					echo_date "${line}为合法IPv6格式，目前未支持IPV6地址，略过" >> $LOG_FILE
					continue
				else
					echo_date "${line}不为IP格式，检查是否为域名地址" >> $LOG_FILE
					detect_domain ${line}
					if [ "$?" == "0" ]; then
						echo_date "${line}为合法域名格式，进行处理" >> $LOG_FILE
						nslookup "${line}" 127.0.0.1:${dnslistenport} > /tmp/clash_kpipset_tmp.txt
						cat /tmp/clash_kpipset_tmp.txt | grep -n "^Address" | awk -F " " '{print $3}' | grep -v "127.0.0.1" > /tmp/clash_kpipset_tmp2.txt #域名解析结果可能含有V4跟V6地址。下一步再进行筛选
						lines=$(cat /tmp/clash_kpipset_tmp2.txt | awk '{print $0}')
						for line2 in $lines
						do
							detect_ip ${line2}
							d=$?
							if [ "$d" == "4" ]; then
								#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
								ipset -! add black_koolproxy ${line2} >/dev/null 2>&1
							elif [ "$d" == "6" ]; then
								#echo_date "为合法IPV6格式，进行处理" >> $LOG_FILE
								continue
							fi
						done
						
						echo "$line" | sed "s/^/ipset=&\/./g" | sed "s/$/\/black_koolproxy/g" >> /jffs/softcenter/merlinclash/conf/kpipset.conf
					else
						echo_date "格式有误，略过" >> $LOG_FILE
					fi
				fi
			done
		else
			rm -rf /jffs/softcenter/merlinclash/conf/kpipset.conf
		fi
		rm -rf /tmp/etc/dnsmasq.user/kpipset.conf >/dev/null 2>&1
		if [ -f "/jffs/softcenter/merlinclash/conf/kpipset.conf" ]; then
			ln -sf /jffs/softcenter/merlinclash/conf/kpipset.conf /tmp/etc/dnsmasq.user/kpipset.conf >/dev/null 2>&1
			echo_date "【完成】/jffs/softcenter/merlinclash/conf/kpipset.conf文件创建成功！" >> $LOG_FILE
		fi
		if [ "$2" != "kp" ]; then
			restart_dnsmasq
		fi
		;;
	ipsetproxy)
		ipset -F ipset_proxy >/dev/null 2>&1
		if [ -s "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml" ]; then
			if [ "$2" != "ip" ]; then
				echo_date "创建强制转发到Clash的ipset规则集" > $LOG_FILE
			fi
			rm -rf /tmp/ipset_proxy.list
			cp -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml /tmp/ipset_proxy.list 2>/dev/null
			#rm -rf /tmp/clash_ipsetproxy.txt
			#rm -rf /tmp/clash_ipsetproxy6.txt
			rm -rf /tmp/clash_ipsetproxy_tmp.txt
			rm -rf /tmp/clash_ipsetproxy_tmp2.txt
			#echo "create ipset_proxy hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipset_proxy.ipset
			#echo "create ipset_proxy6 hash:net family inet6" >/jffs/softcenter/res/ipset_proxy6.ipset
			rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxy.conf
			
			lines=$(cat /tmp/ipset_proxy.list | awk '{print $0}')
			for line in $lines
			do
				#先检测是否为IP格式
				detect_ip ${line}
				a=$?
				if [ "$a" == "4" ]; then
					echo_date "${line}为合法IPv4格式，进行处理" >> $LOG_FILE
					#echo ${line} >> /tmp/clash_ipsetproxy.txt
					ipset -! add ipset_proxy ${line} >/dev/null 2>&1
				elif [ "$a" == "6" ]; then
					echo_date "${line}为合法IPv6格式，进行处理" >> $LOG_FILE
					ipset -! add ipset_proxy6 ${line} >/dev/null 2>&1
				else
					echo_date "${line}不为IP格式，检查是否为域名地址" >> $LOG_FILE
					detect_domain ${line}
					if [ "$?" == "0" ]; then
						echo_date "${line}为合法域名格式，进行处理" >> $LOG_FILE
						nslookup "${line}" 127.0.0.1:${dnslistenport} > /tmp/clash_ipsetproxy_tmp.txt
						cat /tmp/clash_ipsetproxy_tmp.txt | grep -n "^Address" | awk -F " " '{print $3}' | grep -v "127.0.0.1" > /tmp/clash_ipsetproxy_tmp2.txt #域名解析结果可能含有V4跟V6地址。下一步再进行筛选
						lines=$(cat /tmp/clash_ipsetproxy_tmp2.txt | awk '{print $0}')
						for line2 in $lines
						do
							detect_ip ${line2}
							b=$?
							if [ "$b" == "4" ]; then
								#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
								ipset -! add ipset_proxy ${line2} >/dev/null 2>&1
							elif [ "$b" == "6" ]; then
								#echo_date "为合法IPV6格式，进行处理" >> $LOG_FILE
								ipset -! add ipset_proxy6 ${line2} >/dev/null 2>&1
							fi
						done
						
						echo "$line" | sed "s/^/ipset=&\/./g" | sed "s/$/\/ipset_proxy/g" >> /jffs/softcenter/merlinclash/conf/ipsetproxy.conf
					else
						echo_date "格式有误，略过" >> $LOG_FILE
					fi
				fi
			done
		else
			rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxy.conf
		fi
		rm -rf /tmp/etc/dnsmasq.user/ipsetproxy.conf >/dev/null 2>&1
		if [ -f "/jffs/softcenter/merlinclash/conf/ipsetproxy.conf" ]; then
			ln -sf /jffs/softcenter/merlinclash/conf/ipsetproxy.conf /tmp/etc/dnsmasq.user/ipsetproxy.conf >/dev/null 2>&1
			echo_date "【完成】/jffs/softcenter/merlinclash/conf/ipsetproxy.conf文件创建成功！" >> $LOG_FILE
		fi
		if [ "$2" != "ip" ]; then
			restart_dnsmasq
		fi
		;;
	esac
}
case $2 in
koolproxy)
	mkpiec=$(get merlinclash_koolproxy_ipset_edit_content1)

	kpipset=$(decode_url_link $mkpiec)

	echo -e "$kpipset" > /jffs/softcenter/merlinclash/yaml_basic/kpipset.yaml
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/kpipset.yaml /tmp/upload/clash_kpipset.txt

	echo_date "生成koolproxy-ipset集文件" >> /tmp/upload/clash_kpipset.log
	apply_dnsmasq "kpipset"
	echo BBABBBBC >> $LOG_FILE
	;;
kp)
	apply_dnsmasq "kpipset" "kp"
	;;
ipsetproxy)
	miec=$(get merlinclash_ipsetproxy_edit_content1)

	ipsetproxy=$(decode_url_link $miec)

	echo -e "$ipsetproxy" > /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml /tmp/upload/clash_ipsetproxy.txt

	echo_date "生成ipset集文件" >> /tmp/upload/clash_ipsetproxy.log
	apply_dnsmasq "ipsetproxy"
	echo BBABBBBC >> $LOG_FILE
	;;
ip)
	apply_dnsmasq "ipsetproxy" "ip"
	;;
esac

if [ "$1" != "ip" ] && [ "$1" != "kp" ]; then
	http_response "$1"
fi
