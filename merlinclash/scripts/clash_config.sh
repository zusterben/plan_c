#!/bin/sh

source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
alias echo_date2='echo 【$(date +%Y年%m月%d日\ %X)】'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
eval $(dbus export merlinclash_)
mkdir -p /tmp/upload

#内核进程启动成功检测标志
clash_process_started="0"
#ipv6代理标志
ipv6_flag="0"
# 路由标记值
mcrm="524288"
### 全局变量赋值
yamlname=${merlinclash_set_yamlsel_start}
mcenable=${merlinclash_enable}
dnshijacksel=${merlinclash_dns_dnshijack_sw}
dfib=${merlinclash_dns_fakeip_server}
cusruleplan=${merlinclash_acl_plan}
retryTimes=${merlinclash_set_logcheck_val}
tproxymode=${merlinclash_ipt_tproxy_type}
cirswitch=${merlinclash_set_chnroute_sw}
ipv6switch=${merlinclash_ipt_ipv6_sw}
dnsplan=${merlinclash_dns_type}
dnsgoclash=${merlinclash_ipt_proxyrouter_sw}
dnsinclash=${merlinclash_dns_proxydns_sw}

#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml

#IP获取
ISP_DNS1=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
ISP_DNS2=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 2p)
DHCP_DNS1=$(nvram get dhcp_dns1_x | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
IFIP_DNS1=$(echo $ISP_DNS1 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
IFIP_DNS2=$(echo $ISP_DNS2 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
IFIP_DHCPDNS1=$(echo $DHCP_DNS1 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
lan_ipaddr=$(nvram get lan_ipaddr)
wan_ipaddr=$(nvram get wan0_ipaddr)
#取公网接口-
ip_prefix_hex=$(nvram get lan_ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
opvpn_prefix_hex=$(nvram get vpn_server_local | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
pptpvpn_prefix_hex=$(nvram get pptpd_clients | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
ipsec_prefix_hex=$(nvram get ipsec_profile_1 | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')

mkdir -p /tmp/upload


ipv6_mode(){
	[ -n "$(ip addr | grep -w inet6 | awk '{print $2}')" ] && echo true || echo false
}

get_wan0_cidr() {
	local netmask=$(nvram get wan0_netmask)
	local x=${netmask##*255.}
	set -- 0^^^128^192^224^240^248^252^254^ $(((${#netmask} - ${#x}) * 2)) ${x%%.*}
	x=${1%%$3*}
	suffix=$(($2 + (${#x} / 4)))
	prefix=$(nvram get wan0_ipaddr)
	if [ -n "$prefix" -a -n "$netmask" ]; then
		echo $prefix/$suffix
	else
		echo ""
	fi
}

### 进程启动状态检测
detect_running_status(){
	local BINNAME=$1
	local PIDFILE=$2
	local PID1
	local PID2
	local i=40
	if [ -n "${PIDFILE}" ];then
		until [ -n "${PID1}" -a -n "${PID2}" -a -n $(echo ${PID1} | grep -Eow ${PID2} 2>/dev/null) ]; do
			usleep 250000
			i=$(($i - 1))
			PID1=$(pidof ${BINNAME})
			PID2=$(cat ${PIDFILE})
			if [ "$i" -lt 1 ]; then
				echo_date "$1进程启动失败！" >> $LOG_FILE
				#return 1
				close_in_five
			fi
		done
		echo_date "$1启动成功！pid：${PID2}"
	else
		until [ -n "${PID1}" ]; do
			usleep 250000
			i=$(($i - 1))
			PID1=$(pidof ${BINNAME})
			if [ "$i" -lt 1 ]; then
				echo_date "$1进程启动失败！" >> $LOG_FILE
				#return 1
				close_in_five
			fi
		done
		echo_date "$1启动成功，pid：${PID1}" >> $LOG_FILE
	fi
}

### dnsmasq处理
restart_dnsmasq() {
	local DLC=$(nvram get dns_local_cache)
	if [ "$DLC" == "1" ]; then
		nvram set dns_local_cache=0
		nvram commit
	fi
	# 根据情况写路由本机DNS，Fake ip情况下不可使用MC的代理
	local LOCAL_DNSISP_DNS1=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
	local LOCAL_DNSISP_DNS2=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 2p | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
	local LOCAL_DNSISP_DNSv6=$(nvram get ipv6_get_dns | awk '{print $1}' | grep -v '^::$' | grep -v '^::1$' | head -1)
	if [ "$mcenable" = "1" ] && [ "$dnsinclash" = "1" ] && [ "${clash_process_started}" = "1" ]; then
		# 代理路由dns
		if [ "$dnsplan" = "rh" ]; then
			if [ "$(nvram get smartdns_enable)" == "1" ]; then
				echo "nameserver 127.0.0.1" > /etc/resolv.smartdns
			else
				echo "nameserver 127.0.0.1" > /etc/resolv.conf
			fi
		elif [ -n "$LOCAL_DNSISP_DNS1" ] || [ -n "$LOCAL_DNSISP_DNS2" ] || [ -n "$LOCAL_DNSISP_DNSv6" ]; then
			# 有任何一个 DNS 变量非空 → 写入所有非空的
			if [ "$(nvram get smartdns_enable)" == "1" ]; then
				[ -n "$(cat /tmp/resolv.smartdns | grep 9053)" ] || service restart_wan_dns
			else
				{
					[ -n "$LOCAL_DNSISP_DNS1" ] && echo "nameserver $LOCAL_DNSISP_DNS1"
					[ -n "$LOCAL_DNSISP_DNS2" ] && echo "nameserver $LOCAL_DNSISP_DNS2"
					[ -n "$LOCAL_DNSISP_DNSv6" ] && echo "nameserver $LOCAL_DNSISP_DNSv6"
				} > /etc/resolv.conf
			fi
		fi
	elif [ -n "$LOCAL_DNSISP_DNS1" ] || [ -n "$LOCAL_DNSISP_DNS2" ] || [ -n "$LOCAL_DNSISP_DNSv6" ]; then
		# 非代理路由dns，且有至少一个 DNS 变量非空
		if [ "$(nvram get smartdns_enable)" == "1" ]; then
			[ -n "$(cat /tmp/resolv.smartdns | grep 9053)" ] || service restart_wan_dns
		else
			{
				[ -n "$LOCAL_DNSISP_DNS1" ] && echo "nameserver $LOCAL_DNSISP_DNS1"
				[ -n "$LOCAL_DNSISP_DNS2" ] && echo "nameserver $LOCAL_DNSISP_DNS2"
				[ -n "$LOCAL_DNSISP_DNSv6" ] && echo "nameserver $LOCAL_DNSISP_DNSv6"
			} > /etc/resolv.conf
		fi
	fi
	echo_date "创建dnsmasq.postconf软链接" >> $LOG_FILE
	local link_dns_target=$(readlink "/jffs/scripts/dnsmasq.postconf")
#	local link_sdn_target=$(readlink "/jffs/scripts/dnsmasq-sdn.postconf")
	if [ "$link_dns_target" != "/jffs/softcenter/merlinclash/conf/dnsmasq.postconf" ]; then
		ln -sf /jffs/softcenter/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq.postconf
	fi
#	if [ "$link_sdn_target" != "/jffs/softcenter/merlinclash/conf/dnsmasq.postconf" ]; then
#		ln -sf /jffs/softcenter/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq-sdn.postconf
#	fi
	# Restart dnsmasq
	echo_date "重启dnsmasq服务..." >> $LOG_FILE
	service restart_dnsmasq >/dev/null 2>&1
	detect_running_status dnsmasq
}

### ipset处理
creat_ipset() {
	#创建直连名单
	xt=`lsmod | grep xt_set`
	OS=$(uname -r)
	if [ -z "$xt" ] && [ -f "/lib/modules/${OS}/kernel/net/netfilter/xt_set.ko" ]; then
		echo_date "加载xt_set.ko内核模块！" >> $LOG_FILE
		modprobe xt_set
	fi
	if [ -z "`lsmod | grep ip_set_bitmap_port`" ] && [ -f "/lib/modules/4.1.27/kernel/net/netfilter/ipset/ip_set_bitmap_port.ko" ]; then
		echo_date "加载ip_set_bitmap_port.ko内核模块！"
		modprobe ip_set_bitmap_port
	fi
	[ -n "$IFIP_DNS1" ] && ISP_DNS_a="$ISP_DNS1" || ISP_DNS_a=""
	[ -n "$IFIP_DNS2" ] && ISP_DNS_b="$ISP_DNS2" || ISP_DNS_b=""
	[ -n "$IFIP_DHCPDNS1" ] && ISP_DNS_c="$DHCP_DNS1" || ISP_DNS_c=""
	echo_date "创建内网绕行ipset规则集" >> $LOG_FILE
	ipset -! create direct_list nethash && ipset flush direct_list
	ip_lan="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 255.255.255.255 $ISP_DNS_a $ISP_DNS_b $ISP_DNS_c $(get_wan0_cidr)"
	for ip in $ip_lan; do
		ipset -! add direct_list $ip >/dev/null 2>&1
	done
	if [ $(ipv6_mode) == "true" ]; then
		echo_date "创建内网绕行ipv6-ipset规则集" >> $LOG_FILE
		ipset -! create direct_list6 nethash family inet6 && ipset flush direct_list6
		ip6_lan="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fc00::/7 fe80::/10 ff00::/8"
		for ip6 in $ip6_lan; do
			ipset -! add direct_list6 $ip6 >/dev/null 2>&1
		done
		for a in $(ip addr | grep -w inet6 | awk '{print $2}') ; do 
			ipset -! add direct_list6 $a >/dev/null 2>&1 
		done
		fake_ip_range6=$(yq eval '.dns.fake-ip-range6' /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml)
		ipset -! add direct_list6 $fake_ip_range6 nomatch >/dev/null 2>&1 
	fi
	#
	echo_date "创建clash相关ipset规则集" >> $LOG_FILE
	ipset -! create router nethash
	ipset -! create ipset_proxy nethash
	ipset -! create ipset_proxy6 hash:net family inet6
	ipset -! create ipset_proxyarround nethash
	ipset -! create ipset_proxyarround6 hash:net family inet6
	
	if [ ! -f "/jffs/softcenter/res/china_ip_route.ipset" ]; then
		echo_date "创建大陆IP绕行ipset规则集" >> $LOG_FILE
		cp /jffs/softcenter/merlinclash/yaml_basic/ChinaIP.yaml /tmp/china_ip_route.list 2>/dev/null
		sed -i "s/'//g" /tmp/china_ip_route.list 2>/dev/null
		sed -i "s/^ \{0,\}- //g" /tmp/china_ip_route.list 2>/dev/null
		sed -i '/payload:/d' /tmp/china_ip_route.list 2>/dev/null
		sed -i '/^ \{0,\}#/d' /tmp/china_ip_route.list 2>/dev/null
		echo "create china_ip_route hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/china_ip_route.ipset
		awk '!/^$/&&!/^#/{printf("add china_ip_route %s'" "'\n",$0)}' /tmp/china_ip_route.list >>/jffs/softcenter/res/china_ip_route.ipset
		rm -rf /tmp/china_ip_route.list 2>/dev/null
	fi
	ipset -! flush china_ip_route 2>/dev/null
	ipset -! restore </jffs/softcenter/res/china_ip_route.ipset 2>/dev/null

	if [ $(ipv6_mode) == "true" ]; then
		if [ ! -f "/jffs/softcenter/res/china_ip_route6.ipset" ]; then
			echo_date "创建大陆IP绕行ipv6-ipset规则集" >> $LOG_FILE
			cp /jffs/softcenter/merlinclash/yaml_basic/ChinaIPv6.yaml /tmp/china_ip_route6.list 2>/dev/null
			sed -i "s/'//g" /tmp/china_ip_route6.list 2>/dev/null
			sed -i "s/^ \{0,\}- //g" /tmp/china_ip_route6.list 2>/dev/null
			sed -i '/payload:/d' /tmp/china_ip_route6.list 2>/dev/null
			sed -i '/^ \{0,\}#/d' /tmp/china_ip_route6.list 2>/dev/null
			echo "create china_ip_route6 hash:net family inet6" >/jffs/softcenter/res/china_ip_route6.ipset
			awk '!/^$/&&!/^#/{printf("add china_ip_route6 %s'" "'\n",$0)}' /tmp/china_ip_route6.list >>/jffs/softcenter/res/china_ip_route6.ipset
			rm -rf /tmp/china_ip_route6.list 2>/dev/null
		else
			ipset -! flush china_ip_route6 2>/dev/null
			ipset -! restore </jffs/softcenter/res/china_ip_route6.ipset 2>/dev/null
		fi	
		ipset -! flush china_ip_route6 2>/dev/null
		ipset -! restore </jffs/softcenter/res/china_ip_route6.ipset 2>/dev/null
	fi
	if [ -f "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml" ]; then
		echo_date "开始创建强制转发规则到ipset规则集..." >> $LOG_FILE
		sh /jffs/softcenter/scripts/clash_ipsetproxy.sh 1 ipsetproxy
	fi
	if [ -f "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml" ]; then
		echo_date "开始创建强制绕行规则到ipset规则集..." >> $LOG_FILE
		sh /jffs/softcenter/scripts/clash_ipsetproxy.sh 1 ipsetproxyarround
	fi

}

clean_ipset(){
	rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/ipsetproxyarround.conf >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxy.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/ipsetproxy.conf >/dev/null 2>&1
}

### 启动准备
check_ss(){
	local ss_open=$(dbus get ss_basic_enable)
	
	if [ "${ss_open}" == "1" ]; then
    	echo_date "检测到【科学上网】插件运行中，请先关闭该插件，再运行MerlinClash！" >> $LOG_FILE
		echo_date "...MerlinClash！退出中..." >> $LOG_FILE
		close_in_five	
    else
	    echo_date "没有检测到冲突插件，准备开启MerlinClash！" >> $LOG_FILE
	fi
}

check_yaml(){
	#配合自定规则，此处修改为每次都从BAK恢复原版文件来操作-20200629
	cp -rf /jffs/softcenter/merlinclash/yaml_bak/$yamlname.yaml $yamlpath
	if [ -f "$yamlpath" ]; then
		echo_date "检查到Clash配置文件存在！选中的配置文件是【$yamlname】" >> $LOG_FILE
		#插入一行免得出错
		sed -i '$a' $yamlpath
		#修改订阅后，此处先合并RULE文件，根据自定义规则选择项来进行处理，值为：merlinclash_acl_plan
		# if [ "$cusruleplan" == "closed" ] || [ "$cusruleplan" == "easy" ]; then
		# 	#合并rule_bak默认文件
		# 	cat /jffs/softcenter/merlinclash/rule_bak/${yamlname}_rules.yaml >> $yamlpath
		# else
		# 	cat /jffs/softcenter/merlinclash/rule_use/${yamlname}_rules.yaml >> $yamlpath
		# fi
		#拼接头文件
		sed -i '$a' $yamlpath
		cat /jffs/softcenter/merlinclash/yaml_basic/head.yaml >> $yamlpath
		echo_date "标准头文件合并完毕" >> $LOG_FILE

		#拼接Hosts文件
		echo_date "拼接Host文件" >> $LOG_FILE
		sed -i '$a' $yamlpath
		cat /jffs/softcenter/merlinclash/yaml_basic/hosts.yaml >> $yamlpath
		#SNIFFER拼合
		if [ "${merlinclash_dns_sniffer_sw}" == "1" ]; then
			#插入换行符免得出错
			sed -i '$a' $yamlpath
			echo_date "拼接Sniffer文件" >> $LOG_FILE
			cat /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml >> $yamlpath
		fi
	else
		echo_date "文件丢失，没有找到上传的配置文件！请先上传您的配置文件！" >> $LOG_FILE
		echo_date "...MerlinClash！退出中..." >> $LOG_FILE
		close_in_five
	fi
}

check_dnsplan(){
	#插入换行符免得出错
	sed -i '$a' $yamlpath
	case $dnsplan in
	rh)
		#默认方案
		echo_date "使用DNS方案为：Redir-Host" >> $LOG_FILE
		cat /jffs/softcenter/merlinclash/yaml_dns/redirhost.yaml >> $yamlpath
		;;
	fi)
		#fake-ip方案
		echo_date "使用DNS方案为：Fake-IP" >> $LOG_FILE
		cat /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml >> $yamlpath
		;;
	esac

}
check_rule() {
	/bin/sh /jffs/softcenter/scripts/clash_saveacls.sh push push
	if [ -f "/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml" ]; then
		acl_nu=$(get_list merlinclash_acl_type 1 4)
		num=0
		if [ -n "$acl_nu" ]; then
			# 将acl_nu转换为数组并逆序处理
			acl_list=""
			for acl in $acl_nu; do
				acl_list="$acl $acl_list"
			done
			
			for acl in $acl_list; do
				type=$(get merlinclash_acl_type_$acl)
				content=$(get merlinclash_acl_content_$acl)
				lianjie=$(get merlinclash_acl_lianjie_$acl)
				type=$(decode_url_link "$type")
				content=$(decode_url_link "$content")
				lianjie=$(decode_url_link "$lianjie")
				type=$(urldecode "$type")
				content=$(urldecode "$content")
				lianjie=$(urldecode "$lianjie")
				#写入自定规则到当前配置文件
				num1=$(($num+1))
				echo_date "写入第 $num1 条自定规则到当前配置文件" >> $LOG_FILE
				if [ "$type" == "IP-CIDR" ]; then
					yq eval ".rules = [\"$type,$content,$lianjie,no-resolve\"] + (.rules // [])" -i $yamlpath
				else
					yq eval ".rules = [\"$type,$content,$lianjie\"] + (.rules // [])" -i $yamlpath
				fi
				let num++
			done
		else
			echo_date "没有自定规则" >> $LOG_FILE	
		fi
		dbus remove merlinclash_acl_type
		dbus remove merlinclash_acl_content
		dbus remove merlinclash_acl_lianjie
	fi

}

set_Tolerance(){
	#自定义容差值
	intervalbox=${merlinclash_set_interval_sw}
	urltestbox=${merlinclash_set_tolerance_sw}
	if [ "$intervalbox" == "1" ]; then
		interval=${merlinclash_set_interval_val}
		echo_date "调整测ping时间间隔为: $interval " >> $LOG_FILE
		yq eval -i "(.proxy-groups[] | select(.type == "url-test" or .type == "fallback" or .type == "load-balance")).interval = \"$interval\"" "$yamlpath"
	else
		echo_date "未自定义测ping时间间隔，保持默认" >> $LOG_FILE
		
	fi
	if [ "$urltestbox" == "1" ]; then
		tolerance=${merlinclash_set_tolerance_val}
		echo_date "调整测ping容差为: $tolerance " >> $LOG_FILE
		yq eval -i "(.proxy-groups[] | select(.type == "url-test" or .type == "fallback" or .type == "load-balance")).tolerance = \"$tolerance\"" "$yamlpath"
	
	else
		echo_date "未自定义测ping容差，保持默认" >> $LOG_FILE
		
	fi

}

check_coremark(){
	# 查看当前/jffs的挂载点是什么设备，如/dev/mtdblock9, /dev/sda1；有usb2jffs的时候，/dev/sda1，无usb2jffs的时候，/dev/mtdblock9，出问题未正确挂载的时候，为空
	local cur_patition=$(df -h | /bin/grep /jffs | awk '{print $1}')
	local jffs_device="not mount"
	if [ -n "${cur_patition}" ]; then
  		jffs_device=${cur_patition}
	fi
	local mounted_nu=$(mount | /bin/grep "${jffs_device}" | grep -E "/tmp/mnt/|/jffs"|/bin/grep -c "/dev/s")

	if [ "${merlinclash_set_recordbycron_sw}" != "1" ]; then
		if [ "${mounted_nu}" -eq "2" ]; then
			coremark="1"
		elif [ "${LINUX_VER}" -gt "41" ]; then
			coremark="1"
		else
			coremark="0"
		fi
	else
		echo_date "已开启强制使用定时脚本记录代理组状态" >> $LOG_FILE
		coremark="0"
	fi
	#更新内核版本号
	local ret=$(env -i PATH=${PATH} /jffs/softcenter/bin/clash -v 2>/dev/null | head -n 1)
	local clashTmpV1=$(echo "$ret" | cut -d " " -f2)
	local clashTmpV2=$(echo "$ret" | cut -d " " -f3)
	if [ "$clashTmpV1" = "Meta" ]; then
		merlinclash_binary_ver_tmp="Mihomo $clashTmpV2"; 
	else
		merlinclash_binary_ver_tmp=$clashTmpV1
	fi

	if [ -n "$merlinclash_binary_ver_tmp" ]; then
		mcv="$merlinclash_binary_ver_tmp"		
	else
		mcv="null"
	fi
	dbus set merlinclash_binary_ver="$mcv"

}

start_custom(){

    #内核代理组状态记忆&fake-ip缓存启用
	if [ "${coremark}" == "1" ]; then
		echo_date "开启内核代理组状态记忆及Fake-ip缓存" >> $LOG_FILE
		yq eval ".profile.store-selected = true" -i "$yamlpath"
		yq eval ".profile.store-fake-ip = true" -i "$yamlpath"
	fi

	#开启tcp并发
	if [ "${merlinclash_set_tcpcon_sw}" == "1" ]; then
		yq eval ".tcp-concurrent = true" -i "$yamlpath"
	fi

	#检查redir/tproxy端口，如果没有就写一个
	proxy_port=$(yq eval ".redir-port" "$yamlpath" 2>/dev/null)
	tproxy_port=$(yq eval ".tproxy-port" "$yamlpath" 2>/dev/null)
	if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
		if [ "$proxy_port" == "null" ] || [ -z "$proxy_port" ]; then
			yq eval ".redir-port = 23457" -i "$yamlpath"
		fi
	fi
	if [ "$tproxymode" != "closed" ]; then
		if [ "$tproxy_port" == "null" ] || [ -z "$tproxy_port" ]; then
			yq eval ".tproxy-port = 23458" -i "$yamlpath"
		fi
	fi

	#移除出启动配置文件 http/socks 端口
	if [ "$merlinclash_set_mixport_sw" == "0" ]; then
		echo_date "Http/Socks5代理端口未开启" >> $LOG_FILE
		yq eval -i 'del(.port)' "$yamlpath"
		yq eval -i 'del(.socks-port)' "$yamlpath"
		yq eval -i 'del(.mixed-port)' "$yamlpath"
	fi
	
	#Geo数据库写入
	geoip_lite_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat"
	geoip_full_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat"

	geosite_default_url="https://github.com/flyhigherpi/merlinclash_clash_related/raw/refs/heads/master/geosite/geosite.dat"
	geosite_lite_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite-lite.dat"
	geosite_full_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"

	if [ "${merlinclash_set_geoip_type}" != "head" ] || [ "${merlinclash_set_geosite_type}" != "head" ]; then
		yq eval ".geodata-mode = true" -i "$yamlpath"
	fi
	case "${merlinclash_set_geoip_type}" in
        lite)
            echo_date "设置GeoIP数据库为：GeoIP-Lite" >> $LOG_FILE
			yq eval ".geox-url.geoip = \"$geoip_lite_url\"" -i "$yamlpath"
			;;

        full)
            echo_date "设置GeoIP数据库为：GeoIP-Full" >> $LOG_FILE
			yq eval ".geox-url.geoip = \"$geoip_full_url\"" -i "$yamlpath"
			;;
		head)
			echo_date "GeoIP数据库跟随基础配置，不操作" >> $LOG_FILE
			;;
        *)
        echo_date "未设置GeoIP类型， 默认设置为GeoIP-lite" >> $LOG_FILE
			yq eval ".geox-url.geoip = \"$geoip_lite_url\"" -i "$yamlpath"
			;;
    esac
	#GeoSite数据库写入
	case "${merlinclash_set_geosite_type}" in
		lite)
			echo_date "设置GeoSite数据库为：GeoSite-Lite" >> $LOG_FILE
			yq eval ".geox-url.geosite = \"$geosite_lite_url\"" -i "$yamlpath"
			;;
		full)
			echo_date "设置GeoSite数据库为：GeoSite-Full" >> $LOG_FILE
			yq eval ".geox-url.geosite = \"$geosite_full_url\"" -i "$yamlpath"
			;;
		default)
			echo_date "设置GeoSite数据库为：GeoSite-default" >> $LOG_FILE
			yq eval ".geox-url.geosite = \"$geosite_default_url\"" -i "$yamlpath"
			;;
		head)
			echo_date "GeoSite数据库跟随基础配置，不操作" >> $LOG_FILE
			;;
		*)
			echo_date "未设置GeoSite类型， 默认设置为GeoSite-default" >> $LOG_FILE
			yq eval ".geox-url.geosite = \"$geosite_default_url\"" -i "$yamlpath"
			;;
	esac

	#设置必要字段
	yq eval ".allow-lan = true" -i "$yamlpath"
	#yq eval '.mode = "rule"' -i "$yamlpath"
	yq eval '.log-level = "error"' -i "$yamlpath"

	#启动时对控制面板IP重赋值
	ecport=$(yq eval '.external-controller | split(":") | .[1]' "$yamlpath" 2>/dev/null)
	if [ -z "$ecport" ] || [ "$ecport" == "null" ]; then
		ecport="9990"
	fi
	yq eval '.external-ui = "dashboard"' -i "$yamlpath"
	yq eval ".external-controller = \"$lan_ipaddr:$ecport\"" -i "$yamlpath"
	#修改管理面板密码
	mds=${merlinclash_set_dashboard_password}
	yq eval ".secret =  \"$mds\"" -i "$yamlpath"
	echo_date 修改管理面板密码为：$mds >> $LOG_FILE
	#设置mark值
	if [ "${merlinclash_ipt_proxyrouter_sw}" == "1" ]; then
		yq eval ".routing-mark = $mcrm" -i "$yamlpath"
		echo_date "设置路由流量标记值(Routing-Mark)为：$mcrm" >> $LOG_FILE
	fi

	# 检测是否在lan设置中是否自定义过dns,如果有给干掉
	if [ "${merlinclash_dns_cleardns_sw}" == "1" ]; then
		echo_date "清除路由自定义DNS" >> $LOG_FILE
		if [ -n "$(nvram get dhcp_dns1_x)" ]; then
			nvram unset dhcp_dns1_x
			nvram commit
		fi
		if [ -n "$(nvram get dhcp_dns2_x)" ]; then
			nvram unset dhcp_dns2_x
			nvram commit
		fi	
	fi
	# 开启ipv6赋值
	if [ "$ipv6switch" == "1" ]; then
		echo_date "修改yaml配置文件的IPv6相关设置" >> $LOG_FILE
		yq eval ".ipv6 = true" -i "$yamlpath"
		yq eval ".dns.ipv6 = true" -i "$yamlpath"
	fi
}

#端口取值
get_ports(){
	httpport=$(yq eval ".port" "$yamlpath" 2>/dev/null)
	socksport=$(yq eval ".socks-port" "$yamlpath" 2>/dev/null)
	mixport=$(yq eval ".mixed-port" "$yamlpath" 2>/dev/null)
	proxy_port=$(yq eval ".redir-port" "$yamlpath" 2>/dev/null)
	tproxy_port=$(yq eval ".tproxy-port" "$yamlpath" 2>/dev/null)
	dnslistenport=$(yq eval ".dns.listen" "$yamlpath" 2>/dev/null)
	ecport=$(yq eval '.external-controller | split(":") | .[1]' "$yamlpath" 2>/dev/null)
}

### 启动
set_sys() {
	# set_ulimit
	ulimit -n 16384
	echo 1 >/proc/sys/vm/overcommit_memory
	if [ -z "$(pidof jitterentropy-rngd)" -a -z "$(pidof haveged)" ];then
		echo_date "启动haveged，为系统提供更多的可用熵！" >> $LOG_FILE
		haveged -w 1024 >/dev/null 2>&1	
	fi	
}

#fixTimeZone() {
	# 修复日志显示时区问题
#	[ -f "/etc/TZ" ] && grep -q "GMT-8" /etc/TZ 2>/dev/null &&
#	[ ! -e "/etc/localtime" ] && [ -f "/jffs/softcenter/merlinclash/Shanghai" ] &&
#	ln -sf /jffs/softcenter/merlinclash/Shanghai /etc/localtime
#}

startClashNormalOrPerp(){
    local clashRunLog="/tmp/clash_run.log"
    local watchdog=${merlinclash_set_watchdog_sw}
    if [ "$watchdog" = "1" ];then
        echo_date "检测到开启进程守护，开启进程实时守护..." >> $LOG_FILE
		mkdir -p /jffs/softcenter/perp/clash
		cat >/tmp/clash_dog.sh <<-EOF
			#!/bin/sh
			source /jffs/softcenter/scripts/base.sh
			eval $(dbus export merlinclash_)
			alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

			while [ "$merlinclash_enable" == "1" ]; do
			    if [ ! -n "$(pidof clash)" ]; then
			        /jffs/softcenter/bin/clash -d /jffs/softcenter/merlinclash/ -f $yamlpath 1>$clashRunLog  2>&1 &
			    fi
			    sleep 60
			    continue
			done

		EOF
		chmod +x /tmp/clash_dog.sh
		/tmp/clash_dog.sh &
    else
        /jffs/softcenter/bin/clash -d /jffs/softcenter/merlinclash/ -f $yamlpath 1>$clashRunLog  2>&1 &
    fi
}

start_clash(){
	echo_date "使用【$yamlname】 配置文件" >> $LOG_FILE
	rm -rf "/tmp/upload/view.txt"
	cp -rf $yamlpath /tmp/upload/view.txt
	echo_date "启动Clash程序" >> $LOG_FILE

	# 启动之前检查下是否需要修复时区
	#fixTimeZone
	# 启动clash，看看是不是需要用Perp守护进程
	startClashNormalOrPerp


	if [ ! $retryTimes ] || [ $retryTimes -lt 20 ];then
		retryTimes=40
		dbus set merlinclash_set_logcheck_val=40
	fi

	echo_date "启动Clash程序完毕，Clash启动日志位置：/tmp/clash_run.log" >> $LOG_FILE
	echo_date "正在检查Clash进程启动是否报错，请稍候！" >> $LOG_FILE
	echo_date "尝试重试检查日志次数：$retryTimes 次"  >> $LOG_FILE
	
	until [ "$(pidof clash)" -a "$(netstat -anp | grep clash |head -n 5)" -a ! -n "$(grep "Parse config error" /tmp/clash_run.log | head -n 5)" ]; do
		if [ "$retryTimes" -lt 1 ]; then
    		echo_date "Clash 进程启动失败！请检查配置文件是否存在问题，即将退出" >> $LOG_FILE
    		echo_date "失败原因：" >> $LOG_FILE
    		error1=$(cat /tmp/clash_run.log | grep -oE "Parse config error.*")
    		error2=$(cat /tmp/clash_run.log | grep -oE "clashconfig.sh.*")
    		error3=$(cat /tmp/clash_run.log | grep -oE "illegal instruction.*")
    		error4=$(cat /tmp/clash_run.log | grep -n "level=error" | head -1 | grep -oE "msg=.*")
    		if [ -n "$error1" ]; then
        		echo_date $error1 >> $LOG_FILE		
    		elif [ -n "$error2" ]; then
        		echo_date $error2 >> $LOG_FILE
    		elif [ -n "$error3" ]; then
        		echo_date $error3 >> $LOG_FILE
    			echo_date "clash二进制故障，请重新上传" >> $LOG_FILE
    		elif [ -n "$error4" ]; then
        		echo_date $error4 >> $LOG_FILE
    		fi
    		dbus set merlinclash_binary_startime=""
    		close_in_five
			return
		fi
		retryTimes=$(($retryTimes - 1))
		usleep 300000
	done
	
	usleep 300000
	echo_date "Clash 进程启动成功！(PID: $(pidof clash))" >> $LOG_FILE
	a_tmp=$(echo_date2)
	dbus set merlinclash_binary_startime=$a_tmp
	clash_process_started="1"
	rm -rf /tmp/upload/*.yaml
}

start_remark(){
	if [ "${coremark}" == "0" ]; then          
		echo_date -------------------- 📌记录/还原代理组状态 ------------------- >> $LOG_FILE
		/bin/sh /jffs/softcenter/scripts/clash_node_mark.sh remark
    fi
}

### nat加载
load_tproxy() {
	MODULES="nf_tproxy_core xt_TPROXY"
	OS=$(uname -r)
	# load Kernel Modules
	echo_date 加载Tproxy模块，用于UDP转发... >> $LOG_FILE
	checkmoduleisloaded() {
		if lsmod | grep $MODULE &>/dev/null; then return 0; else return 1; fi
	}

	for MODULE in $MODULES; do
		if ! checkmoduleisloaded; then
			if [  "${LINUX_VER}" -eq "419" -o "${LINUX_VER}" -eq "54" ];then
				modprobe ${MODULE}.ko
			else
				insmod /lib/modules/${OS}/kernel/net/netfilter/${MODULE}.ko
			fi
		fi
	done

	modules_loaded=0

	for MODULE in $MODULES; do
		if checkmoduleisloaded; then
			modules_loaded=$((j++))
		fi
	done
}

load_nat() {
	nat_ready=$(iptables -t nat -L PREROUTING -v -n --line-numbers | grep -v PREROUTING | grep -v destination)
	i=120
	until [ -n "$nat_ready" ]; do
		i=$(($i - 1))
		if [ "$i" -lt 1 ]; then
			echo_date "【错误】加载nat规则失败! 注意：路由AP模式下不能使用透明代理" >> $LOG_FILE
			close_in_five
		fi
		sleep 1s
		nat_ready=$(iptables -t nat -L PREROUTING -v -n --line-numbers | grep -v PREROUTING | grep -v destination)
	done
	echo_date "加载nat规则!" >> $LOG_FILE
	sleep 1s
	apply_nat_rules
}

#设备绕行
get_method_name(){
	case "$1" in
	1)
		echo "IP + MAC匹配"
		;;
	2)
		echo "仅IP匹配"
		;;
	3)
		echo "仅MAC匹配"
		;;
	esac
}

get_mode_name() {
	case "$1" in
	0)
		echo "不通过代理"
		;;
	1)
		echo "通过clash"
		;;
	esac
}

factor() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo ""
	else
		echo "$2 $1"
	fi
}

get_jump_mode() {
	case "$1" in
	0)
		echo "j"
		;;
	*)
		echo "g"
		;;
	esac
}

get_action_chain() {
	case "$1" in
	0)
		echo "RETURN"
		;;
	1)
		if [ "$cirswitch" == "1" ]; then
			echo "merlinclash_CHN"
		else
			echo "merlinclash_NOR"
		fi
		;;
	esac
}

lan_bypass(){
	# deivce_nu 获取已存数据序号
	echo_date --------------------- 📌写入访问控制规则 --------------------- >> $LOG_FILE
	OS=$(uname -r)
	if lsmod | grep ip_set_hash_mac &>/dev/null; then
		echo_date "ip_set_hash_mac模块已加载" >> $LOG_FILE; 
	else
		#检查是否固件是否有ip_set_hash_mac模块
		if [ -f "/lib/modules/${OS}/kernel/net/netfilter/ipset/ip_set_hash_mac.ko" ]; then
			echo_date "加载MAC地址过滤模块" >> $LOG_FILE; 
			modprobe ip_set_hash_mac
		fi
	fi
	mnm=$(dbus get merlinclash_nokpacl_method)
	echo_date "已设置【$(get_method_name $mnm)】过滤" >> $LOG_FILE
	list_flag="0"
	if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
		list_flag="1" #REDIR-TCP / TPROXY-UDP
	elif [ "$tproxymode" == "tcp" ] || [ "$tproxymode" == "tcpudp" ]; then
		list_flag="2" #TPROXY-TCP / TCP&UDP
	fi
	nokpacl_nu=$(get_list merlinclash_nokpacl_ip 1 4)

	echo "create macblacklist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macblacklist_dns.ipset
	echo "create macwhitelist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macwhitelist_dns.ipset
	echo "create ipblacklist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipblacklist_dns.ipset
	echo "create ipwhitelist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipwhitelist_dns.ipset
	if [ "$mnm" != "3" ]; then
		echo "create lan_ip_blacklist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_ip_blacklist.ipset
		echo "create lan_ip_whitelist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_ip_whitelist.ipset
	fi
	if [ "$mnm" != "2" ]; then
		echo "create lan_mac_blacklist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_mac_blacklist.ipset
		echo "create lan_mac_whitelist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_mac_whitelist.ipset	
	fi
	if [ "$list_flag" == "1" ]; then
		if [ -n "$nokpacl_nu" ]; then
			for nokpacl in $nokpacl_nu; do
				echo_date "处理当前第$nokpacl条规则" >> $LOG_FILE
				ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
				if [ -z "$(echo "$ipaddr" | grep "/")" ]; then
    				ipaddr="${ipaddr}/32"
				fi
				macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
				ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
				proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
				proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
				[ "$mnm" == "1" ] && echo_date "设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				[ "$mnm" == "2" ] && macaddr="" && echo_date "设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				[ "$mnm" == "3" ] && ipaddr="" && echo_date "设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
					echo_date "设备$proxy_name MAC地址为空，跳过处理。" >> $LOG_FILE
					continue
				fi
				if [ "$mnm" == "2" ] && [ "$ipaddr" == "" ]; then
					echo_date "设备$proxy_name IP地址为空，跳过处理。" >> $LOG_FILE
					continue
				fi
				if [ "$mnm" == "1" ] && [ "$macaddr" == "" ] && [ "$ipaddr" == "" ]; then
					echo_date "设备$proxy_name MAC地址和IP地址都为空，跳过处理。" >> $LOG_FILE
					continue
				fi
				if [ "$proxy_mode" == "0" ]; then
					# echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add lan_mac_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_mac_blacklist.ipset
					[ -n "$macaddr" ] && echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					[ -n "$ipaddr" ] && echo "add lan_ip_blacklist ${ipaddr}" >> /jffs/softcenter/res/lan_ip_blacklist.ipset
					[ -n "$ipaddr" ] && echo "add ipblacklist_dns ${ipaddr}" >> /jffs/softcenter/res/ipblacklist_dns.ipset
				fi
				if [ "$proxy_mode" == "1" ] && [ "$ports" == "all" ]; then
					# echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add lan_mac_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_mac_whitelist.ipset
					[ -n "$macaddr" ] && echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					[ -n "$ipaddr" ] && echo "add lan_ip_whitelist ${ipaddr}" >> /jffs/softcenter/res/lan_ip_whitelist.ipset
					[ -n "$ipaddr" ] && echo "add ipwhitelist_dns ${ipaddr}" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
				fi
				if [ "$proxy_mode" == "1" ] && [ "$ports" != "all" ]; then
					# echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					[ -n "$ipaddr" ] && echo "add ipwhitelist_dns ${ipaddr}" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
				fi
				if [ "$ports" == "all" ]; then
					ports=""
				fi
				#访问自定端口走代理
				if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
					# echo_date "$proxy_name 访问指定端口【$ports】转发进Clash" >> $LOG_FILE
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
						iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN
						
					fi
				fi
			done
			if [ "$mnm" != "2" ]; then
				ipset -! flush lan_mac_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_mac_blacklist.ipset 2>/dev/null
				ipset -! flush macblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
				ipset -! flush lan_mac_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_mac_whitelist.ipset 2>/dev/null
				ipset -! flush macwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
			fi
			if [ "$mnm" != "3" ]; then
				ipset -! flush lan_ip_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_ip_blacklist.ipset 2>/dev/null
				ipset -! flush ipblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
				ipset -! flush lan_ip_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_ip_whitelist.ipset 2>/dev/null
				ipset -! flush ipwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
			fi
			#IPTABLES写法
			#1.黑名单内先过滤
			#iptables写法
			iptables -t nat -I merlinclash -m set --match-set lan_mac_blacklist src -p tcp -j RETURN >/dev/null 2>&1
			iptables -t nat -I merlinclash -m set --match-set lan_ip_blacklist src -p tcp -j RETURN >/dev/null 2>&1
			if [ "$tproxymode" == "udp" ]; then
				iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
			fi
			iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_blacklist src -p udp -j RETURN >/dev/null 2>&1
			iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_blacklist src -p udp -j RETURN >/dev/null 2>&1

			#2.白名单内再放行
			if [ "$cirswitch" == "1" ]; then
				echo_date "设置白名单进入merlinclash_CHN链" >> $LOG_FILE
				iptables -t nat -A merlinclash -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash_CHN
				iptables -t nat -A merlinclash -m set --match-set lan_ip_whitelist src -p tcp -j merlinclash_CHN

				if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp  -j merlinclash
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p udp  -j merlinclash
				fi
			else
				echo_date "设置白名单进入merlinclash_NOR链" >> $LOG_FILE	
				iptables -t nat -A merlinclash -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash_NOR	
				iptables -t nat -A merlinclash -m set --match-set lan_ip_whitelist src -p tcp -j merlinclash_NOR	
				if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp  -j merlinclash
							iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p udp  -j merlinclash
				fi
			fi
			#3.剩余主机处理
			if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
				merlinclash_nokpacl_default_port=""
				[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
				echo_date 加载ACl规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问全端口通过clash
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
					else
						iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
					fi
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
					if [ "$dnsplan" == "fi" ]; then
						if [ "$mnm" != "2" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
						fi
						if [ "$mnm" != "3" ]; then
							iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
						fi
					fi
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
					fi
				else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
					echo_date "剩余主机全端口不通过clash，只给通过Clash的设备转发dns端口" >> $LOG_FILE
					#iptables写法
					if [ "$dnshijacksel" == "1" ]; then
						if [ "$mnm" != "2" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						if [ "$mnm" != "3" ]; then
							iptables -t nat -I PREROUTING -m set --match-set ipwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -j RETURN #剩余主机udp流量都不转发
					fi
				fi
			else 
				[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
				echo_date 加载ACl规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问指定端口通过clash
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then	
						iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN			
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
					else
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
					fi						
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
					if [ "$dnsplan" == "fi" ]; then
						if [ "$mnm" != "2" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
						fi
						if [ "$mnm" != "3" ]; then
							iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
						fi
					fi
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
					
					fi
				fi
			fi
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
			fi
		else
			echo_date "未设置设备绕行，使用默认：全设备转发进Clash" >> $LOG_FILE
			merlinclash_nokpacl_default_mode="1"
			dbus set merlinclash_nokpacl_default_mode="1"
			if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
				merlinclash_nokpacl_default_port=""
				echo_date 加载ACl规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				#iptables写法
				#大陆白判断
				if [ "$cirswitch" == "1" ]; then				
					iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
					if [ "$dnshijacksel" == "1" ]; then
							iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1			
					fi
				else
					iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
				fi
				if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
						iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
			else
				echo_date 加载ACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
			
				#大陆白判断
				if [ "$cirswitch" == "1" ]; then
					iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
											
					fi
					if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					fi
				else
					iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
					fi
					if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					fi
				fi
			fi
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
			fi
		fi
		dbus remove merlinclash_nokpacl_ip
		dbus remove merlinclash_nokpacl_name
		dbus remove merlinclash_nokpacl_mode
		dbus remove merlinclash_nokpacl_port
	fi
	if [ "$list_flag" == "2" ]; then
		if [ -n "$nokpacl_nu" ]; then
			for nokpacl in $nokpacl_nu; do
				echo_date "处理第$nokpacl条规则" >> $LOG_FILE
				ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
				if [ -z "$(echo "$ipaddr" | grep "/")" ]; then
    				ipaddr="${ipaddr}/32"
				fi
				macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
				ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
				proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
				proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
				[ "$mnm" == "1" ] && echo_date "设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				[ "$mnm" == "2" ] && macaddr="" && echo_date "设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				[ "$mnm" == "3" ] && ipaddr="" && echo_date "设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
				if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
					echo_date "设备$proxy_name MAC地址为空，跳过处理。" >> $LOG_FILE
					continue
				fi
				if [ "$mnm" == "2" ] && [ "$ipaddr" == "" ]; then
					echo_date "设备$proxy_name IP地址为空，跳过处理。" >> $LOG_FILE
					continue
				fi
				if [ "$mnm" == "1" ] && [ "$macaddr" == "" ] && [ "$ipaddr" == "" ]; then
					echo_date "设备$proxy_name MAC地址和IP地址都为空，跳过处理。" >> $LOG_FILE
					continue
				fi				
				if [ "$proxy_mode" == "0" ] && [ "$ports" == "all" ]; then
					# echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add lan_mac_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_mac_blacklist.ipset
					[ -n "$macaddr" ] && echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					[ -n "$ipaddr" ] && echo "add lan_ip_blacklist ${ipaddr}" >> /jffs/softcenter/res/lan_ip_blacklist.ipset
					[ -n "$ipaddr" ] && echo "add ipblacklist_dns ${ipaddr}" >> /jffs/softcenter/res/ipblacklist_dns.ipset
				fi
				if [ "$proxy_mode" == "1" ] && [ "$ports" == "all" ]; then
					# echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add lan_mac_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_mac_whitelist.ipset
					[ -n "$macaddr" ] && echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					[ -n "$ipaddr" ] && echo "add lan_ip_whitelist ${ipaddr}" >> /jffs/softcenter/res/lan_ip_whitelist.ipset	
					[ -n "$ipaddr" ] && echo "add ipwhitelist_dns ${ipaddr}" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
				fi
				if [ "$proxy_mode" == "1" ] && [ "$ports" != "all" ]; then
					# echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
					[ -n "$macaddr" ] && echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					[ -n "$ipaddr" ] && echo "add ipwhitelist_dns ${ipaddr}" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
				fi
				if [ "$ports" == "all" ]; then
					ports=""
				fi
				# 1 acl in SHADOWSOCKS for nat
				#访问自定端口走代理
				# echo_date "iptables优先处理访问自定端口走代理设备：$proxy_name" >> $LOG_FILE
				if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
					echo_date "$proxy_name 访问指定端口【$ports】走代理" >> $LOG_FILE
					iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
					iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp -j RETURN
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
						ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp -j RETURN
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						echo_date "同时开启Tproxy-TCP&UDP转发" >> $LOG_FILE
						iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
						iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN
						
						if [ "$ipv6_flag" == "1" ]; then
							echo_date "同时开启Tproxy-TCP&UDP转发 | 开启IPV6" >> $LOG_FILE
							ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
							ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN								
						fi
					fi
				fi
			done
			if [ "$mnm" != "2" ]; then
				ipset -! flush lan_mac_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_mac_blacklist.ipset 2>/dev/null
				ipset -! flush macblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
				ipset -! flush lan_mac_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_mac_whitelist.ipset 2>/dev/null
				ipset -! flush macwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
			fi
			if [ "$mnm" != "3" ]; then
				ipset -! flush lan_ip_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_ip_blacklist.ipset 2>/dev/null
				ipset -! flush ipblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
				ipset -! flush lan_ip_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_ip_whitelist.ipset 2>/dev/null
				ipset -! flush ipwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
			fi

			#IPTABLES写法
			#1.黑名单内先过滤
			#iptables写法
			echo_date "iptables处理中" >> $LOG_FILE		
			echo_date "黑名单内先过滤" >> $LOG_FILE	
			iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_blacklist src -p tcp -j RETURN >/dev/null 2>&1
			iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_blacklist src -p tcp -j RETURN >/dev/null 2>&1
							
			if [ "$tproxymode" == "udp" ] || [ "$tproxymode" == "tcpudp" ]; then
					iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
					ip6tables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
			fi
			if [ "$ipv6_flag" == "1" ]; then
				ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_blacklist src -p tcp -j RETURN >/dev/null 2>&1
			fi
			#20201122
			if [ "$tproxymode" == "tcpudp" ]; then
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_blacklist src -p udp -j RETURN >/dev/null 2>&1
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_blacklist src -p udp -j RETURN >/dev/null 2>&1
				if [ "$ipv6_flag" == "1" ]; then
					ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_blacklist src -p udp -j RETURN >/dev/null 2>&1
				fi
			fi
			#2.白名单内再放行
			echo_date "白名单内再放行" >> $LOG_FILE	
			if [ "$cirswitch" == "1" ]; then	
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p tcp -j merlinclash
			
				if [ "$ipv6_flag" == "1" ]; then
					ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash
				fi
				if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp -j merlinclash
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p udp -j merlinclash
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp -j merlinclash				
					fi
				fi
			else
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p tcp -j merlinclash
				
				if [ "$ipv6_flag" == "1" ]; then
					ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p tcp -j merlinclash				
				fi
				if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp -j merlinclash
						iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_ip_whitelist src -p udp -j merlinclash
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_mac_whitelist src -p udp -j merlinclash
					fi
				fi
			fi
			#3.剩余主机处理
			echo_date "剩余主机处理" >> $LOG_FILE	
			if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
				merlinclash_nokpacl_default_port=""
				[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
				echo_date 加载ACl规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问全端口通过clash
					#iptables写法
					#大陆白判断
						if [ "$dnshijacksel" == "1" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							if [ "$dnsplan" == "fi" ]; then
								iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
							fi
						
						fi
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
								if [ "$ipv6_flag" == "1" ]; then
									ip6tables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
								fi
						fi 
				else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
					echo_date "剩余主机全端口不通过clash，只给通过clash的设备转发dns端口" >> $LOG_FILE
					#iptables写法
					if [ "$dnshijacksel" == "1" ]; then
						if [ "$mnm" != "2" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						if [ "$mnm" != "3" ]; then
							iptables -t nat -I PREROUTING -m set --match-set ipwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
				fi
			else
				[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
				echo_date 加载ACL规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问指定端口通过clash
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
						fi
						if [ "$dnshijacksel" == "1" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							if [ "$dnsplan" == "fi" ]; then
								iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
							fi
					
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							fi
						fi
					else
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
						fi
						if [ "$dnshijacksel" == "1" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							fi
						fi
					fi
				fi
			fi
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
			fi
		else
			echo_date "未设置设备绕行，采用默认规则：clash全设备通行" >> $LOG_FILE
			merlinclash_nokpacl_default_mode="1"
			dbus set merlinclash_nokpacl_default_mode="1"
			if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
				merlinclash_nokpacl_default_port=""
				echo_date 加载ACl规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				#iptables写法
					iptables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
						iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
					fi
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
							if [ "$tproxymode" == "tcpudp" ]; then
								ip6tables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
								ip6tables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
							fi
					fi
			else
				echo_date 加载ACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
				#大陆白判断
				if [ "$cirswitch" == "1" ]; then
					iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					fi
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						fi
					fi
				else
					iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
					fi
					if [ "$dnshijacksel" == "1" ]; then
						iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						fi
					fi
				fi
				
			fi
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
			fi
		fi
		dbus remove merlinclash_nokpacl_ip
		dbus remove merlinclash_nokpacl_name
		dbus remove merlinclash_nokpacl_mode
		dbus remove merlinclash_nokpacl_port
	fi
	
}

apply_nat_rules() {
	dem2=$(yq eval ".enhanced-mode" "$yamlpath" 2>/dev/null)
	echo_date "开始写入iptable规则" >> $LOG_FILE

	if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
		echo_date "当前为【Redir TCP】透明代理模式" >> $LOG_FILE
		# ports redirect for clash except port 22 for ssh connection
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "IPV6-DNS兼容处理" >> $LOG_FILE
		fi
		iptables -t nat -N merlinclash
		echo_date "创建【nat】表【merlinclash】链" >> $LOG_FILE	
		iptables -t nat -N merlinclash_EXT
		echo_date "创建【nat】表【merlinclash_EXT】链" >> $LOG_FILE
		#ip集强制绕过
		iptables -t nat -A merlinclash -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t nat -A merlinclash -p tcp -m set --match-set direct_list dst -j RETURN
		iptables -t nat -A merlinclash_EXT -p tcp -m set --match-set direct_list dst -j RETURN
		# 创建redirhost常规模式nat rule
		
		iptables -t nat -N merlinclash_NOR
		echo_date "创建【nat】表【merlinclash_NOR】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t nat -A merlinclash_NOR -p tcp -m set --match-set ipset_proxy dst -j REDIRECT --to-ports $proxy_port
		iptables -t nat -A merlinclash_NOR -p tcp -j REDIRECT --to-ports $proxy_port
		# 创建redirhost大陆白名单模式nat rule
		
		iptables -t nat -N merlinclash_CHN
		echo_date "创建【nat】表【merlinclash_CHN】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t nat -A merlinclash_CHN -p tcp -m set --match-set ipset_proxy dst -j REDIRECT --to-ports $proxy_port
		iptables -t nat -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route dst -j REDIRECT --to-ports $proxy_port
		
		if [ "$tproxymode" == "udp" ]; then
			echo_date "开启【TProxy UDP】转发，将创建相关iptable规则" >> $LOG_FILE
			# udp
			load_tproxy
			# 设置策略路由
			ip -4 route add local default dev lo table 233
			ip -4 rule add fwmark 0x2333         table 233
			#同步路由家长电脑控制
			iptables -t filter -S PControls | while read -r line; do iptables -t mangle $line; done
			iptables -t filter -S FORWARD|grep PControls|sed 's/-A FORWARD/-I PREROUTING/g'|while read -r line; do iptables -t mangle $line; done

			#添加merlinclash_PREROUTING链
			iptables -t mangle -N merlinclash_PREROUTING
			iptables -t mangle -F merlinclash_PREROUTING
            
			#仅对首包进行判断是否走clash，对转发的链接打上mark
			iptables -t mangle -N merlinclash
			iptables -t mangle -F merlinclash
			iptables -t mangle -A merlinclash -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
            iptables -t mangle -A merlinclash -j CONNMARK --save-mark
            iptables -t mangle -A merlinclash -p udp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
            
			#非首包有mark直接转发，无mark直连不再进行黑白名单及acl判断
			iptables -t mangle -N merlinclash_divert
			iptables -t mangle -F merlinclash_divert
			iptables -t mangle -A merlinclash_divert -j CONNMARK --restore-mark
            iptables -t mangle -A merlinclash_divert -p udp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
            iptables -t mangle -A merlinclash_divert -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
            iptables -t mangle -A merlinclash_divert -m conntrack --ctstate INVALID -j DROP
				
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
				iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
				iptables -t mangle -A merlinclash_PREROUTING -i br5+ -j RETURN
			fi
			#ip集强制代理
			iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxy dst -j merlinclash
			#ip集强制绕过
			iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxyarround dst -j RETURN
			#局域网&排除地址绕行
			iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set direct_list dst -j RETURN
			if [ "$cirswitch" == "1" ]; then	
				iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set china_ip_route dst -j RETURN
			fi
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_PREROUTING			
		else
			echo_date "【检测到UDP转发关闭，进行下一步】" >> $LOG_FILE
		fi
		echo_date "清除wanduck监听规则" >> $LOG_FILE
		wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
		for wanduck1_index in $wanduck1_indexs; do
			iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
		done
		wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
		for wanduck2_index in $wanduck2_indexs; do
			iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
		done

		lan_bypass

		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$ip_prefix_hex" -j merlinclash_EXT
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$opvpn_prefix_hex" -j merlinclash_EXT #OPENVPN回城兼容
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$pptpvpn_prefix_hex" -j merlinclash_EXT #PPTPVPN回城兼容
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$ipsec_prefix_hex" -j merlinclash_EXT #PPTPVPN回城兼容
		iptables -t nat -A merlinclash_EXT -p tcp -j merlinclash
		
				
		if [ "$dnsgoclash" == "1" ]; then
			#转发路由器自身tcp流量，clash出站流量打了mark不转发，避免回环
			iptables -t nat -N merlinclash_OUTPUT
            iptables -t nat -A merlinclash_OUTPUT -p tcp -m set --match-set direct_list dst -j RETURN
			iptables -t nat -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			if [ "$cirswitch" == "1" ]; then	
				iptables -t nat -A merlinclash_OUTPUT -p tcp -m set ! --match-set china_ip_route dst -j merlinclash
			else
				iptables -t nat -A merlinclash_OUTPUT -p tcp -j merlinclash
			fi
			iptables -t nat -A merlinclash_OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT		
				
		fi
		

		iptables -t nat -A PREROUTING -p tcp -j merlinclash
		
	
	elif [ "$tproxymode" == "tcpudp" ]; then 
		echo_date "当前为【TProxy TCP&UDP】透明代理模式" >> $LOG_FILE
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "开启IPv6模式" >> $LOG_FILE
		fi

		# ipv4设置策略路由
		load_tproxy
		ip -4 route add local default dev lo table 233
		ip -4 rule add fwmark 0x2333         table 233

		#同步路由家长电脑控制
		iptables -t filter -S PControls | while read -r line; do iptables -t mangle $line; done
		iptables -t filter -S FORWARD|grep PControls|sed 's/-A FORWARD/-I PREROUTING/g'|while read -r line; do iptables -t mangle $line; done

		#添加merlinclash_PREROUTING链
		iptables -t mangle -N merlinclash_PREROUTING
		iptables -t mangle -F merlinclash_PREROUTING

		#仅对首包进行判断是否走clash，对转发的链接打上mark
		iptables -t mangle -N merlinclash
		iptables -t mangle -F merlinclash
		iptables -t mangle -A merlinclash -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
        iptables -t mangle -A merlinclash -j CONNMARK --save-mark
		iptables -t mangle -A merlinclash -p tcp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
        iptables -t mangle -A merlinclash -p udp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
            
		#非首包有mark直接转发，无mark直连不再进行黑白名单及acl判断
		iptables -t mangle -N merlinclash_divert
		iptables -t mangle -F merlinclash_divert
		iptables -t mangle -A merlinclash_divert -j CONNMARK --restore-mark
		iptables -t mangle -A merlinclash_divert -p tcp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
        iptables -t mangle -A merlinclash_divert -p udp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
        iptables -t mangle -A merlinclash_divert -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -t mangle -A merlinclash_divert -m conntrack --ctstate INVALID -j DROP

		#echo_date "创建【mangle】表【merlinclash】链" >> $LOG_FILE
		if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
			iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br5+ -j RETURN
		fi
		#ip集强制代理
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxy dst --syn -j merlinclash
		iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxy dst -m conntrack --ctstate NEW -j merlinclash
		#iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set router dst -j merlinclash
		#ip集强制绕过
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set direct_list dst -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set direct_list dst -j RETURN
		#
		if [ "$cirswitch" == "1" ]; then
			iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set china_ip_route dst -j RETURN	
			iptables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set china_ip_route dst -j RETURN											
		fi
											
		if [ "$ipv6_flag" == "0" ]; then
			echo_date "清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			lan_bypass
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_PREROUTING
			
		fi		
	    # ipv6设置策略路由
		if [ "$ipv6_flag" == "1" ]; then
			echo_date "清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done

			ip -6 route add local default dev lo table 233
			ip -6 rule add fwmark 0x2333         table 233

			#同步路由家长电脑控制
			ip6tables -t filter -S PControls | while read -r line; do ip6tables -t mangle $line; done
			ip6tables -t filter -S FORWARD|grep PControls|sed 's/-A FORWARD/-I PREROUTING/g'|while read -r line; do ip6tables -t mangle $line; done

			#添加merlinclash_PREROUTING链
			ip6tables -t mangle -N merlinclash_PREROUTING
			ip6tables -t mangle -F merlinclash_PREROUTING

			#仅对首包进行判断是否走clash，对转发的链接打上mark
			ip6tables -t mangle -N merlinclash
			ip6tables -t mangle -F merlinclash
			ip6tables -t mangle -A merlinclash -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
            ip6tables -t mangle -A merlinclash -j CONNMARK --save-mark
			ip6tables -t mangle -A merlinclash -p tcp -m mark --mark 0x2333 -j TPROXY --on-ip ::1 --on-port $tproxy_port
            ip6tables -t mangle -A merlinclash -p udp -m mark --mark 0x2333 -j TPROXY --on-ip ::1 --on-port $tproxy_port
            
			#非首包有mark直接转发，无mark直连不再进行黑白名单及acl判断
			ip6tables -t mangle -N merlinclash_divert
			ip6tables -t mangle -F merlinclash_divert
			ip6tables -t mangle -A merlinclash_divert -j CONNMARK --restore-mark
			ip6tables -t mangle -A merlinclash_divert -p tcp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
            ip6tables -t mangle -A merlinclash_divert -p udp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
            ip6tables -t mangle -A merlinclash_divert -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
            ip6tables -t mangle -A merlinclash_divert -m conntrack --ctstate INVALID -j DROP

			#echo_date "创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				ip6tables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
				ip6tables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
				ip6tables -t mangle -A merlinclash_PREROUTING -i br5+ -j RETURN
			fi
			#强制转发clash
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxy6 dst -j merlinclash
			ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxy6 dst -j merlinclash
			
			#强制绕行clash
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxyarround6 dst -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set ipset_proxyarround6 dst -j RETURN
			#局域网&排除地址绕行
			echo_date "局域网&排除地址绕行" >> $LOG_FILE
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set direct_list6 dst -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set direct_list6 dst -j RETURN
			#
			if [ "$cirswitch" == "1" ]; then	
				ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m set --match-set china_ip_route6 dst -j RETURN											
				ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set china_ip_route6 dst -j RETURN
			fi
			
			lan_bypass
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_divert
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			ip6tables -t mangle -A PREROUTING -p udp -j merlinclash_divert			
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			iptables -t mangle -A PREROUTING -p udp -j merlinclash_PREROUTING
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			ip6tables -t mangle -A PREROUTING -p udp -j merlinclash_PREROUTING
			
		fi
		
		if [ "$dnsgoclash" == "1" ]; then
			ip -4 rule add fwmark 0x1111         table 233
			iptables -t nat -N merlinclash_OUTPUT
			iptables -t nat -A merlinclash_OUTPUT -p tcp -m set --match-set direct_list dst -j RETURN
            iptables -t nat -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			iptables -t nat -A merlinclash_OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT
			iptables -t mangle -N merlinclash_OUTPUT
			iptables -t mangle -A merlinclash_OUTPUT ! -s $wan_ipaddr -j RETURN
			iptables -t mangle -A merlinclash_OUTPUT -p udp --dport 53 -j RETURN
			iptables -t mangle -A merlinclash_OUTPUT -m set --match-set direct_list dst -j RETURN
            iptables -t mangle -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			if [ "$cirswitch" == "1" ]; then	
				iptables -t mangle -A merlinclash_OUTPUT -m set --match-set china_ip_route dst -j RETURN
			fi
			iptables -t mangle -A merlinclash_OUTPUT -j CONNMARK --restore-mark
			iptables -t mangle -A merlinclash_OUTPUT -p tcp -s -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
			iptables -t mangle -A merlinclash_OUTPUT -p udp -s -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
            iptables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
            iptables -t mangle -A merlinclash_OUTPUT  -m mark ! --mark 0x1111 -m conntrack --ctstate INVALID -j DROP
			iptables -t mangle -A merlinclash_OUTPUT -p tcp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
			iptables -t mangle -A merlinclash_OUTPUT -p udp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
			iptables -t mangle -A merlinclash_OUTPUT -j CONNMARK --save-mark

			iptables -t mangle -I OUTPUT -j merlinclash_OUTPUT

			iptables -t mangle -I merlinclash_divert -p udp -s $wan_ipaddr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
			iptables -t mangle -I merlinclash_divert -p tcp -s $wan_ipaddr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
			iptables -t mangle -D merlinclash_divert -j CONNMARK --restore-mark
			iptables -t mangle -I merlinclash_divert -j CONNMARK --restore-mark
			if [ "$ipv6_flag" == "1" ]; then
				ip -6 rule add fwmark 0x1111         table 233
				wan_ip6addr=$(ip -6 addr show dev ppp0 | sed -n '/inet/{s!.*inet6* !!;s!/.*!!p}' | sed 's/peer.*//' | grep -v '^fe80')
				ip6tables -t mangle -N merlinclash_OUTPUT
				ip6tables -t mangle -A merlinclash_OUTPUT ! -s $wan_ip6addr -j RETURN
				ip6tables -t mangle -A merlinclash_OUTPUT -p udp --dport 53 -j RETURN
				ip6tables -t mangle -A merlinclash_OUTPUT -m set --match-set direct_list6 dst -j RETURN
                ip6tables -t mangle -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
				if [ "$cirswitch" == "1" ]; then
				    ip6tables -t mangle -A merlinclash_OUTPUT -m set --match-set china_ip_route6 dst -j RETURN
			    fi
				ip6tables -t mangle -A merlinclash_OUTPUT -j CONNMARK --restore-mark
				ip6tables -t mangle -A merlinclash_OUTPUT -p tcp -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -p udp -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
				ip6tables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate INVALID -j DROP
				ip6tables -t mangle -A merlinclash_OUTPUT -p tcp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -p udp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -j CONNMARK --save-mark

				ip6tables -t mangle -I OUTPUT -j merlinclash_OUTPUT
				#取到wan口ipv6地址
				ip6tables -t mangle -I merlinclash_divert -p udp -s $wan_ip6addr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
				ip6tables -t mangle -I merlinclash_divert -p tcp -s $wan_ip6addr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
				ip6tables -t mangle -D merlinclash_divert -j CONNMARK --restore-mark
				ip6tables -t mangle -I merlinclash_divert -j CONNMARK --restore-mark
			fi
		fi
	elif [ "$tproxymode" == "tcp" ]; then
		echo_date "当前为【TProxy TCP】透明代理模式" >> $LOG_FILE
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "开启IPv6模式" >> $LOG_FILE
		fi

		# 设置策略路由
		load_tproxy
		ip -4 route add local default dev lo table 233
		ip -4 rule add fwmark 0x2333         table 233

		#同步路由家长电脑控制
		iptables -t filter -S PControls | while read -r line; do iptables -t mangle $line; done
		iptables -t filter -S FORWARD|grep PControls|sed 's/-A FORWARD/-I PREROUTING/g'|while read -r line; do iptables -t mangle $line; done

		#添加merlinclash_PREROUTING链
		iptables -t mangle -N merlinclash_PREROUTING
		iptables -t mangle -F merlinclash_PREROUTING

		#仅对首包进行判断是否走clash，对转发的链接打上mark
		iptables -t mangle -N merlinclash
		iptables -t mangle -F merlinclash
		iptables -t mangle -A merlinclash -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
        iptables -t mangle -A merlinclash -j CONNMARK --save-mark
        iptables -t mangle -A merlinclash -p tcp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
            
		#非首包有mark直接转发，无mark直连不再进行黑白名单及acl判断
		iptables -t mangle -N merlinclash_divert
		iptables -t mangle -F merlinclash_divert
		iptables -t mangle -A merlinclash_divert -j CONNMARK --restore-mark
        iptables -t mangle -A merlinclash_divert -p tcp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
        iptables -t mangle -A merlinclash_divert -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -t mangle -A merlinclash_divert -m conntrack --ctstate INVALID -j DROP

		#echo_date "创建【mangle】表【merlinclash】链" >> $LOG_FILE
		if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
			iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br5+ -j RETURN
		fi
		#iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set router dst -j merlinclash
		#ip集强制代理
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxy dst --syn -j merlinclash
		#ip集强制绕过
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set direct_list dst -j RETURN
		#
		if [ "$cirswitch" == "1" ]; then	
			iptables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set china_ip_route dst -j RETURN
		fi

		if [ "$ipv6_flag" == "0" ]; then
			echo_date "清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			lan_bypass
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			
		fi
		# ipv6设置策略路由
		if [ "$ipv6_flag" == "1" ]; then
			echo_date "清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done

			ip -6 route add local default dev lo table 233
			ip -6 rule add fwmark 0x2333         table 233

			#同步路由家长电脑控制
			ip6tables -t filter -S PControls | while read -r line; do ip6tables -t mangle $line; done
			ip6tables -t filter -S FORWARD|grep PControls|sed 's/-A FORWARD/-I PREROUTING/g'|while read -r line; do ip6tables -t mangle $line; done

			#添加merlinclash_PREROUTING链
			ip6tables -t mangle -N merlinclash_PREROUTING
			ip6tables -t mangle -F merlinclash_PREROUTING

			#仅对首包进行判断是否走clash，对转发的链接打上mark
			ip6tables -t mangle -N merlinclash
			ip6tables -t mangle -F merlinclash
			ip6tables -t mangle -A merlinclash -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
            ip6tables -t mangle -A merlinclash -j CONNMARK --save-mark
			ip6tables -t mangle -A merlinclash -p tcp -m mark --mark 0x2333 -j TPROXY --on-ip ::1 --on-port $tproxy_port
                       
			#非首包有mark直接转发，无mark直连不再进行黑白名单及acl判断
			ip6tables -t mangle -N merlinclash_divert
			ip6tables -t mangle -F merlinclash_divert
			ip6tables -t mangle -A merlinclash_divert -j CONNMARK --restore-mark
			ip6tables -t mangle -A merlinclash_divert -p tcp -m mark --mark 0x2333 -m conntrack --ctstate RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
            ip6tables -t mangle -A merlinclash_divert -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
            ip6tables -t mangle -A merlinclash_divert -m conntrack --ctstate INVALID -j DROP

			#echo_date "创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			if [ "${merlinclash_ipt_proxyiot_sw}" != "1" ]; then
				ip6tables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
				ip6tables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
				ip6tables -t mangle -A merlinclash_PREROUTING -i br5+ -j RETURN
			fi
			#强制转发clash
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxy6 dst -j merlinclash
			#强制绕行clash
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set ipset_proxyarround6 dst -j RETURN
			#局域网&排除地址绕行
			ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set direct_list6 dst -j RETURN
			#
			if [ "$cirswitch" == "1" ]; then	
				ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m set --match-set china_ip_route6 dst -j RETURN
			fi

			lan_bypass
			
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
		
		fi

		
		if [ "$dnsgoclash" == "1" ]; then
			ip -4 rule add fwmark 0x1111         table 233
			iptables -t nat -N merlinclash_OUTPUT
			iptables -t nat -A merlinclash_OUTPUT -p tcp -m set --match-set direct_list dst -j RETURN
            iptables -t nat -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			iptables -t nat -A merlinclash_OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT
			iptables -t mangle -N merlinclash_OUTPUT
			iptables -t mangle -A merlinclash_OUTPUT ! -s $wan_ipaddr -j RETURN
			iptables -t mangle -A merlinclash_OUTPUT -p udp --dport 53 -j RETURN
			iptables -t mangle -A merlinclash_OUTPUT -m set --match-set direct_list dst -j RETURN
            iptables -t mangle -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			if [ "$cirswitch" == "1" ]; then	
				iptables -t mangle -A merlinclash_OUTPUT -m set --match-set china_ip_route dst -j RETURN
			fi
			iptables -t mangle -A merlinclash_OUTPUT -j CONNMARK --restore-mark
			iptables -t mangle -A merlinclash_OUTPUT -p tcp -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
            iptables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
            iptables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate INVALID -j DROP
			iptables -t mangle -A merlinclash_OUTPUT -p tcp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
			iptables -t mangle -A merlinclash_OUTPUT -j CONNMARK --save-mark

			iptables -t mangle -I OUTPUT -j merlinclash_OUTPUT

			iptables -t mangle -I merlinclash_divert -p tcp -s $wan_ipaddr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
			iptables -t mangle -D merlinclash_divert -j CONNMARK --restore-mark
			iptables -t mangle -I merlinclash_divert -j CONNMARK --restore-mark
			if [ "$ipv6_flag" == "1" ]; then
				ip -6 rule add fwmark 0x1111         table 233
				wan_ip6addr=$(ip -6 addr show dev ppp0 | sed -n '/inet/{s!.*inet6* !!;s!/.*!!p}' | sed 's/peer.*//' | grep -v '^fe80')
				ip6tables -t mangle -N merlinclash_OUTPUT
				ip6tables -t mangle -A merlinclash_OUTPUT ! -s $wan_ip6addr -j RETURN
				ip6tables -t mangle -A merlinclash_OUTPUT -p udp --dport 53 -j RETURN
				ip6tables -t mangle -A merlinclash_OUTPUT -m set --match-set direct_list6 dst -j RETURN
                ip6tables -t mangle -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
				if [ "$cirswitch" == "1" ]; then
				    ip6tables -t mangle -A merlinclash_OUTPUT -m set --match-set china_ip_route6 dst -j RETURN
			    fi
				ip6tables -t mangle -A merlinclash_OUTPUT -j CONNMARK --restore-mark
				ip6tables -t mangle -A merlinclash_OUTPUT -p tcp -m mark --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
				ip6tables -t mangle -A merlinclash_OUTPUT -m mark ! --mark 0x1111 -m conntrack --ctstate INVALID -j DROP
				ip6tables -t mangle -A merlinclash_OUTPUT -p tcp -m conntrack --ctstate NEW -j MARK --set-mark 0x1111
				ip6tables -t mangle -A merlinclash_OUTPUT -j CONNMARK --save-mark

				ip6tables -t mangle -I OUTPUT -j merlinclash_OUTPUT
				#取到wan口ipv6地址
				ip6tables -t mangle -I merlinclash_divert -p tcp -s $wan_ip6addr -m mark --mark 0x1111 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j TPROXY --on-ip ::1 --on-port $tproxy_port
				ip6tables -t mangle -D merlinclash_divert -j CONNMARK --restore-mark
				ip6tables -t mangle -I merlinclash_divert -j CONNMARK --restore-mark
			fi
		fi
	fi

	# QOS开启的情况下
	QOSO=$(iptables -t mangle -S | grep -o QOSO | wc -l)
	RRULE=$(iptables -t mangle -S | grep "A QOSO" | head -n1 | grep RETURN)
	if [ "$QOSO" -gt "1" ] && [ -z "$RRULE" ]; then
		iptables -t mangle -I QOSO0 -m mark --mark "$ip_prefix_hex" -j RETURN
	fi
	#路由IPV6开启，但是不开启tproxy代理，仅开启ipv6劫持解析，需要内核4.1以上
	if [ "${LINUX_VER}" -ge "41" ] && [ "$ipv6switch" == "0" ] && [ $(ipv6_mode) == "true" ]; then
		load_tproxy
		echo_date "检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $LOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
	fi
	if [ "${LINUX_VER}" -lt "41" ] && [ $(ipv6_mode) == "true" ]; then
		load_tproxy
		echo_date "检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $LOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
	fi
	if [ "$dnsplan" == "fi" ]; then
		ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m set --match-set lan_mac_blacklist src -j DROP #阻断黑名单设备ipv6dns查询
	fi
	echo_date "iptable规则创建完成" >> $LOG_FILE
}

write_update_yaml_cron(){
	
    yaml_dlinks_file=/jffs/softcenter/merlinclash/yaml_bak/${yamlname}.dlinks
	
	if [ -n "$yamlname" ] && echo "$yamlname" | grep -q '^AP_' && [ -f "${yaml_dlinks_file}" ];then
		sed -i '/autoupdate/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1

		if [ "$mcenable" == "1" ] && [ "${clash_process_started}" = "1" ]; then
			update_time=$(awk -F',' '{print $1; exit}' "${yaml_dlinks_file}")
        	case "${update_time}" in
				86400)
					echo_date "设置每天凌晨5点，更新订阅配置" >> $LOG_FILE
					cru a autoupdate "0 5 * * * /bin/sh /jffs/softcenter/scripts/clash_subscribe.sh cron cron"
					cru a autologdel "0 * * * * /bin/sh /jffs/softcenter/scripts/clash_logautodel.sh"
				;;
				259200)
					echo_date "设置每周一周四凌晨5点，更新订阅配置" >> $LOG_FILE
					cru a autoupdate "0 5 * * 1,4 /bin/sh /jffs/softcenter/scripts/clash_subscribe.sh cron cron"
					cru a autologdel "0 * * * * /bin/sh /jffs/softcenter/scripts/clash_logautodel.sh"
				;;
				604800)
					echo_date "设置每周一凌晨5点，更新订阅配置" >> $LOG_FILE
					cru a autoupdate "0 5 * * 1 /bin/sh /jffs/softcenter/scripts/clash_subscribe.sh cron cron"
					cru a autologdel "0 * * * * /bin/sh /jffs/softcenter/scripts/clash_logautodel.sh"
				;;
				*)
					echo_date "未开启定时订阅" >> $LOG_FILE
			;;
			esac
		else
			echo_date "未检查到Clash进程，不开启定时订阅更新服务" >> $LOG_FILE
		fi
	fi																
}


write_setmark_cron_job(){
	if [ "${coremark}" == "1" ]; then
		echo_date "使用内核内置代理组状态保存服务" >> $LOG_FILE
		echo_date "Linux内核版本大于4.19或者启用了jffs2usb，使用内核内置代理组状态保存服务" > /tmp/upload/merlinclash_node_mark.log
		echo_date "------ 未使用定时脚本，本处无记录日志 -------" >> /tmp/upload/merlinclash_node_mark.log
	else
		sed -i '/autosermark/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		if [ "$mcenable" == "1" ] && [ "${clash_process_started}" = "1" ]; then
			echo_date "开启Clash代理组状态保存服务，每分钟自动保存代理组设置" >> $LOG_FILE
			echo_date "开启Clash代理组状态保存服务，每分钟自动保存代理组设置" > /tmp/upload/merlinclash_node_mark.log
			cru a autosermark "* * * * * /bin/sh /jffs/softcenter/scripts/clash_node_mark.sh setmark"
			#同时启动日志监测，1小时检测一次
			cru a autologdel "0 * * * * /bin/sh /jffs/softcenter/scripts/clash_logautodel.sh"		
		else	
			echo_date "未检查到Clash进程，不开启Clash代理组状态保存服务" >> $LOG_FILE
		fi
	fi
}

write_clash_restart_cron_job(){
	mscrm=${merlinclash_select_clash_restart_minute}
	mscrh=${merlinclash_select_clash_restart_hour}
	mscrw=${merlinclash_select_clash_restart_week}
	mscrd=${merlinclash_select_clash_restart_day}
	mscrm_2=${merlinclash_select_clash_restart_minute_2}
	remove_clash_restart_regularly(){
		if [ -n "$(cru l|grep clash_restart)" ]; then		
			sed -i '/clash_restart/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		fi
	}
	start_clash_restart_regularly_day(){
		remove_clash_restart_regularly
		cru a clash_restart ${mscrm} ${mscrh}" * * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
		echo_date "Clash将于每日的${mscrh}时${mscrm}分重启" >> $LOG_FILE
	}
	start_clash_restart_regularly_week(){
		remove_clash_restart_regularly
		cru a clash_restart ${mscrm} ${mscrh}" * * "${mscrw}" /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
		echo_date "Clash将于每周${mscrw}的${mscrh}时${mscrm}分重启" >> $LOG_FILE
	}
	start_clash_restart_regularly_month(){
		remove_clash_restart_regularly
		cru a clash_restart ${mscrm} ${mscrh} ${mscrd}" * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
		echo_date "Clash将于每月${mscrd}号的${mscrh}时${mscrm}分重启" >> $LOG_FILE
	}

	start_clash_restart_regularly_mhour(){
		remove_clash_restart_regularly
		if [ "$mscrm_2" == "2" ] || [ "$mscrm_2" == "5" ] || [ "$mscrm_2" == "10" ] || [ "$mscrm_2" == "15" ] || [ "$mscrm_2" == "20" ] || [ "$mscrm_2" == "25" ] || [ "$mscrm_2" == "30" ]; then
			cru a clash_restart "*/"${mscrm_2}" * * * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
			echo_date "Clash将每隔${mscrm_2}分钟重启" >> $LOG_FILE
		fi
		if [ "$mscrm_2" == "1" ] || [ "$mscrm_2" == "3" ] || [ "$mscrm_2" == "6" ] || [ "$mscrm_2" == "12" ]; then
			cru a clash_restart "0 */"${mscrm_2} "* * * /bin/sh /jffs/softcenter/scripts/clash_restart_update.sh"
			echo_date "Clash将每隔${mscrm_2}小时重启" >> $LOG_FILE
		fi
	}
	mscr=${merlinclash_select_clash_restart}
	case $mscr in
	1)
		echo_date "定时重启处于关闭状态" >> $LOG_FILE
		remove_clash_restart_regularly
		;;
	2)
		start_clash_restart_regularly_day
		;;
	3)
		start_clash_restart_regularly_week
		;;
	4)
		start_clash_restart_regularly_month
		;;
	5)
		start_clash_restart_regularly_mhour
		;;
	*)
		echo_date "定时重启处于关闭状态" >> $LOG_FILE
		remove_clash_restart_regularly
		;;
	esac
}

### 关闭各种服务
kill_process() {
	clash_process=$(pidof clash)
	if [ -n "$clash_process" ]; then
		echo_date "关闭Clash进程.."
		killall clash_dog.sh >/dev/null 2>&1
		killall clash >/dev/null 2>&1
		kill -9 "$clash_process" >/dev/null 2>&1
	fi
}

kill_cron_job() {
	if [ -n "$(cru l | grep autosermark)" ]; then
		echo_date 关闭代理组状态保存服务... >> $LOG_FILE
		sed -i '/autosermark/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep autologdel)" ]; then
		echo_date 关闭日志监测服务... >> $LOG_FILE
		sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l|grep autoupdate)" ]; then
		echo_date 关闭定时订阅任务... >> $LOG_FILE	
		sed -i '/autoupdate/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l|grep clash_restart)" ]; then
		echo_date 关闭定时重启任务... >> $LOG_FILE	
		sed -i '/clash_restart/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}

flush_nat() {
	echo_date 清除iptables规则... >> $LOG_FILE
	# flush rules and set if any
	iptables -t nat -D PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
	iptables -t mangle -D merlinclash_PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	iptables -t mangle -D merlinclash_PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	iptables -t mangle -D merlinclash_PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D merlinclash_PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D merlinclash_PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D merlinclash_PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br5+ -j RETURN >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p tcp -j merlinclash_PREROUTING >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j merlinclash_PREROUTING >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p tcp -j merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp --dport 53 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p udp --dport 53 -j RETURN >/dev/null 2>&1

	dns_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/udp dpt:53/=" | sort -r)
	for dns_index in $dns_indexs; do
		iptables -t nat -D PREROUTING $dns_index >/dev/null 2>&1
	done

	nat_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/clash/=' | sort -r)
	for nat_index in $nat_indexs; do
		iptables -t nat -D PREROUTING $nat_index >/dev/null 2>&1
	done
	cir_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/china_ip_route/=' | sort -r)
	for cir_index in $cir_indexs; do
		iptables -t nat -D PREROUTING $cir_index >/dev/null 2>&1
	done
	cir_indexs2=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/china_ip_route/=' | sort -r)
	for cir_indexs in $cir_indexs2; do
		iptables -t mangle -D merlinclash_PREROUTING $cir_indexs >/dev/null 2>&1
	done
	cir_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/china_ip_route6/=' | sort -r)
	for cir_indexs in $cir_indexs6; do
		ip6tables -t mangle -D merlinclash_PREROUTING $cir_indexs >/dev/null 2>&1
	done
	dir_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/direct_list/=' | sort -r)
	for dir_index in $dir_indexs; do
		iptables -t mangle -D merlinclash_PREROUTING $dir_index >/dev/null 2>&1
	done
	dir_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/direct_list6/=' | sort -r)
	for dir_indexs in $dir_indexs6; do
		ip6tables -t mangle -D merlinclash_PREROUTING $dir_indexs >/dev/null 2>&1
	done
	noipb_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/macblacklist_dns/=' | sort -r)
	for noipb_index in $noipb_indexs; do
		iptables -t nat -D PREROUTING $noipb_index >/dev/null 2>&1
	done
	mnoipb_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/macblacklist_dns/=' | sort -r)
	for mnoipb_index in $mnoipb_indexs; do
		iptables -t mangle -D merlinclash_PREROUTING $mnoipb_index >/dev/null 2>&1
	done
	mnoipb_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/macblacklist_dns/=' | sort -r)
	for mnoipb_indexs in $mnoipb_indexs6; do
		ip6tables -t mangle -D merlinclash_PREROUTING $mnoipb_indexs >/dev/null 2>&1
	done
	macwhite_indexs=$(iptables -nvL merlinclash_PREROUTING -t nat | sed 1,2d | sed -n '/macwhitelist_dns/=' | sort -r)
	for macwhite_index in $macwhite_indexs; do
		iptables -t nat -D merlinclash_PREROUTING $macwhite_index >/dev/null 2>&1
	done
	ipb_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/ipblacklist_dns/=' | sort -r)
	for ipb_index in $ipb_indexs; do
		iptables -t nat -D PREROUTING $ipb_index >/dev/null 2>&1
	done
	ipw_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/ipwhitelist_dns/=' | sort -r)
	for ipw_index in $ipw_indexs; do
		iptables -t nat -D PREROUTING $ipw_index >/dev/null 2>&1
	done
	mangle_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/clash/=' | sort -r)
    for mangle_index in $mangle_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $mangle_index >/dev/null 2>&1
    done
	mangle6_indexs=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/clash/=' | sort -r)
    for mangle6_index in $mangle6_indexs; do
        ip6tables -t mangle -D merlinclash_PREROUTING $mangle6_index >/dev/null 2>&1
    done
	mangle4_indexs=$(iptables -nvL PREROUTING -t mangle | sed 1,2d | sed -n '/clash/=' | sort -r)
    for mangle4_index in $mangle4_indexs; do
        iptables -t mangle -D PREROUTING $mangle4_index >/dev/null 2>&1
    done
	mangle2_indexs=$(ip6tables -nvL PREROUTING -t mangle | sed 1,2d | sed -n '/clash/=' | sort -r)
    for mangle2_index in $mangle2_indexs; do
        ip6tables -t mangle -D PREROUTING $mangle2_index >/dev/null 2>&1
    done

	lwl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_mac_whitelist/=" | sort -r)
    for lwl_index in $lwl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lwl_index >/dev/null 2>&1
    done
	lwl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_ip_whitelist/=" | sort -r)
    for lwl_index in $lwl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lwl_index >/dev/null 2>&1
    done

	lwln_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/lan_mac_whitelist/=" | sort -r)
    for lwln_index in $lwln_indexs; do
        iptables -t nat -D PREROUTING $lwln_index >/dev/null 2>&1
    done
	lwln_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/lan_ip_whitelist/=" | sort -r)
    for lwln_index in $lwln_indexs; do
        iptables -t nat -D PREROUTING $lwln_index >/dev/null 2>&1
    done

	lbl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_mac_blacklist/=" | sort -r)
    for lbl_index in $lbl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lbl_index >/dev/null 2>&1
    done
	lbl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_ip_blacklist/=" | sort -r)
    for lbl_index in $lbl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lbl_index >/dev/null 2>&1
    done

	lbl_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_mac_blacklist/=" | sort -r)
    for lbl_indexs in $lbl_indexs6; do
        ip6tables -t mangle -D merlinclash_PREROUTING $lbl_indexs >/dev/null 2>&1
    done
	lbl_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_ip_blacklist/=" | sort -r)
    for lbl_indexs in $lbl_indexs6; do
        ip6tables -t mangle -D merlinclash_PREROUTING $lbl_indexs >/dev/null 2>&1
    done

	mac_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/MAC/=' | sort -r)
    for mac_index in $mac_indexs; do
        iptables -t nat -D PREROUTING $mac_index >/dev/null 2>&1
    done
	mac4_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/MAC/=' | sort -r)
    for mac4_index in $mac4_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $mac4_index >/dev/null 2>&1
    done
	mac6_indexs=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/MAC/=' | sort -r)
    for mac6_index in $mac6_indexs; do
        ip6tables -t mangle -D merlinclash_PREROUTING $mac6_index >/dev/null 2>&1
    done
	proxyarround_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/ipset_proxyarround/=' | sort -r)
    for proxyarround_index in $proxyarround_indexs; do
        iptables -t nat -D PREROUTING $proxyarround_index >/dev/null 2>&1
    done
	proxyarround4_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/ipset_proxyarround/=' | sort -r)
    for proxyarround4_index in $proxyarround4_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $proxyarround4_index >/dev/null 2>&1
    done
	proxyarround6_indexs=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n '/ipset_proxyarround6/=' | sort -r)
    for proxyarround6_index in $proxyarround6_indexs; do
        ip6tables -t mangle -D merlinclash_PREROUTING $proxyarround6_index >/dev/null 2>&1
    done
    iptables -t nat -D PREROUTING -p tcp -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -j ACCEPT >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j ACCEPT >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p tcp -j ACCEPT >/dev/null 2>&1
	iptables -t mangle -D QOSO0 -m mark --mark "$ip_prefix_hex" -j RETURN >/dev/null 2>&1

	#清空OUTPUT链
	iptables -t nat -F OUTPUT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$ip_prefix_hex" -j merlinclash_EXT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$opvpn_prefix_hex" -j merlinclash_EXT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$pptpvpn_prefix_hex" -j merlinclash_EXT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$ipsec_prefix_hex" -j merlinclash_EXT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m set --match-set router dst -j merlinclash >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -j merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t nat -X merlinclash_OUTPUT >/dev/null 2>&1
	
	iptables -t nat -F merlinclash >/dev/null 2>&1 && iptables -t nat -X merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_NOR >/dev/null 2>&1 && iptables -t nat -X merlinclash_NOR >/dev/null 2>&1
	iptables -t nat -F merlinclash_CHN >/dev/null 2>&1 && iptables -t nat -X merlinclash_CHN >/dev/null 2>&1
	iptables -t nat -F merlinclash_EXT >/dev/null 2>&1 && iptables -t nat -X merlinclash_EXT >/dev/null 2>&1
	iptables -t mangle -F merlinclash >/dev/null 2>&1 && iptables -t mangle -X merlinclash >/dev/null 2>&1
	iptables -t mangle -F merlinclash_NOR >/dev/null 2>&1 && iptables -t mangle -X merlinclash_NOR >/dev/null 2>&1
	iptables -t mangle -F merlinclash_CHN >/dev/null 2>&1 && iptables -t mangle -X merlinclash_CHN >/dev/null 2>&1
	iptables -t mangle -F merlinclash_divert >/dev/null 2>&1 && iptables -t mangle -X merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -F merlinclash_PREROUTING >/dev/null 2>&1 && iptables -t mangle -X merlinclash_PREROUTING >/dev/null 2>&1
	iptables -t mangle -D OUTPUT -j merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t mangle -F merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t mangle -X merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -X merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_NOR >/dev/null 2>&1 && ip6tables -t mangle -X merlinclash_NOR >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_CHN >/dev/null 2>&1 && ip6tables -t mangle -X merlinclash_CHN >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash >/dev/null 2>&1 && ip6tables -t mangle -X merlinclash >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_PREROUTING >/dev/null 2>&1 && ip6tables -t mangle -X merlinclash_PREROUTING >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_divert >/dev/null 2>&1 && ip6tables -t mangle -X merlinclash_divert >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p tcp -j merlinclash_divert >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p udp -j merlinclash_divert >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p tcp -j merlinclash_PREROUTING >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p udp -j merlinclash_PREROUTING >/dev/null 2>&1
	ip6tables -t mangle -D OUTPUT -j merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p udp --dport 53 -m set --match-set lan_mac_blacklist src -j DROP >/dev/null 2>&1
	#清除mangle表中的家长管理规则
	iptables -t mangle -S PREROUTING | grep PControls | sed 's/-A/-D/g' | while read -r line; do iptables -t mangle $line; done >/dev/null 2>&1
	ip6tables -t mangle -S PREROUTING | grep PControls | sed 's/-A/-D/g' | while read -r line; do ip6tables -t mangle $line; done >/dev/null 2>&1
	iptables -t mangle -F PControls >/dev/null 2>&1
	iptables -t mangle -X PControls >/dev/null 2>&1
	ip6tables -t mangle -F PControls >/dev/null 2>&1
	ip6tables -t mangle -X PControls >/dev/null 2>&1

	iptables -t nat -F merlinclash >/dev/null 2>&1 && iptables -t nat -X merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_EXT >/dev/null 2>&1 && iptables -t nat -X merlinclash_EXT >/dev/null 2>&1
	#echo_date 删除ip route规则.
	ip rule del fwmark 1 lookup 100 >/dev/null 2>&1
	ip route del local default dev lo table 100 >/dev/null 2>&1
	ip -4 route del local default dev lo table 233 >/dev/null 2>&1
	ip -4 rule del fwmark 0x2333         table 233 >/dev/null 2>&1
	ip -4 rule del fwmark 0x1111         table 233 >/dev/null 2>&1
	ip -6 route del local default dev lo table 233 >/dev/null 2>&1
	ip -6 rule del fwmark 0x2333         table 233 >/dev/null 2>&1
	ip -6 rule del fwmark 0x1111         table 233 >/dev/null 2>&1
	#
	echo_date "清除ipset规则集" >> $LOG_FILE
	ipset -F direct_list >/dev/null 2>&1 && ipset -X direct_list >/dev/null 2>&1
	ipset -F direct_list6 >/dev/null 2>&1 && ipset -X direct_list6 >/dev/null 2>&1
	ipset -F router >/dev/null 2>&1 && ipset -X router >/dev/null 2>&1
	ipset -F ipset_proxy >/dev/null 2>&1 && ipset -X ipset_proxy >/dev/null 2>&1
	ipset -F ipset_proxyarround >/dev/null 2>&1 && ipset -X ipset_proxyarround >/dev/null 2>&1
	ipset -F ipset_proxy6 >/dev/null 2>&1 && ipset -X ipset_proxy6 >/dev/null 2>&1
	ipset -F ipset_proxyarround6 >/dev/null 2>&1 && ipset -X ipset_proxyarround6 >/dev/null 2>&1

	ipset destroy china_ip_route >/dev/null 2>&1
	ipset destroy china_ip_route6 >/dev/null 2>&1
	ipset destroy lan_ip_blacklist >/dev/null 2>&1
	ipset destroy lan_mac_blacklist >/dev/null 2>&1
	ipset destroy lan_ip_whitelist >/dev/null 2>&1
	ipset destroy lan_mac_whitelist >/dev/null 2>&1
	ipset destroy macblacklist_dns >/dev/null 2>&1
	ipset destroy macwhitelist_dns >/dev/null 2>&1
	ipset destroy ipblacklist_dns >/dev/null 2>&1
	ipset destroy ipwhitelist_dns >/dev/null 2>&1
	echo_date "清除iptables规则完毕..." >> $LOG_FILE
	if [ -f "/tmp/clash_firewall_triggered" ]; then
    	rm -f /tmp/clash_firewall_triggered
	else
		restart_firewall
	fi
}

restart_firewall() {
	if [ "${merlinclash_ipt_proxyrouter_sw}" == "1" ]; then
		# 设置标志，表示这次防火墙重启是由flush_nat触发的
		touch /tmp/clash_firewall_triggered
		service restart_firewall >/dev/null 2>&1
		logger "[软件中心-Magic Catling]: 重启防火墙...！"
		echo_date "重启防火墙..." >> $LOG_FILE
	fi
}

close_in_five() {
	echo_date "插件将在5秒后自动关闭！！" >> $LOG_FILE
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1s
		echo_date $i
		let i--
	done
	
	stop_config >/dev/null 2>&1

	echo_date "🔴Magic Catling已关闭！！" >> $LOG_FILE
	echo_date ======================= Magic Catling ======================= >> $LOG_FILE
	unset_lock
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	exit
}

stop_config(){
	echo_date 触发脚本stop_config >> $LOG_FILE
	echo_date ======================= Magic Catling ======================= >> $LOG_FILE
	echo_date ---------------------- 🔴关闭相关程序 ---------------------- >> $LOG_FILE
	kill_cron_job
	clean_ipset
	dbus set merlinclash_enable="0"
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && restart_dnsmasq
	kill_process
	echo_date -------------------- 🔴清除iptables规则 -------------------- >> $LOG_FILE
	flush_nat
}

### 主流程
apply_mc() {
	echo_date ======================= Magic Catling ======================= >> $LOG_FILE
	echo_date ------------------------ 🟠启动准备 ------------------------ >> $LOG_FILE
	check_ss #兼容检查
	clean_ipset	#清除ipset
	kill_process #关闭进程
	kill_cron_job #关闭定时任务
	flush_nat #清除iptables规则
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && restart_dnsmasq #重启dnsmasq
	echo_date ------------------------ 🟢开始启动 ------------------------ >> $LOG_FILE
	echo_date ---------------------- 📌设置启动参数 ---------------------- >> $LOG_FILE
	check_yaml	#检查合并yaml文件
	check_rule	#拼合自定义规则
	check_dnsplan	#检查DNS方案
	set_Tolerance 	#设置延迟容差
	check_coremark	#检查内核代理组状态
	start_custom	#设置启动参数
	get_ports	#获取端口号
	echo_date ---------------------- 📌创建ipset规则 --------------------- >> $LOG_FILE
	creat_ipset	#创建相关ipset规则
	set_sys	#启动增熵
	echo_date ---------------------- 📌启动Mihomo内核 --------------------- >> $LOG_FILE
	start_clash	#启动内核
	start_remark	#恢复记忆节点
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && echo_date --------------------- 📌创建iptables规则 -------------------- >> $LOG_FILE
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && load_nat
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && restart_dnsmasq #重启dnsmasq
	echo_date ----------------------- 📌启动后处理 ------------------------ >> $LOG_FILE
	write_setmark_cron_job #节点后台记忆
	write_update_yaml_cron #定时订阅
	write_clash_restart_cron_job #定时重启
    echo_date "" >> $LOG_FILE
	echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo_date "                      管理面板：$lan_ipaddr:$ecport      " >> $LOG_FILE
    [ -n "${httpport}" ] &&  [ "${httpport}" != "null" ] && echo_date "                     Http代理：$lan_ipaddr:$httpport "  >> $LOG_FILE
    [ -n "${socksport}" ] &&  [ "${socksport}" != "null" ] && echo_date "                    Socks代理：$lan_ipaddr:$socksport " >> $LOG_FILE
	[ -n "${mixport}" ] &&  [ "${mixport}" != "null" ] && echo_date "                      混合代理：$lan_ipaddr:$mixport " >> $LOG_FILE	
    echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
    echo_date "                     ✅恭喜！开启MerlinClash成功！" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date   "如果不能科学上网，请刷新设备dns缓存，或者等待几分钟再尝试" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date ======================= Magic Catling ======================= >> $LOG_FILE
}

apply_nat() {
	echo_date --------------------- 🔴清除iptables规则 -------------------- >> $LOG_FILE
	flush_nat
	echo_date ---------------------- 📌创建ipset规则 ---------------------- >> $LOG_FILE
	clean_ipset
	creat_ipset
	get_ports
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && echo_date --------------------- 📌创建iptables规则 -------------------- >> $LOG_FILE
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && load_nat
	[ "${merlinclash_ipt_closeproxy_sw}" != "1" ] && restart_dnsmasq
	echo_date "=============== Magic Catling iptable 重写完成===============" >> $LOG_FILE
}

case $ACTION in

start)
	set_lock
	#日志自动删除，防止长时间未重启文件过大
	sh /jffs/softcenter/scripts/clash_logautodel.sh
	if [ "${merlinclash_enable}" == "1" ];then
		if [ "${merlinclash_set_startdelay_sw}" == "1" ]; then		
			sleeptime=${merlinclash_set_startdelay_val}
			logger "[软件中心-开机自启]: Magic Catling 自启推迟:$sleeptime秒！"
			sleep ${sleeptime}s
			logger "[软件中心-开机自启]: Magic Catling 自启推迟:$sleeptime秒 结束！"
		fi
		apply_mc >>"$LOG_FILE"
	else
		logger "[软件中心-开机自启]: Magic Catling 未设置开机启动！"
	fi
	unset_lock
	;;

start_nat)
	set_lock
	logger "[软件中心-NAT重启]: IPTABLES发生变化，Magic Catling NAT重启！"
	echo_date "[软件中心-NAT重启]: IPTABLES发生变化，Magic Catling NAT重启！" >> $LOG_FILE
	echo_date "[软件中心-NAT重启]: Magic Catling开关状态为：【${merlinclash_enable}】" >> $LOG_FILE
	if [ "${merlinclash_enable}" == "1" -a "$(pidof clash)" -a "$(netstat -anp | grep clash | head -n 5)" -a ! -n "$(grep "Parse config error" /tmp/clash_run.log)" ]; then	
		logger "[软件中心-NAT重启]: Magic Catling 完全启动，开始重写dns配置和iptables"
		echo_date "[软件中心-NAT重启]: Magic Catling 完全启动，开始重写dns配置和iptables" >> $LOG_FILE
		apply_nat >>"$LOG_FILE"
	else
		logger "[软件中心-NAT重启]: Magic Catling 插件未开启或Clash未完全启动，终止写入dns配置和iptables"
		echo_date "[软件中心-NAT重启]: Magic Catling 插件未开启或Clash未完全启动，终止写入dns配置和iptables" >> $LOG_FILE
	fi
	unset_lock
	;;
esac

case $2 in
start)
	echo "" > /tmp/upload/merlinclash_log.txt
	http_response "$1"
	set_lock
	if [ "${merlinclash_enable}" == "1" ];then
        apply_mc
	else
		stop_config
		echo_date >> $LOG_FILE
		echo_date 你已经成功关闭Magic Catling~ >> $LOG_FILE
		echo_date See you again! >> $LOG_FILE
		echo_date >> $LOG_FILE
		echo_date ======================= Magic Catling ======================= >> $LOG_FILE
	fi
	unset_lock
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
stop)
	stop_config
	echo_date >> $LOG_FILE
	echo_date 你已经成功关闭Magic Catling~ >> $LOG_FILE
	echo_date See you again! >> $LOG_FILE
	echo_date >> $LOG_FILE
	echo_date ======================= Magic Catling ======================= >> $LOG_FILE
	;;
restart)
	if [ "${merlinclash_enable}" == "1" ];then
        apply_mc
	else
		stop_config
		echo_date >> $LOG_FILE
		echo_date 你已经成功关闭Magic Catling~ >> $LOG_FILE
		echo_date See you again! >> $LOG_FILE
		echo_date >> $LOG_FILE
	fi
	;;
esac
