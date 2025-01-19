#!/bin/sh

source /jffs/softcenter/scripts/base.sh
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
alias echo_date2='echo 【$(date +%Y年%m月%d日\ %X)】'
LOG_FILE=/tmp/upload/merlinclash_log.txt
SIMLOG_FILE=/tmp/upload/merlinclash_simlog.txt
LOCK_FILE=/var/lock/merlinclash.lock
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
debug_file=/tmp/mcdebug.txt
eval `dbus export merlinclash`

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
get_list(){
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	echo $b
}
yamlname=$(get merlinclash_yamlsel)
mcenable=$(get merlinclash_enable)
kpenable=$(get merlinclash_koolproxy_enable)
umenable=$(get merlinclash_unblockmusic_enable)
uploadfilename=$(get merlinclash_uploadfilename)
bypassmode=$(get merlinclash_bypassmode)
modesel=$(get merlinclash_clashmode)
dnshijacksel=$(get merlinclash_dnshijack)
d2s=$(get merlinclash_d2s)
d2s_dnsnp=$(get merlinclash_d2s_dnsnp)
d2s_lp=$(get merlinclash_d2s_lp)
dfib=$(get merlinclash_dns_fakeipblack)
cusruleplan=$(get merlinclash_cusrule_plan)
retryTimes=$(get merlinclash_check_delay_time)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
yamlbakpath=/jffs/softcenter/merlinclash/yaml_bak/$yamlname.yaml
#提取配置认证码
secret=$(cat $yamlpath | awk '/secret:/{print $2}'  | xargs echo -n)

#20200904 新增host.yaml处理
hostsel=$(get merlinclash_hostsel)
hostsyaml=/jffs/softcenter/merlinclash/yaml_basic/host/$hostsel.yaml
tproxy=$(cat $yamlpath | awk '/tproxy:/{print $2}'  | xargs echo -n)
#端口取值
	httpport=$(cat $yamlpath | awk -F: '/^port/{print $2}' | xargs echo -n)
	socksport=$(cat $yamlpath | awk -F: '/^socks-port/{print $2}' | xargs echo -n)
	proxy_port=$(cat $yamlpath | awk -F: '/^redir-port/{print $2}' | xargs echo -n)
	tproxy_port=$(cat $yamlpath | awk -F: '/^tproxy-port/{print $2}' | xargs echo -n)
	dnslistenport=$(cat $yamlpath | awk -F: '/listen/{print $3}' | xargs echo -n)

if [ "$modesel" == "default" ]; then
    modesel=$(cat $yamlpath | grep "^mode:" | awk -F "[: ]" '{print $3}'| xargs echo -n)
fi
ISP_DNS1=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
ISP_DNS2=$(nvram get wan0_dns | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 2p)
ISP6_DNS1=$(nvram get ipv6_dns1 | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
ISP6_DNS2=$(nvram get ipv6_dns2 | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
DHCP_DNS1=$(nvram get dhcp_dns1_x | sed 's/ /\n/g' | grep -v 0.0.0.0 | grep -v 127.0.0.1 | sed -n 1p)
IFIP_DNS1=$(echo $ISP_DNS1 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
IFIP_DNS2=$(echo $ISP_DNS2 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
IFIP_DHCPDNS1=$(echo $DHCP_DNS1 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:")
ipv6_flag="0"
chromecast_nu=""
lan_ipaddr=$(nvram get lan_ipaddr)
wan_ipaddr=$(nvram get wan0_ipaddr)
wan6_ipaddr=$(nvram get ipv6_rtr_addr)
#取公网接口+
ifa=$(ip addr show  | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $0}' | grep "$wan_ipaddr")
interface=$(echo ${ifa##* })
#取公网接口-
ssh_port=$(nvram get sshd_port)
head_tmp=/jffs/softcenter/merlinclash/yaml_basic/head.yaml
rm -rf /tmp/upload/clash_error.log
rm -rf /tmp/upload/dns_read_error.log
ip_prefix_hex=$(nvram get lan_ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
opvpn_prefix_hex=$(nvram get vpn_server_local | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
pptpvpn_prefix_hex=$(nvram get pptpd_clients | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')

ipsec_prefix_hex=$(nvram get ipsec_profile_1  | grep -E -o "[0-9]+\.[0-9]+\.[0-9]+" | head  -n1 | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00\n")}')
uploadpath=/tmp/upload
bridge=$(ifconfig | grep br | awk -F' ' '{print $1}')

mkdir -p /tmp/upload
rm -rf /tmp/upload/UnblockMusic.log
p_lan_bypass_flag="0"

#初始化赋值
if [ "${LINUX_VER}" -lt "41" ]; then
	dbus set merlinclash_tproxymode="closed"
	dbus set merlinclash_ipv6switch="0"
	ipv6switch=$(get merlinclash_ipv6switch)
fi

tproxymode=$(get merlinclash_tproxymode)
cirswitch=$(get merlinclash_cirswitch)
ipv6switch=$(get merlinclash_ipv6switch)
dnsplan=$(get merlinclash_dnsplan)
dnsgoclash=$(get merlinclash_dnsgoclash)
closeproxy=$(get merlinclash_closeproxy)
recordbycron=$(get merlinclash_recordbycron)
coremark="0"
dbus set merlinclash_iptablessel="fangan1"
iptsel=$(get merlinclash_iptablessel)

check_coremark(){
	if [ "${recordbycron}" != "1" ];then
		if [ "$(nvram get sc_mount)" == "1" ]; then
			coremark="1"
            echo_date "检测到U盘已挂载，将使用Clash内核内置代理组状态保存服务" >> $LOG_FILE
        elif [ "${LINUX_VER}" -gt "41" ]; then
            coremark="1"
            echo_date "检测到您的路由Linux内核版本大于4.1，将使用Clash内核内置代理组状态保存服务" >> $LOG_FILE
        else
            echo_date "使用定时脚本记录代理组状态" >> $LOG_FILE  
        fi
    else
    	echo_date "已开启强制使用定时脚本记录代理组状态" >> $LOG_FILE
    fi

}


set_lock() {
	exec 1000>"$LOCK_FILE"
	flock -x 1000
}

unset_lock() {
	flock -u 1000
	rm -rf "$LOCK_FILE"
}

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
urldecode(){
	printf $(echo -n "$1" | sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"\n"
}

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
move_config(){
	#查找upload文件夹是否有刚刚上传的yaml文件，正常只有一份
	#name=$(find $uploadpath  -name "$yamlname.yaml" |sed 's#.*/##')
	echo_date "上传的文件名是$uploadfilename" >> $LOG_FILE
	if [ -f "/tmp/upload/$uploadfilename" ]; then
		#后台执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为上传文件名.yaml
		echo_date "yaml文件合法性检查" >> $LOG_FILE
		check_yamlfile
		if [ $? == "1" ]; then
			echo_date "开始yaml配置文件预处理"
			mkdir -p /tmp/upload/yaml
			rm -rf /tmp/upload/yaml/*
			cp -rf /tmp/upload/$uploadfilename /tmp/upload/yaml/$uploadfilename
			sh /jffs/softcenter/scripts/clash_yaml_upload_sub.sh
		else
			echo_date "配置文件不是合法的yaml文件，请检查订阅连接是否有误" >> $LOG_FILE
			rm -rf /tmp/upload/$uploadfilename
			echo BBABBBBC >> $LOG_FILE
			exit 1
		fi
	else
		echo_date "没找到yaml配置文件"
		rm -rf /tmp/upload/*.yaml
		exit 1
	fi


}
check_yamlfile(){
	/bin/sh /jffs/softcenter/scripts/clash_checkyaml.sh "/tmp/upload/$uploadfilename"
}
httpdwatchdog(){
	if [ "$mcenable" == "1" ] ;then
		sed -i '/httpd_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		cru a httpd_watchdog "*/1 * * * * /bin/sh /jffs/softcenter/scripts/clash_httpdwatchdog.sh"
	else
		echo_date 关闭httpd看门狗... >> $LOG_FILE
		sed -i '/httpd_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}
watchdog(){
	watchdog=$(get merlinclash_watchdog)
	if [ "$mcenable" == "1" ] && [ "$watchdog" == "1" ];then
		sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		watcdogtime=$(get merlinclash_watchdog_delay_time)
		cru a clash_watchdog "*/$watcdogtime * * * * /bin/sh /jffs/softcenter/scripts/clash_watchdog.sh"
	else
		echo_date 关闭clash看门狗... >> $LOG_FILE
		sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}
write_setmark_cron_job(){
	if [ "${coremark}" == "1" ]; then
		echo_date "Linux内核版本大于4.1或者U盘已挂载，使用Clash内核内置代理组状态保存服务" >> $LOG_FILE
		echo_date "Linux内核版本大于4.1或者U盘已挂载，使用Clash内核内置代理组状态保存服务" > /tmp/upload/merlinclash_node_mark.log
		echo_date "------ 未使用定时脚本，本处无记录日志 -------" >> /tmp/upload/merlinclash_node_mark.log
	else
	  sed -i '/autosermark/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	  sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	  if [ "$mcenable" == "1" ];then
		  if [ "$(pidof clash)" -a "$(netstat -anp | grep clash | head -n 5)" -a ! -n "$(grep "Parse config error" /tmp/clash_run.log | head -n 5)" ] ; then
			  echo_date "开启Clash代理组状态保存服务，每分钟自动保存代理组设置" >> $LOG_FILE
			  echo_date "开启Clash代理组状态保存服务，每分钟自动保存代理组设置" > /tmp/upload/merlinclash_node_mark.log
			  cru a autosermark "* * * * * /bin/sh /jffs/softcenter/scripts/clash_node_mark.sh setmark"
			  #同时启动日志监测，1小时检测一次
			  cru a autologdel "0 * * * * /bin/sh /jffs/softcenter/scripts/clash_logautodel.sh"		
		  else	
			  echo_date "未检查到Clash进程，不开启Clash代理组状态保存服务" >> $LOG_FILE
		  fi
	  fi
	fi
}
write_clash_restart_cron_job(){
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
	mscr=$(get merlinclash_select_clash_restart)
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
write_regular_cron_job(){
	remove_regular_subscribe(){
		if [ -n "$(cru l|grep regular_subscribe)" ]; then		
			sed -i '/regular_subscribe/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		fi
	}
	msrm=$(get merlinclash_select_regular_minute)
	msrh=$(get merlinclash_select_regular_hour)
	msrw=$(get merlinclash_select_regular_week)
	msrd=$(get merlinclash_select_regular_day)
	msrm_2=$(get merlinclash_select_regular_minute_2)
	start_regular_subscribe_day(){
		remove_regular_subscribe
		cru a regular_subscribe ${msrm} ${msrh}" * * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
		echo_date "将于每日的${msrh}时${msrm}分重新订阅" >> $LOG_FILE
	}
	start_regular_subscribe_week(){
		remove_regular_subscribe
		cru a regular_subscribe ${msrm} ${msrh}" * * "${msrw}" /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
		echo_date "将于每周${msrw}的${msrh}时${msrm}分重新订阅" >> $LOG_FILE
	}
	start_regular_subscribe_month(){
		remove_regular_subscribe
		cru a regular_subscribe ${msrm} ${msrh} ${msrd}" * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
		echo_date "将于每月${msrd}号的${msrh}时${msrm}分重新订阅" >> $LOG_FILE
	}

	start_regular_subscribe_mhour(){
		remove_regular_subscribe
		if [ "$msrm_2" == "2" ] || [ "$msrm_2" == "5" ] || [ "$msrm_2" == "10" ] || [ "$msrm_2" == "15" ] || [ "$msrm_2" == "20" ] || [ "$msrm_2" == "25" ] || [ "$msrm_2" == "30" ]; then
			cru a regular_subscribe "*/"${msrm_2}" * * * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
			echo_date "将每隔${msrm_2}分钟重新订阅" >> $LOG_FILE
		fi
		if [ "$msrm_2" == "1" ] || [ "$msrm_2" == "3" ] || [ "$msrm_2" == "6" ] || [ "$msrm_2" == "12" ]; then
			cru a regular_subscribe "0 */"${msrm_2} "* * * /bin/sh /jffs/softcenter/scripts/clash_regular_update.sh"
			echo_date "将每隔${msrm_2}小时重新订阅" >> $LOG_FILE
		fi
	}
	msrs=$(get merlinclash_select_regular_subscribe)
	case $msrs in
	1)
		echo_date "定时订阅处于关闭状态" >> $LOG_FILE
		remove_regular_subscribe
		;;
	2)
		start_regular_subscribe_day
		;;
	3)
		start_regular_subscribe_week
		;;
	4)
		start_regular_subscribe_month
		;;
	5)
		start_regular_subscribe_mhour
		;;
	*)
		echo_date "定时订阅处于关闭状态" >> $LOG_FILE
		remove_regular_subscribe
		;;
	esac
}
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
get_tproxymode_name() {
	case "$1" in
	closed)
		echo "Redir-TCP模式"
		;;
	udp)
		echo "开启UDP转发"
		;;
	tcpudp)
		echo "Tproxy-TCP&UDP模式"
		;;
	tcp)
		echo "Tproxy-TCP模式"
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
get_dns_plan() {
	case "$1" in
	rh)
		echo "RedirHost"
		;;
	fi)
		echo "FakeIp"
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
kill_cron_job() {
	if [ -n "$(cru l | grep autosermark)" ]; then
		echo_date 关闭代理组状态保存服务... >> $LOG_FILE
		sed -i '/autosermark/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep autologdel)" ]; then
		echo_date 关闭日志监测服务... >> $LOG_FILE
		sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep clash_watchdog)" ]; then
		echo_date 关闭Clash看门狗任务... >> $LOG_FILE
		sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep httpd_watchdog)" ]; then
		echo_date 关闭httpd看门狗任务... >> $LOG_FILE
		sed -i '/httpd_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l|grep regular_subscribe)" ]; then
		echo_date 关闭定时订阅任务... >> $LOG_FILE	
		sed -i '/regular_subscribe/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l|grep clash_restart)" ]; then
		echo_date 关闭定时重启任务... >> $LOG_FILE	
		sed -i '/clash_restart/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep d2s_watchdog)" ]; then
		echo_date 关闭dns2socks看门狗任务... >> $LOG_FILE
		sed -i '/d2s_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep clash_prenetflix)" ]; then
		echo_date 关闭预解析定时任务... >> $LOG_FILE
		sed -i '/clash_prenetflix/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}

kill_setmark(){
	pid_setmark=$(ps | grep clash_node_mark.sh | grep -v grep | awk '{print $1}')
	if [ -n "$pid_setmark" ]; then
		echo_date 关闭代理组状态保存服务进程...
		kill -9 "$pid_setmark" >/dev/null 2>&1
	fi
}

kill_process() {
	clash_process=$(pidof clash)
	kcp_process=$(pidof client_linux)
	d2s_process=$(pidof mc_dns2socks)
	if [ -n "$kcp_process" ]; then
		echo_date 关闭kcp协议进程... >> $LOG_FILE
		killall client_linux >/dev/null 2>&1
	fi
	if [ -n "$clash_process" ]; then
		echo_date "关闭Clash进程.."
		killall clash >/dev/null 2>&1
		kill -9 "$clash_process" >/dev/null 2>&1
	fi
	if [ -n "$d2s_process" ]; then
		echo_date "关闭dns2socks进程." >> $LOG_FILE
		kill -9 "$d2s_process" >/dev/null 2>&1
	fi
}
kill_clash() {
	clash_process=$(pidof clash)	
	if [ -n "$clash_process" ]; then
		echo_date "关闭Clash进程.."
		killall clash >/dev/null 2>&1
		kill -9 "$clash_process" >/dev/null 2>&1
# 		echo_date 关闭Clash进程...
# 		killall clash >/dev/null 2>&1
# 		kill -9 "$clash_process" >/dev/null 2>&1
	fi	
}
flush_nat() {
	echo_date 清除iptables规则... >> $LOG_FILE
	# flush rules and set if any
	iptables -t nat -D PREROUTING -p udp -d 8.8.4.4 --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p udp -d 8.8.8.8 --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	iptables -t mangle -D merlinclash_PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D merlinclash_PREROUTING -i br1 -j RETURN >/dev/null 2>&1
	iptables -t nat -D PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D merlinclash_PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	iptables -t mangle -D merlinclash_PREROUTING -i br2 -j RETURN >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p tcp -j merlinclash_PREROUTING >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j merlinclash_PREROUTING >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p tcp -j merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp --dport 53 -j RETURN >/dev/null 2>&1
	ip6tables -t mangle -D PREROUTING -p udp --dport 53 -j RETURN >/dev/null 2>&1

	# 关闭控制面板端口
	close_port
	
    #iptables -t mangle -D PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_PREROUTING >/dev/null 2>&1
    #iptables -t mangle -D PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_PREROUTING >/dev/null 2>&1
	dns_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/udp dpt:53/=" | sort -r)
	#dns2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/"${lan_ipaddr}":"${dnslistenport}"/=" | sort -r)
	for dns_index in $dns_indexs; do
		iptables -t nat -D PREROUTING $dns_index >/dev/null 2>&1
	done
	#dns_indexs6=$(ip6tables -nvL PREROUTING -t mangle | sed 1,2d | sed -n "/udp dpt:53/=" | sort -r)
	#dns2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/"${lan_ipaddr}":"${dnslistenport}"/=" | sort -r)
	#for dns_indexs in $dns_indexs6; do
	#	ip6tables -t mangle -D PREROUTING $dns_indexs >/dev/null 2>&1
	#done
	#dns_indexs4=$(iptables -nvL PREROUTING -t mangle | sed 1,2d | sed -n "/udp dpt:53/=" | sort -r)
	#for dns_indexs in $dns_indexs4; do
	#	iptables -t mangle -D PREROUTING $dns_indexs >/dev/null 2>&1
	#done
	kp_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | sort -r)
	for kp_index in $kp_indexs; do
		iptables -t nat -D PREROUTING $kp_index >/dev/null 2>&1
	done
	clm_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/cloud_music/=' | sort -r)
	for clm_index in $clm_indexs; do
		iptables -t nat -D PREROUTING $clm_index >/dev/null 2>&1
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
	ssh_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/tcp dpt:"$ssh_port"/=" | sort -r)
    for ssh_index in $ssh_indexs; do
        iptables -t nat -D PREROUTING $ssh_index >/dev/null 2>&1
    done
	sshm_indexs=$(iptables -nvL PREROUTING -t mangle | sed 1,2d | sed -n "/tcp dpt:"$ssh_port"/=" | sort -r)
    for sshm_index in $sshm_indexs; do
        iptables -t mangle -D PREROUTING $sshm_index >/dev/null 2>&1
    done
	lwl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_whitelist/=" | sort -r)
    for lwl_index in $lwl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lwl_index >/dev/null 2>&1
    done
	lwln_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n "/lan_whitelist/=" | sort -r)
    for lwln_index in $lwln_indexs; do
        iptables -t nat -D PREROUTING $lwln_index >/dev/null 2>&1
    done
	lbl_indexs=$(iptables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_blacklist/=" | sort -r)
    for lbl_index in $lbl_indexs; do
        iptables -t mangle -D merlinclash_PREROUTING $lbl_index >/dev/null 2>&1
    done
	lbl_indexs6=$(ip6tables -nvL merlinclash_PREROUTING -t mangle | sed 1,2d | sed -n "/lan_blacklist/=" | sort -r)
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
	iptables -t nat -D PREROUTING -p tcp --dport $ssh_port -j ACCEPT >/dev/null 2>&1
	iptables -t mangle -D OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
	iptables -t mangle -D QOSO0 -m mark --mark "$ip_prefix_hex" -j RETURN

	#清空OUTPUT链
	iptables -t nat -F OUTPUT >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$ip_prefix_hex" -j merlinclash_EXT
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$opvpn_prefix_hex" -j merlinclash_EXT
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$pptpvpn_prefix_hex" -j merlinclash_EXT
	iptables -t nat -D OUTPUT -p tcp -m mark --mark "$ipsec_prefix_hex" -j merlinclash_EXT
	iptables -t nat -D OUTPUT -p tcp -m set --match-set router dst -j merlinclash
	iptables -t nat -D OUTPUT -p tcp -j merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t nat -X merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t nat -F KOOLPROXY >/dev/null 2>&1 && iptables -t nat -X KOOLPROXY >/dev/null 2>&1
	iptables -t nat -F KOOLPROXY_ACT >/dev/null 2>&1 && iptables -t nat -X KOOLPROXY_ACT >/dev/null 2>&1
	iptables -t nat -F KP_HTTP >/dev/null 2>&1 && iptables -t nat -X KP_HTTP >/dev/null 2>&1
	iptables -t nat -F KP_HTTPS >/dev/null 2>&1 && iptables -t nat -X KP_HTTPS >/dev/null 2>&1
	iptables -t nat -F KP_BLOCK_HTTP > /dev/null 2>&1 && iptables -t nat -X KP_BLOCK_HTTP > /dev/null 2>&1
	iptables -t nat -F KP_BLOCK_HTTPS > /dev/null 2>&1 && iptables -t nat -X KP_BLOCK_HTTPS > /dev/null 2>&1	
	iptables -t nat -F KP_ALL_PORT > /dev/null 2>&1 && iptables -t nat -X KP_ALL_PORT > /dev/null 2>&1
	iptables -t nat -F cloud_music >/dev/null 2>&1 && iptables -t nat -X cloud_music >/dev/null 2>&1
	iptables -t nat -F merlinclash >/dev/null 2>&1 && iptables -t nat -X merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_NOR >/dev/null 2>&1 && iptables -t nat -X merlinclash_NOR >/dev/null 2>&1
	iptables -t nat -F merlinclash_CHN >/dev/null 2>&1 && iptables -t nat -X merlinclash_CHN >/dev/null 2>&1
	iptables -t nat -F merlinclash_EXT >/dev/null 2>&1 && iptables -t nat -X merlinclash_EXT >/dev/null 2>&1
	iptables -t mangle -F merlinclash >/dev/null 2>&1 && iptables -t mangle -X merlinclash >/dev/null 2>&1
	iptables -t mangle -F merlinclash_NOR >/dev/null 2>&1 && iptables -t mangle -X merlinclash_NOR >/dev/null 2>&1
	iptables -t mangle -F merlinclash_CHN >/dev/null 2>&1 && iptables -t mangle -X merlinclash_CHN >/dev/null 2>&1
	iptables -t mangle -F merlinclash_divert >/dev/null 2>&1 && iptables -t mangle -X merlinclash_divert >/dev/null 2>&1
	iptables -t mangle -F merlinclash_PREROUTING >/dev/null 2>&1 && iptables -t mangle -X merlinclash_PREROUTING >/dev/null 2>&1
	#iptables -t mangle -F OUTPUT >/dev/null 2>&1
	iptables -t mangle -D OUTPUT -j merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t mangle -F merlinclash_OUTPUT >/dev/null 2>&1
	iptables -t mangle -X merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -F merlinclash_OUTPUT >/dev/null 2>&1
	ip6tables -t mangle -X merlinclash_OUTPUT >/dev/null 2>&1
	#ip6tables -t mangle -F PREROUTING >/dev/null 2>&1
	#ip6tables -t mangle -F OUTPUT >/dev/null 2>&1
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
	ip6tables -t mangle -D PREROUTING -p udp --dport 53 -m set --match-set lan_blacklist src -j DROP >/dev/null 2>&1
	#清除mangle表中的家长管理规则
	iptables -t mangle -S PREROUTING | grep PControls | sed 's/-A/-D/g' | while read -r line; do iptables -t mangle $line; done
	ip6tables -t mangle -S PREROUTING | grep PControls | sed 's/-A/-D/g' | while read -r line; do ip6tables -t mangle $line; done
	iptables -t mangle -F PControls >/dev/null 2>&1
	iptables -t mangle -X PControls >/dev/null 2>&1
	ip6tables -t mangle -F PControls >/dev/null 2>&1
	ip6tables -t mangle -X PControls >/dev/null 2>&1
	#20201111---
	iptables -t nat -F merlinclash >/dev/null 2>&1 && iptables -t nat -X merlinclash >/dev/null 2>&1
	iptables -t nat -F merlinclash_EXT >/dev/null 2>&1 && iptables -t nat -X merlinclash_EXT >/dev/null 2>&1
	#echo_date 删除ip route规则.
	ip rule del fwmark 1 lookup 100
	ip route del local default dev lo table 100
	ip -4 route del local default dev lo table 233
	ip -4 rule del fwmark 0x2333         table 233
	ip -4 rule del fwmark 0x1111         table 233
	ip -6 route del local default dev lo table 233
	ip -6 rule del fwmark 0x2333         table 233
	ip -6 rule del fwmark 0x1111         table 233
	#
	echo_date "清除ipset规则集" >> $LOG_FILE
	ipset -F direct_list >/dev/null 2>&1 && ipset -X direct_list >/dev/null 2>&1
	ipset -F direct_list6 >/dev/null 2>&1 && ipset -X direct_list6 >/dev/null 2>&1
	ipset -F router >/dev/null 2>&1 && ipset -X router >/dev/null 2>&1
	ipset -F ipset_proxy >/dev/null 2>&1 && ipset -X ipset_proxy >/dev/null 2>&1
	ipset -F ipset_proxyarround >/dev/null 2>&1 && ipset -X ipset_proxyarround >/dev/null 2>&1
	ipset -F ipset_proxy6 >/dev/null 2>&1 && ipset -X ipset_proxy6 >/dev/null 2>&1
	ipset -F ipset_proxyarround6 >/dev/null 2>&1 && ipset -X ipset_proxyarround6 >/dev/null 2>&1
	#KP相关+++
	ipset -F black_koolproxy > /dev/null 2>&1 && ipset -X black_koolproxy > /dev/null 2>&1
	ipset -F white_koolproxy > /dev/null 2>&1 && ipset -X white_koolproxy > /dev/null 2>&1	
	ipset -F kp_full_port > /dev/null 2>&1 && ipset -X kp_full_port > /dev/null 2>&1
	#KP相关---
	ipset destroy china_ip_route >/dev/null 2>&1
	ipset destroy china_ip_route6 >/dev/null 2>&1
	#20201102
	ipset destroy m_lan_bypass >/dev/null 2>&1
	ipset destroy lan_whitelist >/dev/null 2>&1	
	ipset destroy kp_port_http >/dev/null 2>&1
	ipset destroy kp_port_https >/dev/null 2>&1
	ipset destroy macblacklist_dns >/dev/null 2>&1
	ipset destroy macwhitelist_dns >/dev/null 2>&1
	ipset destroy ipblacklist_dns >/dev/null 2>&1
	ipset destroy ipwhitelist_dns >/dev/null 2>&1
	echo_date "清除iptables规则完毕..." >> $LOG_FILE
}
detect() {
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		echo_date "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo_date "+   发现你未开启Enable JFFS custom scripts and configs选项！        +"
		echo_date "+  【软件中心】和【MerlinClash】插件都需要此项开启才能正常使用！！  +"
		echo_date "+   请前往【系统管理】- 【系统设置】去开启，并重启路由器后重试！！  +"
		echo_date "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		close_in_five
	fi
	# 检测是否在lan设置中是否自定义过dns,如果有给干掉
	dnsclear=$(get merlinclash_dnsclear)
	if [ "$dnsclear" == "1" ]; then
		echo_date "清除路由自定义DNS" >> $LOG_FILE
		echo_date "清除路由自定义DNS" >> $SIMLOG_FILE
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
		sed -i "s/^ipv6: false/ipv6: true/g" $yamlpath
		sed -i "s/^\ \ ipv6: false/\ \ ipv6: true/g" $yamlpath
	fi
}
close_in_five() {
	echo_date "插件将在5秒后自动关闭！！" >> $LOG_FILE
	echo_date "插件将在5秒后自动关闭！！" >> $SIMLOG_FILE
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1s
		echo_date $i
		let i--
	done
	dbus set merlinclash_enable="0"
	if [ "$umenable" == "1" ]; then
		sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh stop
	fi
	stop_config >/dev/null

	echo_date "Merlin Clash插件已关闭！！" >> $LOG_FILE
	echo_date "Merlin Clash插件已关闭！！" >> $SIMLOG_FILE
	echo_date ======================= Merlin Clash ========================
	unset_lock
	exit
}
#自定规则20200621
check_rule() {	
	yamlselchange=$(get merlinclash_yamlselchange)
	if [ "$yamlselchange" == "1" ]; then
		echo_date "检测到使用配置文件发生变化" >> $LOG_FILE
		/bin/sh /jffs/softcenter/scripts/clash_saveacls.sh use use 
	fi
	# acl_nu 获取已存数据序号
	if [ "$cusruleplan" == "easy" ]; then
		acl_nu=$(get_list merlinclash_acl_type 1 4)
		num=0
		if [ -n "$acl_nu" ]; then
			for acl in $acl_nu; do
				type=$(get merlinclash_acl_type_$acl)
				content=$(get merlinclash_acl_content_$acl)
				lianjie=$(get merlinclash_acl_lianjie_$acl)
				#protocol=$(get merlinclash_acl_protocol_$acl)
				#type=$(eval echo \$merlinclash_acl_type_$acl)
				#content=$(eval echo \$merlinclash_acl_content_$acl)
				#lianjie=$(eval echo \$merlinclash_acl_lianjie_$acl)
				#protocol=$(eval echo \$merlinclash_acl_protocol_$acl)
				type=$(decode_url_link $type)
				content=$(decode_url_link $content)
				lianjie=$(decode_url_link $lianjie)
				#protocol=$(decode_url_link $protocol)
				type=$(urldecode $type)
				content=$(urldecode $content)
				lianjie=$(urldecode $lianjie)
				#protocol=$(urldecode $protocol)
				#写入自定规则到当前配置文件
				num1=$(($num+1))
				rules_line=$(sed -n -e '/^rules:/=' $yamlpath)
				echo_date "写入第$num1条自定规则到当前配置文件" >> $LOG_FILE
				if [ "$type" == "IP-CIDR" ]; then
					sed "$rules_line a \ \ -\ $type,$content,$lianjie,no-resolve" -i $yamlpath
				else
				    sed "$rules_line a \ \ -\ $type,$content,$lianjie" -i $yamlpath
				fi
				let num++
			done
		else
			echo_date "没有自定规则" >> $LOG_FILE	
		fi
		dbus remove merlinclash_acl_type
		dbus remove merlinclash_acl_content
		dbus remove merlinclash_acl_lianjie
		dbus remove merlinclash_acl_protocol
	fi

	#格式化文本,避免rules:规则 - 未对齐而报错 -20200727
	sed -i '/^rules:/,/^port:/s/^[][ ]*- /  - /g' $yamlpath
	if [ -f "/jffs/softcenter/merlinclash/yaml_basic/script.yaml" ]; then
		sed -i '/^ *$/d' /jffs/softcenter/merlinclash/yaml_basic/script.yaml

		if [[ `cat /jffs/softcenter/merlinclash/yaml_basic/script.yaml |wc -l` -eq 0 ]]; then
			echo_date "没有自定脚本规则" >> $LOG_FILE
		else
			echo_date "存在自定脚本规则，开始写入" >> $LOG_FILE
			rules_line=$(sed -n -e '/^rules:/=' $yamlpath)
			rules_line=$(($rules_line-1))
			sed -i "${rules_line}r /jffs/softcenter/merlinclash/yaml_basic/script.yaml" $yamlpath
		fi
	fi
}
#自定义容差值20200920
set_Tolerance(){
	intervalbox=$(get merlinclash_interval_cbox)
	urltestbox=$(get merlinclash_urltestTolerance_cbox)
	if [ "$intervalbox" == "1" ]; then
		interval=$(get merlinclash_intervalsel)
		echo_date "调整测ping时间间隔为:$interval" >> $LOG_FILE
		sed -ri "s/(interval:)[^\"]*/interval: $interval/" $yamlpath
	else
		echo_date "未自定义测ping时间间隔，保持默认" >> $LOG_FILE
		
	fi
	if [ "$urltestbox" == "1" ]; then
		tolerance=$(get merlinclash_urltestTolerancesel)
		echo_date "调整测ping容差为:$tolerance" >> $LOG_FILE
		sed -ri "s/(tolerance:)[^\"]*/tolerance: $tolerance/" $yamlpath
	else
		echo_date "未自定义测ping容差，保持默认" >> $LOG_FILE
		
	fi

}
#设备绕行20200721 
lan_bypass(){	
	# deivce_nu 获取已存数据序号
	echo_date ---------------------- 设备管理检查区 开始 ------------------------ >> $LOG_FILE
	OS=$(uname -r)
	whitelist_nu=$(get_list merlinclash_whitelist_ip 1 4)
	device_nu=$(get_list merlinclash_device_ip 1 4)
	#KOOLPROXY&UnblockNeteaseMusic兼容
	KP_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | head -n1)
	CL_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/cloud_music/=' | head -n1)
	if [ "$CL_NU" != "" ]; then
		INSET_NU=$(expr "$CL_NU" + 1)
	else
		if [ "$KP_NU" == "" ]; then
			KP_NU=0
		fi
		INSET_NU=$(expr "$KP_NU" + 1)
	fi
	wlnum=0
	if lsmod | grep ip_set_hash_mac &>/dev/null; then
		echo_date "ip_set_hash_mac模块已加载" >> $LOG_FILE; 
	else
		#检查是否固件是否有ip_set_hash_mac模块
		if [ -f "/lib/modules/${OS}/kernel/net/netfilter/ipset/ip_set_hash_mac.ko" ]; then
			echo_date "加载ip_set_hash_mac模块" >> $LOG_FILE; 
			modprobe ip_set_hash_mac
		else
			echo_date "ip_set_hash_mac模块不存在，尝试使用黑白名单功能" >> $LOG_FILE
		fi
	fi
	#KOOLPROXY兼容重写
	kppid=$(pidof koolproxy)
	if [ -z "$kppid" ] || [ "$kpenable" == "0" ];then
		mnm=$(get merlinclash_nokpacl_method)
		echo_date "未开启护网大师，已设置【$(get_method_name $mnm)】过滤" >> $LOG_FILE
		list_flag="0"
		tproxymode=$(get merlinclash_tproxymode)
		if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
			list_flag="1" #REDIR-TCP / TPROXY-UDP
		elif [ "$tproxymode" == "tcp" ] || [ "$tproxymode" == "tcpudp" ]; then
			list_flag="2" #TPROXY-TCP / TCP&UDP
		fi
		nokpacl_nu=$(get_list merlinclash_nokpacl_ip 1 4)
		if [ -f "/jffs/softcenter/res/macblacklist_dns.ipset" ]; then
			ipset destroy macblacklist_dns >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/macwhitelist_dns.ipset" ]; then
			ipset destroy macwhitelist_dns >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/lan_blacklist.ipset" ]; then
			ipset destroy lan_blacklist >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/lan_whitelist.ipset" ]; then
			ipset destroy lan_whitelist >/dev/null 2>&1
		fi
		echo "create macblacklist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macblacklist_dns.ipset
		echo "create macwhitelist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macwhitelist_dns.ipset
		if [ "$mnm" != "2" ]; then
			echo "create lan_blacklist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
		else
			echo "create lan_blacklist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
		fi
		echo "create ipblacklist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipblacklist_dns.ipset
		echo "create ipwhitelist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipwhitelist_dns.ipset
		if [ "$list_flag" == "1" ]; then
			if [ -n "$nokpacl_nu" ]; then
				for nokpacl in $nokpacl_nu; do
					echo_date "处理当前第$nokpacl条规则" >> $LOG_FILE
					ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
					macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					[ "$mnm" == "1" ] && echo_date "设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "2" ] && macaddr="" && "设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "3" ] && ipaddr="" && "设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
						echo_date "设备$proxy_name MAC地址为空，不做处理，跳过。" >> $LOG_FILE
						continue
					fi
					if [ "$proxy_mode" == "0" ] && [ "$mnm" != "2" ]; then
						echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					elif [ "$proxy_mode" == "0" ] && [ "$mnm" == "2" ]; then
						echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" == "all" ]; then
						echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" == "all" ]; then
						echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" != "all" ]; then
						echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" != "all" ]; then
						echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
					fi
					#访问自定端口走代理
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "$proxy_name 访问指定端口【$ports】转发进Clash" >> $LOG_FILE
						#iptables -t nat -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						#iptables -t nat -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
					#	iptables -t nat -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
					#	iptables -t nat -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						
						if [ "$tproxymode" == "udp" ]; then
						    iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
						    iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN
							#iptables -t mangle -A PREROUTING -p udp -j merlinclash_PREROUTING
							
						fi
					fi
					# 2 acl in OUTPUT（used by koolproxy）
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					# 3 acl in SHADOWSOCKS for mangle
				done
				if [ "$mnm" != "2" ]; then
					ipset -! flush macblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
					ipset -! flush macwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
				else
					ipset -! flush ipblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
					ipset -! flush ipwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				fi
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
			 #iptables写法		
				iptables -t nat -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
               				
				if [ "$tproxymode" == "udp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				#20201122
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1

			 #2.白名单内再放行
				if [ "$cirswitch" == "1" ]; then
					echo_date "设置白名单进入merlinclash_CHN链" >> $LOG_FILE
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
				#	iptables -t nat -A PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
				#	iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
					if [ "$tproxymode" == "udp" ]; then
					  		iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp  -j merlinclash
					fi
				else
					echo_date "设置白名单进入merlinclash_NOR链" >> $LOG_FILE	
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR	
				#	iptables -t nat -A PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
				#	iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
					if [ "$tproxymode" == "udp" ]; then
					 	     iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp  -j merlinclash
					fi
				fi
			 #3.剩余主机处理
				mndp=$(get merlinclash_nokpacl_default_port)
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 加载ACl规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问全端口通过clash
						#iptables写法
						#大陆白判断
						#echo_date "路由IP：DNS端口为${lan_ipaddr}:${dnslistenport}" >> $LOG_FILE
						if [ "$cirswitch" == "1" ]; then				
							iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
								
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							##iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#不加这句,RERIDHOST部分设备进了黑名单会断网，FAKEIP模式黑名单设备DNS解析错误断网
							#if [ "$tproxymode" == "udp" ]; then
								#iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
								#iptables -t mangle -I merlinclash_PREROUTING -m set --match-set macblacklist_dns src -p udp -j RETURN >/dev/null 2>&1 #20210104
								#iptables -t mangle -I merlinclash_PREROUTING -m set --match-set china_ip_route dst -p udp -j RETURN >/dev/null 2>&1 #20210104
							#fi
						else
							iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
								
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1 #20201215
							#if [ "$tproxymode" == "udp" ]; then
								#iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
								#iptables -t mangle -I merlinclash_PREROUTING -m set --match-set macblacklist_dns src -p udp -j RETURN >/dev/null 2>&1 #20210104
							#fi
						fi
					else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
						echo_date "剩余主机全端口不通过clash，只给通过Clash的设备转发dns端口" >> $LOG_FILE
						#iptables写法
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						#else
						#	iptables -t nat -A PREROUTING -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
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
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							if [ "$tproxymode" == "udp" ]; then
							  		iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							
							fi
						else
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
								
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							if [ "$tproxymode" == "udp" ]; then
							   		iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
								
							fi
						fi
					fi
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
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
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1			
						fi
					else
						iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
					if [ "$tproxymode" == "udp" ]; then
						   iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
						   iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
					fi
				else
					echo_date 加载ACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					# 1 acl in SHADOWSOCKS for nat
					#iptables -t nat -A merlinclash $(factor $ipaddr "-m mac --mac-source") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
												
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						fi
					else
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
						fi
						if [ "$tproxymode" == "udp" ]; then
						 		iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						fi
					fi
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
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
					#ipaddr_hex=$(echo $ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}')
					macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					[ "$mnm" == "1" ] && echo_date "设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "2" ] && macaddr="" && "设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "3" ] && ipaddr="" && "设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
						echo_date "设备$proxy_name MAC地址为空，不做处理，跳过。" >> $LOG_FILE
						continue
					fi
					if [ "$proxy_mode" == "0" ] && [ "$mnm" != "2" ]; then
						echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					elif [ "$proxy_mode" == "0" ] && [ "$mnm" == "2" ]; then
						echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" == "all" ]; then
						echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" == "all" ]; then
						echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" != "all" ]; then
						echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" != "all" ]; then
						echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
					fi
					# 1 acl in SHADOWSOCKS for nat
					#访问自定端口走代理
					echo_date "iptables优先处理访问自定端口走代理设备：$proxy_name" >> $LOG_FILE
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "$proxy_name 访问指定端口【$ports】走代理" >> $LOG_FILE
						#iptables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
						#iptables -t mangle -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash_PREROUTING
						#iptables -t mangle -A PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
					    iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp -j RETURN
						if [ "$ipv6_flag" == "1" ]; then
							#ip6tables -t mangle -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash_PREROUTING
							#ip6tables -t mangle -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
							ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -j merlinclash
						    ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p tcp -j RETURN
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							echo_date "同时开启Tproxy-TCP&UDP转发" >> $LOG_FILE
							#iptables -t mangle -A PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport ! --dport") -j RETURN
							iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
						    iptables -t mangle -A merlinclash_PREROUTING $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN
							
							if [ "$ipv6_flag" == "1" ]; then
								echo_date "同时开启Tproxy-TCP&UDP转发 | 开启IPV6" >> $LOG_FILE
								#ip6tables -t mangle -A PREROUTING $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport ! --dport") -j RETURN
								ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -j merlinclash
								ip6tables -t mangle -A merlinclash_PREROUTING $(factor $macaddr "-m mac --mac-source") -p udp -j RETURN								
							fi
						fi
					fi
					# 2 acl in OUTPUT（used by koolproxy）
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					# 3 acl in SHADOWSOCKS for mangle
				done
				if [ "$mnm" != "2" ]; then
					ipset -! flush macblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
					ipset -! flush macwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
				else
					ipset -! flush ipblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
					ipset -! flush ipwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				fi
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
			 #iptables写法
				echo_date "iptables处理中" >> $LOG_FILE		
				echo_date "黑名单内先过滤" >> $LOG_FILE	
				#iptables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
								
				if [ "$tproxymode" == "udp" ] || [ "$tproxymode" == "tcpudp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
						ip6tables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				if [ "$ipv6_flag" == "1" ]; then
					#ip6tables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
					ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				fi
				#20201122
				if [ "$tproxymode" == "tcpudp" ]; then
					#iptables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
					iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
					if [ "$ipv6_flag" == "1" ]; then
						#ip6tables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
						ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
					fi
				fi
			 #2.白名单内再放行
				echo_date "白名单内再放行" >> $LOG_FILE	
				if [ "$cirswitch" == "1" ]; then
					#iptables -t nat -A PREROUTING -m set --match-set china_ip_route dst -p udp -j ACCEPT >/dev/null 2>&1		
					iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
				
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
					
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
					  		iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp -j merlinclash
					
						if [ "$ipv6_flag" == "1" ]; then
						   	ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp -j merlinclash
						
						fi
					fi
				else
					iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
					
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p tcp -j merlinclash
					
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
					   		iptables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp -j merlinclash
						
						if [ "$ipv6_flag" == "1" ]; then
						    ip6tables -t mangle -A merlinclash_PREROUTING -m set --match-set lan_whitelist src -p udp -j merlinclash
						
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
							#iptables -t mangle -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
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
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
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
							#iptables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
								#ip6tables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
						
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
							  	iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
								#iptables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
								if [ "$ipv6_flag" == "1" ]; then
								   	ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
									#ip6tables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
								fi
							fi
						else
							iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
							#iptables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
								#ip6tables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
							   	iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
								#iptables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
								if [ "$ipv6_flag" == "1" ]; then
								    ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash
									#ip6tables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
								fi
							fi
						fi
					fi
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
			else
				echo_date "未设置设备绕行，采用默认规则：clash全设备通行" >> $LOG_FILE
				merlinclash_nokpacl_default_mode="1"
				dbus set merlinclash_nokpacl_default_mode="1"
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					echo_date 加载ACl规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					#iptables写法
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
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
					# 1 acl in SHADOWSOCKS for nat
					#iptables -t nat -A merlinclash $(factor $ipaddr "-m mac --mac-source") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						#iptables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
							#ip6tables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
						fi
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "tcpudp" ]; then
						    iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
							#iptables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
							if [ "$ipv6_flag" == "1" ]; then
							   	ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
								#ip6tables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
							fi
						fi
					else
						iptables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
						#iptables -t mangle -A merlinclash_PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash_PREROUTING -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
							#ip6tables -t mangle -A PREROUTING -p tcp -j ACCEPT #兜底让流量不进入merlinclash链
						fi
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
						    iptables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
							#iptables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
							if [ "$ipv6_flag" == "1" ]; then
							    ip6tables -t mangle -A merlinclash_PREROUTING -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash
								#ip6tables -t mangle -A PREROUTING -p udp -j ACCEPT #兜底让流量不进入merlinclash链
							fi
						fi
					fi
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
			fi
			dbus remove merlinclash_nokpacl_ip
			dbus remove merlinclash_nokpacl_name
			dbus remove merlinclash_nokpacl_mode
			dbus remove merlinclash_nokpacl_port
		fi
	fi
	if [ ! -z "$kppid" ] && [ "$kpenable" == "1" ];then
			echo_date "当前开启护网大师,使用【仅IP匹配】方案过滤" >> $LOG_FILE
			nokpacl_nu=$(get_list merlinclash_nokpacl_ip 1 4)
			#20201215黑名单内设备IP DNS不走转发。
			if [ -f "/jffs/softcenter/res/ipblacklist_dns.ipset" ]; then
				ipset destroy ipblacklist_dns >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/ipwhitelist_dns.ipset" ]; then
				ipset destroy ipwhitelist_dns >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/lan_blacklist.ipset" ]; then
				ipset destroy lan_blacklist >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/lan_whitelist.ipset" ]; then
				ipset destroy lan_whitelist >/dev/null 2>&1
			fi
			echo "create ipblacklist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipblacklist_dns.ipset
			echo "create ipwhitelist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipwhitelist_dns.ipset
			echo "create lan_blacklist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
			if [ -n "$nokpacl_nu" ]; then
				for nokpacl in $nokpacl_nu; do
					echo_date "处理第$nokpacl条规则" >> $LOG_FILE
					ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
					ipaddr_hex=$(echo $ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}')
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl)
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					echo_date "设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$proxy_mode" == "0" ]; then
						echo_date "$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if [ "$proxy_mode" == "1" ] && [ "$ports" == "all" ]; then
						echo_date "$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "all" ]; then
						echo_date "$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
						echo_date 加载KoolProxyACL规则：【$proxy_name】【全部端口】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
					else
						echo_date 加载KoolProxyACL规则：【$proxy_name】【$ports】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
					fi
					# 1 acl in SHADOWSOCKS for nat
					#访问自定端口走代理
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "$proxy_name 访问指定端口【$ports】转发进Clash" >> $LOG_FILE
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						# 2 acl in OUTPUT（used by koolproxy）
						iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					fi
				done
				ipset -! flush ipblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
				ipset -! flush ipwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
				#iptables写法		
				iptables -t nat -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
								
				if [ "$tproxymode" == "udp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				#2.白名单内再放行
				if [ "$cirswitch" == "1" ]; then		
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
				else
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR	
				fi
				#剩余主机处理
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 加载KoolProxyACL规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then				
							iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1 #20201215 不加这句，部分设备会无法联网
						else
							iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
						#iptables写法
						if [ "$dnshijacksel" == "front" ]; then				
							iptables -t nat -I PREROUTING -m set --match-set ipwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
						fi
						
					fi
				else
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 加载KoolProxyACL规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN		
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						else
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							fi
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
			else
				echo_date "未设置设备绕行，采用默认规则：clash全设备通行" >> $LOG_FILE
				merlinclash_nokpacl_default_mode="1"
				dbus set merlinclash_nokpacl_default_mode="1"
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					echo_date 加载KoolProxyACL规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					else
						iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
				else
					echo_date 加载KoolProxyACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					# 1 acl in SHADOWSOCKS for nat
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport ! --dport") -j RETURN
					
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					# 2 acl in OUTPUT（used by koolproxy）
					iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					else
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi		
				fi
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
			fi
			dbus remove merlinclash_nokpacl_ip
			dbus remove merlinclash_nokpacl_name
			dbus remove merlinclash_nokpacl_mode
			dbus remove merlinclash_nokpacl_port
	fi
	dbus remove merlinclash_device_ip
	dbus remove merlinclash_device_name
	dbus remove merlinclash_device_mode
	dbus remove merlinclash_whitelist_ip
	dbus remove merlinclash_ipport_ip
	dbus remove merlinclash_ipport_name
	dbus remove merlinclash_ipport_port
	echo_date ---------------------- 设备管理检查区 结束 ------------------------ >> $LOG_FILE
}
#20200816复用为自定义host
start_host(){
	
	#用yq处理router.asus.com的值 修改router.asus.com ip地址为当前路由lanip
	echo_date "当前选中host文件为：$hostsel.yaml" >> $LOG_FILE
# 	router_tmp=$(yq r /jffs/softcenter/merlinclash/yaml_basic/host/$hostsel.yaml hosts.[router.asus.com])
# 	echo_date "router.asus.com值:$router_tmp" >> $LOG_FILE
# 	if [ -n "$router_tmp" ] && [ "$router_tmp" != "$lan_ipaddr" ]; then
# 		echo_date "修正router.asus.com值为路由LANIP" >> $LOG_FILE
# 		yq w -i $hostsyaml "hosts.[router.asus.com]" $lan_ipaddr
# 	fi
	rm -rf /tmp/upload/$hostsel.txt
	[ ! -L "/tmp/upload/$hostsel.txt" ] && ln -sf $hostsyaml /tmp/upload/$hostsel.txt

	sed -i '$a' $yamlpath
	cat $hostsyaml >> $yamlpath

	echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo_date "             +               hosts处理完毕           +" >> $LOG_FILE
    echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
}
#
start_routingmark(){
	sed -i '$a' $yamlpath
	cat /jffs/softcenter/merlinclash/yaml_basic/routingmark.yaml >> $yamlpath
}
start_remark(){
	if [ "${coremark}" == "1" ]; then
      echo_date "使用Clash内核内置代理组状态恢复" >> $LOG_FILE
    else
	  /bin/sh /jffs/softcenter/scripts/clash_node_mark.sh remark
    fi
    echo_date "推送Clash运行模式: $merlinclash_clashmode"
	/bin/sh /jffs/softcenter/scripts/clash_patchmode.sh >/dev/null 2>&1
}

start_kcp(){
	# kcp_nu 获取已存数据序号

	kcp_nu=$(get_list merlinclash_kcp_lport 1 4)
	kcpnum=0
	kcpswitch=$(get merlinclash_kcpswitch)
	if [ -n "$kcp_nu" ] && [ "$kcpswitch" == "1" ]; then
		echo_date "检查到KCP开启且有KCP配置，将启动KCP加速" >> $LOG_FILE
		for kcp in $kcp_nu; do
			lport=$(eval echo \$merlinclash_kcp_lport_$kcp)
			server=$(eval echo \$merlinclash_kcp_server_$kcp)
			port=$(eval echo \$merlinclash_kcp_port_$kcp)
			param=$(eval echo \$merlinclash_kcp_param_$kcp)
			#根据传入值启动kcp进程
			kcpnum1=$(($kcpnum+1))
			echo_date "启动第$kcpnum1个kcp进程" >> $LOG_FILE
			/jffs/softcenter/bin/client_linux -l :$lport -r $server:$port $param >/dev/null 2>&1 &
			local kcppid
			kcppid=$(pidof client_linux)
			if [ -n "$kcppid" ];then
				echo_date "kcp进程启动成功，pid:$kcppid! "
			else
				echo_date "kcp进程启动失败！"
			fi
			let kcpnum++
		done
	else
		echo_date "没有打开KCP开关或者不存在KCP设置，不启动KCP加速" >> $LOG_FILE
		kcp_process=$(pidof client_linux)
		if [ -n "$kcp_process" ]; then
			echo_date "关闭残留KCP协议进程"... >> $LOG_FILE
			killall client_linux >/dev/null 2>&1
		fi	
	fi
	dbus remove merlinclash_kcp_lport
	dbus remove merlinclash_kcp_server
	dbus remove merlinclash_kcp_port
	dbus remove merlinclash_kcp_param	
}
set_sys() {
	# set_ulimit
	ulimit -n 16384
	echo 1 >/proc/sys/vm/overcommit_memory

	# more entropy
	# use command `cat /proc/sys/kernel/random/entropy_avail` to check current entropy
	#echo_date "启动haveged，为系统提供更多的可用熵！"
	#if [ -z $(which jitterentropy-rngd) -a -f "/jffs/softcenter/bin/haveged_c" ]; then
#	if [ -z "$(pidof jitterentropy-rngd)" -a -z "$(pidof haveged)" -a -f "/jffs/softcenter/bin/haveged_c" ];then
#		echo_date "启动haveged，为系统提供更多的可用熵！"
#		haveged_c -w 1024 >/dev/null 2>&1	
#	fi	
}
creat_ipset() {
	#20201121 创建直连名单
	xt=`lsmod | grep xt_set`
	OS=$(uname -r)
	if [ -z "$xt" ] && [ -f "/lib/modules/${OS}/kernel/net/netfilter/xt_set.ko" ];then
		echo_date "加载xt_set.ko内核模块！"
		modprobe xt_set
	fi
	if [ -z "`lsmod | grep ip_set_bitmap_port`" ] && [ -f "/lib/modules/${OS}/kernel/net/netfilter/ipset/ip_set_bitmap_port.ko" ];then
		echo_date "加载ip_set_bitmap_port.ko内核模块！"
		modprobe ip_set_bitmap_port
	fi
	[ -n "$IFIP_DNS1" ] && ISP_DNS_a="$ISP_DNS1" || ISP_DNS_a=""
	[ -n "$IFIP_DNS2" ] && ISP_DNS_b="$ISP_DNS2" || ISP_DNS_a=""
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
	fi
	#
	echo_date "创建clash相关ipset规则集" >> $LOG_FILE
	ipset -! create router nethash
	ipset -! create ipset_proxy nethash
	ipset -! create ipset_proxy6 hash:net family inet6
	ipset -! create ipset_proxyarround nethash
	ipset -! create ipset_proxyarround6 hash:net family inet6
	#ipset -! creat white_kp_list nethash
	echo_date "创建koolproxy所需ipset规则集" >> $LOG_FILE
	ipset -! create white_koolproxy nethash
	ipset -! create black_koolproxy iphash
	#ipset：kp_full_port
	cat /jffs/softcenter/merlinclash/koolproxy/data/rules/koolproxy.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/daily.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/user.txt | grep -Eo "(.\w+\:[1-9][0-9]{1,4})/" | grep -Eo "([0-9]{1,5})" | sort -un | sed -e '$a\80' -e '$a\443' | sed -e "s/^/-A kp_full_port &/g" -e "1 i\-N kp_full_port bitmap:port range 0-65535 " | ipset -R -!
	ipset -A black_koolproxy 110.110.110.110 >/dev/null 2>&1
	#
	#ipset -! create kp_port_http bitmap:port range 0-65535
	#ipset -! create kp_port_https bitmap:port range 0-65535
	#ports=`cat /jffs/softcenter/merlinclash/koolproxy/data/rules/koolproxy.txt | grep -Eo "(.\w+\:[1-9][0-9]{1,4})/" | grep -Eo "([0-9]{1,5})" | sort -un`
	#for port in $ports 80
	#do
	#	ipset -A kp_port_http $port >/dev/null 2>&1
	#	ipset -A kp_port_https $port >/dev/null 2>&1
	#done
	cat /jffs/softcenter/merlinclash/koolproxy/data/rules/koolproxy.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/daily.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/user.txt | grep -Eo "(.\w+\:[1-9][0-9]{1,4})/" | grep -Eo "([0-9]{1,5})" | sort -un | sed -e '$a\80' | sed -e "s/^/-A kp_port_http &/g" -e "1 i\-N kp_port_http bitmap:port range 0-65535 " | ipset -R -!
	cat /jffs/softcenter/merlinclash/koolproxy/data/rules/koolproxy.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/daily.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/user.txt | grep -Eo "(.\w+\:[1-9][0-9]{1,4})/" | grep -Eo "([0-9]{1,5})" | sort -un | sed -e '$a\80' | sed -e "s/^/-A kp_port_https &/g" -e "1 i\-N kp_port_https bitmap:port range 0-65535 " | ipset -R -!
	ipset -A kp_port_https 443 >/dev/null 2>&1
	#
	#echo_date "创建网易云音乐解锁所需ipest规则集" >> $LOG_FILE
	#if [ -n "`ipset -L -n|grep music`" ]; then
		#echo_date "已存在网易云解锁ipset规则" >> $LOG_FILE
	#else
		#ipset -! -N music hash:ip
		#ipset add music 59.111.181.60 
		#ipset add music 59.111.181.38 
		#ipset add music 59.111.181.35 
		#ipset add music 59.111.160.195
		#ipset add music 223.252.199.66
		#ipset add music 59.111.160.197
		#ipset add music 223.252.199.67
		#ipset add music 115.236.121.1
		#ipset add music 115.236.121.3
		#ipset add music 115.236.118.33
		#ipset add music 39.105.63.80
		#ipset add music 118.24.63.156
		#ipset add music 193.112.159.225
		#ipset add music 47.100.127.239
		#20200712++++
		#ipset add music 112.13.122.1
		#ipset add music 112.13.119.17
		#ipset add music 103.126.92.133
		#ipset add music 103.126.92.132
		#ipset add music 101.71.154.241
		#ipset add music 59.111.238.29
		#ipset add music 59.111.179.214
		#ipset add music 59.111.21.14
		#ipset add music 45.254.48.1
		#ipset add music 42.186.120.199
	#fi
	#
	echo_date "创建大陆IP绕行ipset规则集" >> $LOG_FILE
	if [ ! -f "/jffs/softcenter/res/china_ip_route.ipset" ]; then
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
		echo_date "创建大陆IP绕行ipv6-ipset规则集" >> $LOG_FILE
		if [ ! -f "/jffs/softcenter/res/china_ip_route6.ipset" ]; then
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
}
pre_netflix_nslookup(){
	#预解析奈非和DISNEY+
	netflix_flag=$(get merlinclash_prenetflix)
	if [ "$netflix_flag" == "1" ]; then
		NETFLIX_DOMAINS_LIST="/jffs/softcenter/res/Netflix_Domains.list"
		NETFLIX_DOMAINS_CUSTOM_LIST="/jffs/softcenter/res/Netflix_Domains_Custom.list"
		DISNEYPLUS_DOMAINS_LIST="/jffs/softcenter/res/DisneyPlus_Domains.list"
		if [ "$1" != "back" ]; then
			echo_date "启用预解析奈飞及迪士尼+..." >> $LOG_FILE
		fi
		#cat "$NETFLIX_DOMAINS_LIST" |while read -r line0
		lines0=$(cat "$NETFLIX_DOMAINS_LIST" | awk '{print $0}')
		for line0 in $lines0
		do
			[ -n "$line0" ] && nslookup $line0 127.0.0.1:${dnslistenport}
		done >/dev/null 2>&1 &
		#cat "$NETFLIX_DOMAINS_CUSTOM_LIST" |while read -r line1
		lines1=$(cat "$NETFLIX_DOMAINS_CUSTOM_LIST" | awk '{print $0}')
		for line1 in $lines1
		do
			[ -n "$line1" ] && nslookup $line1 127.0.0.1:${dnslistenport}
		done >/dev/null 2>&1 &
		#cat "$DISNEYPLUS_DOMAINS_LIST" |while read -r line2
		lines2=$(cat "$DISNEYPLUS_DOMAINS_LIST" | awk '{print $0}')
		for line2 in $lines2
		do
			[ -n "$line2" ] && nslookup $line2 127.0.0.1:${dnslistenport}
		done >/dev/null 2>&1 &
		if [ "$1" != "back" ]; then
			echo_date "后台预解析奈飞及迪士尼+中，大约需时2分钟。" >> $LOG_FILE
		fi
	fi
	if [ "$1" != "back" ]; then
		mcprenetflix=$(get merlinclash_prenetflix)
		mcprenetflixdtime_enable=$(get merlinclash_prenetflix_delay_time_enable)
		mcprenetflix_dtime=$(get merlinclash_prenetflix_delay_time)
		if [ "$mcenable" == "1" ] && [ "$mcprenetflix" == "1" ] && [ "$mcprenetflixdtime_enable" == "1" ];then
			sed -i '/clash_prenetflix/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
			pretime=$mcprenetflix_dtime
			cru a clash_prenetflix */$pretime" * * * * /bin/sh /jffs/softcenter/merlinclash/clashconfig.sh prenetflix"
		fi
	fi
}

creat_router_ipset(){
	rm -rf /tmp/clash_router.txt
	rm -rf /jffs/softcenter/merlinclash/conf/clash_router_ipset.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/clash_router_ipset.conf >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxyarround.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/ipsetproxyarround.conf >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/conf/ipsetproxy.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/ipsetproxy.conf >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/conf/kpipset.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/kpipset.conf >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/conf/kpipsetarround.conf >/dev/null 2>&1
	rm -rf /tmp/etc/dnsmasq.user/kpipsetarround.conf >/dev/null 2>&1

	jdqd=$(get jdqd_jd_enable)
	if [ "$jdqd" == "1" ]; then
		ipset add router 149.154.160.0/20 #检测到京东签到，写入TG IP段，使得TGBOT能用
	fi
	echo_date "开始创建强制转发到Clash的ipset规则集" >> $LOG_FILE
	sh /jffs/softcenter/scripts/clash_ipsetproxychange.sh ip ip
	echo_date " " >> $LOG_FILE
	echo_date "开始创建强制绕行Clash的ipset规则集" >> $LOG_FILE
	sh /jffs/softcenter/scripts/clash_ipsetproxyarroundchange.sh ip ip
	echo_date " " >> $LOG_FILE
	echo_date "开始创建KP自定义过滤规则集" >> $LOG_FILE
	sh /jffs/softcenter/scripts/clash_ipsetproxychange.sh kp kp
	echo_date " " >> $LOG_FILE
	echo_date "开始创建KP自定义绕行规则集" >> $LOG_FILE
	sh /jffs/softcenter/scripts/clash_ipsetproxyarroundchange.sh kp kp
	echo_date " " >> $LOG_FILE
	dgc=$(/jffs/softcenter/bin/clash -v | awk -F"go" '{print $2}'| awk -F" " '{print $1}')
	if [ "$dgc" -lt "1.18" ]; then
		echo_date "clash二进制版本过低，不符合路由自身代理访问要求，请更新Clash二进制至最新" >> $LOG_FILE
		dbus set merlinclash_dnsgoclash="0"
		dnsgoclash=$(get merlinclash_dnsgoclash)
	else
		echo_date "Clash二进制版本符合路由自身代理访问要求" >> $LOG_FILE
	fi
	#if [ "$dnsgoclash" == "1" ]; then
	#	echo_date "开始创建路由经代理访问ipset规则集"
	#	sh /jffs/softcenter/scripts/clash_routerrule.sh apply apply
	#fi
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
	if [ "$iptsel" == "fangan1" ]; then
		echo_date "IPTABLES执行方案一" >> $LOG_FILE
		apply_nat_rules3
	else
		echo_date "IPTABLES执行方案二" >> $LOG_FILE
		apply_nat_rules4
	fi
	#chromecast
}
add_white_black_ip() {
    echo_date '应用局域网 IP 白名单'
    ip_lan="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 $lan_ipaddr"
    for ip in $ip_lan; do
        ipset -! add merlinclash_white $ip >/dev/null 2>&1
    done
}
load_tproxy() {
	#MODULES="nf_tproxy_core xt_TPROXY xt_socket xt_comment"
	MODULES="nf_tproxy_core xt_TPROXY"
	OS=$(uname -r)
	# load Kernel Modules
	echo_date 加载Tproxy模块，用于UDP转发... >> $LOG_FILE
	checkmoduleisloaded() {
		if lsmod | grep $MODULE &>/dev/null; then return 0; else return 1; fi
	}

	for MODULE in $MODULES; do
		if ! checkmoduleisloaded; then
			#insmod /lib/modules/${OS}/kernel/net/netfilter/${MODULE}.ko
			#只有官改需要加载nf_tproxy_core,swrt不需要
			if [  "${LINUX_VER}" -eq "419" -o "${LINUX_VER}" -eq "54" ];then
				modprobe ${MODULE}.ko
			else
				insmod /lib/modules/${OS}/kernel/net/netfilter/${MODULE}.ko
			fi
		fi
	done

#	modules_loaded=0

#	for MODULE in $MODULES; do
#		if checkmoduleisloaded; then
#			modules_loaded=$((j++))
#		fi
#	done

	#if [ "$modules_loaded" -ne "2" ]; then
	#	echo "One or more modules are missing, only $((modules_loaded + 1)) are loaded. Can't start." >> $LOG_FILE
	#	close_in_five
	#fi
}
apply_nat_rules3() {
	#KOOLPROXY&UnbockNeteaseMusic兼容
	KP_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | head -n1)
	CL_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/cloud_music/=' | head -n1)
	
	
	if [ "$CL_NU" != "" ]; then
		INSET_NU=$(expr "$CL_NU" + 1)
	else
		if [ "$KP_NU" == "" ]; then
			KP_NU=0
		fi
		INSET_NU=$(expr "$KP_NU" + 1)
	fi

	dem2=$(cat $yamlpath | grep "enhanced-mode:" | awk -F "[: ]" '{print $5}')
	echo_date "开始写入iptable规则" >> $LOG_FILE
	tproxymode=$(get merlinclash_tproxymode)

    if [ "$merlinclash_googlehomeswitch" == "1" ]; then
		iptables -I PREROUTING -t nat -p udp -d 8.8.4.4 --dport 53 -j REDIRECT --to-port 53
		iptables -I PREROUTING -t nat -p udp -d 8.8.8.8 --dport 53 -j REDIRECT --to-port 53
	fi

	if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
		echo_date "当前为Redir-TCP透明代理模式" >> $LOG_FILE
		# ports redirect for clash except port 22 for ssh connection
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
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
			echo_date "检测到UDP转发开启，将创建相关iptable规则" >> $LOG_FILE
			# udp
			load_tproxy
			# 设置策略路由
			#modprobe xt_TPROXY
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
			#iptables -t mangle -N merlinclash
			#echo_date "创建【mangle】表【merlinclash】链" >> $LOG_FILE
			#iptables -t mangle -F merlinclash

			#iptables -t mangle -A merlinclash -j CONNMARK --restore-mark
			#iptables -t mangle -A merlinclash -m mark --mark 0x2333 -j RETURN
			#[ -n "$ISP_DNS1" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS1 --dport 53 -j RETURN
			#[ -n "$ISP_DNS2" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS2 --dport 53 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
			iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
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
			#iptables -t nat -A OUTPUT -p tcp -m set --match-set router dst -j merlinclash
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT		
				
		fi
		

		iptables -t nat -A PREROUTING -p tcp -j merlinclash
		
	
	elif [ "$tproxymode" == "tcpudp" ]; then 
		echo_date "当前为Tproxy【TCP&UDP】透明代理模式" >> $LOG_FILE
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "开启IPv6模式" >> $LOG_FILE
		fi
		#SSH端口
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		#iptables -t mangle -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		# ipv4设置策略路由
		load_tproxy
		#modprobe xt_TPROXY

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
		#iptables -t mangle -N merlinclash
		#echo_date "创建【mangle】表【merlinclash】链" >> $LOG_FILE
		#iptables -t mangle -F merlinclash
		
		#iptables -t mangle -A merlinclash -j CONNMARK --restore-mark
		#iptables -t mangle -A merlinclash -m mark --mark 0x2333 -j RETURN
		#[ -n "$ISP_DNS1" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS1 --dport 53 -j RETURN
		#[ -n "$ISP_DNS2" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS2 --dport 53 -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
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
		#iptables -t mangle -A merlinclash -p tcp --syn -j MARK --set-mark 0x2333
		#iptables -t mangle -A merlinclash -p udp -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
		#iptables -t mangle -A merlinclash -j CONNMARK --save-mark

		#iptables -t mangle -A merlinclash_PREROUTING -i lo -m mark ! --mark 0x2333 -j RETURN

		#iptables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p tcp -j merlinclash
		#iptables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p udp -j merlinclash

		#iptables -t mangle -A merlinclash_PREROUTING -p tcp -j merlinclash
		#iptables -t mangle -A merlinclash_PREROUTING -p udp -j merlinclash
											
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
			#ip6tables -t mangle -N merlinclash
			#echo_date "创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			#ip6tables -t mangle -F merlinclash
			
			#ip6tables -t mangle -A merlinclash -j CONNMARK --restore-mark
			#ip6tables -t mangle -A merlinclash -m mark --mark 0x2333 -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
			#[ -n "$ISP6_DNS1" ] && ip6tables -t mangle -A merlinclash -p udp -d $ISP6_DNS1 --dport 53 -j RETURN
			#[ -n "$ISP6_DNS2" ] && ip6tables -t mangle -A merlinclash -p udp -d $ISP6_DNS2 --dport 53 -j RETURN
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

			#echo_date "创建【ipv6-mangle】表【merlinclash】链规则" >> $LOG_FILE
			#ip6tables -t mangle -A merlinclash -p tcp --syn -j MARK --set-mark 0x2333
			#ip6tables -t mangle -A merlinclash -p udp -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
			#ip6tables -t mangle -A merlinclash -j CONNMARK --save-mark

			#ip6tables -t mangle -A merlinclash_PREROUTING -i lo -m mark ! --mark 0x2333 -j RETURN

			#ip6tables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p tcp -j merlinclash
			#ip6tables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p udp -j merlinclash

			#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
            #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333					
			
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
		#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
		
		if [ "$dnsgoclash" == "1" ]; then
			ip -4 rule add fwmark 0x1111         table 233
			iptables -t nat -N merlinclash_OUTPUT
			iptables -t nat -A merlinclash_OUTPUT -p tcp -m set --match-set direct_list dst -j RETURN
            iptables -t nat -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			iptables -t nat -A merlinclash_OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT
			#iptables -t mangle -I OUTPUT -p tcp -m set --match-set router dst -j MARK --set-mark 0x2333
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
		echo_date "当前为Tproxy【TCP】透明代理模式" >> $LOG_FILE
		echo_date "DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "开启IPv6模式" >> $LOG_FILE
		fi
		#SSH端口
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		#iptables -t mangle -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		# 设置策略路由
		load_tproxy
		#modprobe xt_TPROXY	
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
		#iptables -t mangle -N merlinclash
		#echo_date "创建【mangle】表【merlinclash】链" >> $LOG_FILE
		#iptables -t mangle -F merlinclash

		#iptables -t mangle -A merlinclash -j CONNMARK --restore-mark
		#iptables -t mangle -A merlinclash -m mark --mark 0x2333 -j RETURN
		#[ -n "$ISP_DNS1" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS1 --dport 53 -j RETURN
		#[ -n "$ISP_DNS2" ] && iptables -t mangle -A merlinclash -p udp -d $ISP_DNS2 --dport 53 -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
		iptables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
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
		#iptables -t mangle -A merlinclash -p tcp --syn -j MARK --set-mark 0x2333
		#iptables -t mangle -A merlinclash -j CONNMARK --save-mark

		#iptables -t mangle -A merlinclash_PREROUTING -i lo -m mark ! --mark 0x2333 -j RETURN

		#iptables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p tcp -j merlinclash

		#if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
			# fake-ip rules
		#	iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
		#fi
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
			#ip6tables -t mangle -N merlinclash
			#echo_date "创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			#ip6tables -t mangle -F merlinclash
			
			#ip6tables -t mangle -A merlinclash -j CONNMARK --restore-mark
			#ip6tables -t mangle -A merlinclash -m mark --mark 0x2333 -j RETURN
			#[ -n "$ISP6_DNS1" ] && ip6tables -t mangle -A merlinclash -p udp -d $ISP6_DNS1 --dport 53 -j RETURN
			#[ -n "$ISP6_DNS2" ] && ip6tables -t mangle -A merlinclash -p udp -d $ISP6_DNS2 --dport 53 -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -i br1 -j RETURN
			ip6tables -t mangle -A merlinclash_PREROUTING -i br2 -j RETURN
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
			#ip6tables -t mangle -A merlinclash -p tcp --syn -j MARK --set-mark 0x2333
			#ip6tables -t mangle -A merlinclash -j CONNMARK --save-mark

			#ip6tables -t mangle -A merlinclash_PREROUTING -i lo -m mark ! --mark 0x2333 -j RETURN

			#ip6tables -t mangle -A merlinclash_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p tcp -j merlinclash
						
			#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
            #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333							
			#ip6tables -t mangle -I PREROUTING -m addrtype ! --src-type LOCAL --dst-type LOCAL -p udp --dport 53 -j TPROXY --on-ip ::1 --on-port "${dnslistenport}" --tproxy-mark 0x2333
			#ip6tables -t mangle -I PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p udp --dport 53 -j TPROXY --on-ip ::1 --on-port "${dnslistenport}" --tproxy-mark 0x2333
			#if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
				# fake-ip rules
			#	iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
			#fi
			lan_bypass
			
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_divert
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash_PREROUTING
		
			#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN

		fi
		#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
		
		if [ "$dnsgoclash" == "1" ]; then
			ip -4 rule add fwmark 0x1111         table 233
			iptables -t nat -N merlinclash_OUTPUT
			iptables -t nat -A merlinclash_OUTPUT -p tcp -m set --match-set direct_list dst -j RETURN
            iptables -t nat -A merlinclash_OUTPUT -m mark --mark $mcrm -j RETURN
			iptables -t nat -A merlinclash_OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
			iptables -t nat -I OUTPUT -j merlinclash_OUTPUT
			#iptables -t mangle -I OUTPUT -p tcp -m set --match-set router dst -j MARK --set-mark 0x2333
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

	# 控制面板的端口转发
	if [ "$merlinclash_dashboardswitch" == "1" ]; then
		echo_date "检测到控制面板公网访问开关开启" >> $LOG_FILE
		open_port
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
		echo_date "检测到路由IPv6开启，但未开启Tproxy代理，仅开启TPv6劫持解析" >> $SIMLOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
		#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
        #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
	fi
	if [ "${LINUX_VER}" -lt "41" ] && [ $(ipv6_mode) == "true" ]; then
		load_tproxy
		echo_date "检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $LOG_FILE
		echo_date "检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $SIMLOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
		#ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
	fi
	if [ "$dnsplan" == "fi" ]; then
		#ip6tables -t mangle -D PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
        #ip6tables -t mangle -D OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m set --match-set lan_blacklist src -j DROP #阻断黑名单设备ipv6dns查询
		#iptables -t nat -I PREROUTING 3 -p udp --dport 53 -m set --match-set lan_blacklist src -j DNAT --to ${dfib}
	
	fi
	echo_date "iptable规则创建完成" >> $LOG_FILE
}
apply_nat_rules4() {
	#KOOLPROXY&UnbockNeteaseMusic兼容
	KP_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | head -n1)
	CL_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/cloud_music/=' | head -n1)
	
	
	if [ "$CL_NU" != "" ]; then
		INSET_NU=$(expr "$CL_NU" + 1)
	else
		if [ "$KP_NU" == "" ]; then
			KP_NU=0
		fi
		INSET_NU=$(expr "$KP_NU" + 1)
	fi

	dem2=$(cat $yamlpath | grep "enhanced-mode:" | awk -F "[: ]" '{print $5}')
	echo_date "【方案二】开始写入iptable规则" >> $LOG_FILE
	tproxymode=$(get merlinclash_tproxymode)

    if [ "$merlinclash_googlehomeswitch" == "1" ]; then
		iptables -I PREROUTING -t nat -p udp -d 8.8.4.4 --dport 53 -j REDIRECT --to-port 53
		iptables -I PREROUTING -t nat -p udp -d 8.8.8.8 --dport 53 -j REDIRECT --to-port 53
	fi

	if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
		echo_date "【方案二】当前为Redir-TCP透明代理模式" >> $LOG_FILE
		# ports redirect for clash except port 22 for ssh connection
		echo_date "【方案二】DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "【方案二】Lan_ip是$lan_ipaddr" >> $LOG_FILE
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		
		iptables -t nat -N merlinclash
		echo_date "【方案二】创建【nat】表【merlinclash】链" >> $LOG_FILE	
		iptables -t nat -N merlinclash_EXT
		echo_date "【方案二】创建【nat】表【merlinclash_EXT】链" >> $LOG_FILE
		#ip集强制绕过
		iptables -t nat -A merlinclash -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t nat -A merlinclash -p tcp -m set --match-set direct_list dst -j RETURN
		iptables -t nat -A merlinclash_EXT -p tcp -m set --match-set direct_list dst -j RETURN
		# 创建redirhost常规模式nat rule
		
		iptables -t nat -N merlinclash_NOR
		echo_date "【方案二】创建【nat】表【merlinclash_NOR】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t nat -A merlinclash_NOR -p tcp -m set --match-set ipset_proxy dst -j REDIRECT --to-ports $proxy_port
		iptables -t nat -A merlinclash_NOR -p tcp -j REDIRECT --to-ports $proxy_port
		# 创建redirhost大陆白名单模式nat rule
		
		iptables -t nat -N merlinclash_CHN
		echo_date "【方案二】创建【nat】表【merlinclash_CHN】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t nat -A merlinclash_CHN -p tcp -m set --match-set ipset_proxy dst -j REDIRECT --to-ports $proxy_port
		iptables -t nat -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route dst -j REDIRECT --to-ports $proxy_port
		
		if [ "$tproxymode" == "udp" ]; then
				echo_date "【方案二】检测到开启UDP转发，将创建相关iptable规则" >> $LOG_FILE
			# udp
			#load_tproxy
			# 设置策略路由
			modprobe xt_TPROXY
			ip rule add fwmark 1 lookup 100
			ip route add local default dev lo table 100
			iptables -t mangle -N merlinclash
			echo_date "【方案二】创建【mangle】表【merlinclash】链" >> $LOG_FILE
			iptables -t mangle -F merlinclash
			#ip集强制代理
			iptables -t mangle -A merlinclash -p udp -m set --match-set ipset_proxy dst -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
			#ip集强制绕过
			iptables -t mangle -A PREROUTING -p udp -m set --match-set ipset_proxyarround dst -j RETURN
			#绕过内网
			iptables -t mangle -A PREROUTING -p udp -m set --match-set direct_list dst -j RETURN
		
			#
			iptables -t mangle -N merlinclash_NOR
			echo_date "【方案二】创建【mangle】表【merlinclash_NOR】链" >> $LOG_FILE
			iptables -t mangle -A merlinclash_NOR -p udp -j TPROXY --on-port "$proxy_port" --tproxy-mark 0x01/0x01
			
			iptables -t mangle -N merlinclash_CHN
			echo_date "【方案二】创建【mangle】表【merlinclash_CHN】链" >> $LOG_FILE
			iptables -t mangle -A merlinclash_CHN -p udp -m set ! --match-set china_ip_route dst -j TPROXY --on-port "$proxy_port" --tproxy-mark 0x01/0x01											
			
			if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
				# fake-ip rules
				iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
			fi				
		else
			echo_date "【方案二】【检测到UDP转发未开启，进行下一步】" >> $LOG_FILE
		fi
		lan_bypass4

		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$ip_prefix_hex" -j merlinclash_EXT
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$opvpn_prefix_hex" -j merlinclash_EXT #OPENVPN回城兼容
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$pptpvpn_prefix_hex" -j merlinclash_EXT #PPTPVPN回城兼容
		iptables -t nat -A OUTPUT -p tcp -m mark --mark "$ipsec_prefix_hex" -j merlinclash_EXT #PPTPVPN回城兼容
		iptables -t nat -A merlinclash_EXT -p tcp -j merlinclash
		iptables -t mangle -A PREROUTING -p udp -j merlinclash
			
		if [ "$dnsplan" != "fi" ]; then
			#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
			if [ "$dnsgoclash" == "1" ]; then
				#OUTPUT dns default-nameserver不经过clash避免回环
				dednss=$(yq r $yamlpath "dns.default-nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss" ]; then
					for dedns in $dednss; do
						iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
					done
				fi
				dednss2=$(yq r $yamlpath "dns.nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss2" ]; then
					for dedns in $dednss2; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				dednss3=$(yq r $yamlpath "dns.fallback" | awk -F " " '{print $2}')
				if [ -n "$dednss3" ]; then
					for dedns in $dednss3; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				#iptables -t nat -A OUTPUT -p tcp -d 198.18.0.0/16 -j REDIRECT --to-port "$proxy_port"
				iptables -t nat -A OUTPUT  -p udp --dport 53 -j REDIRECT --to-port 53
				#iptables -t nat -A OUTPUT -p tcp -m set --match-set router dst -j merlinclash
				#转发路由器自身tcp流量，clash出站流量打了mark不转发，避免回环
				iptables -t nat -I OUTPUT -p tcp -j merlinclash
				iptables -t nat -I OUTPUT -m mark --mark $mcrm -j ACCEPT
			fi
		fi
		PLAN_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/p_lan_bypass/=' | head -n1)
		if [ "$PLAN_NU" != "" ]; then
			INSET_NU=$(expr "$PLAN_NU" + 1)
		fi
		if [ "$p_lan_bypass_flag" == "0" ]; then
			iptables -t nat -A PREROUTING -p tcp -j merlinclash
			
		else
			iptables -t nat -A PREROUTING -p tcp -m set ! --match-set p_lan_bypass src -j merlinclash
		
		fi
	
	elif [ "$tproxymode" == "tcpudp" ]; then 
		echo_date "【方案二】当前为Tproxy【TCP&UDP】透明代理模式" >> $LOG_FILE
		echo_date "【方案二】DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "【方案二】Lan_ip是$lan_ipaddr" >> $LOG_FILE
		#SSH端口
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		#iptables -t mangle -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		# 设置策略路由
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "【方案二】开启IPv6模式" >> $LOG_FILE
		fi
		load_tproxy
		#modprobe xt_TPROXY	
		ip -4 rule add fwmark 1 lookup 100
		ip -4 route add local default dev lo table 100
		iptables -t mangle -N merlinclash
		echo_date "【方案二】创建【mangle】表【merlinclash】链" >> $LOG_FILE
		iptables -t mangle -F merlinclash
		#ip集强制代理
		iptables -t mangle -A merlinclash -p tcp -m set --match-set ipset_proxy dst --syn -j MARK --set-mark 0x2333
		iptables -t mangle -A merlinclash -p udp -m set --match-set ipset_proxy dst -m conntrack --ctstate NEW -j MARK --set-mark 0x2333
		#ip集强制绕过
		iptables -t mangle -A PREROUTING -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		iptables -t mangle -A PREROUTING -p udp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t mangle -A PREROUTING -p tcp -m set --match-set direct_list dst -j RETURN
		iptables -t mangle -A PREROUTING -p udp -m set --match-set direct_list dst -j RETURN
		#
		iptables -t mangle -N merlinclash_NOR
		echo_date "【方案二】创建【mangle】表【merlinclash_NOR】链" >> $LOG_FILE
		iptables -t mangle -A merlinclash_NOR -p udp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
		iptables -t mangle -A merlinclash_NOR -p tcp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01

		iptables -t mangle -N merlinclash_CHN
		echo_date "【方案二】创建【mangle】表【merlinclash_CHN】链" >> $LOG_FILE
		iptables -t mangle -A merlinclash_CHN -p udp -m set ! --match-set china_ip_route dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											
		iptables -t mangle -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											

		if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
			# fake-ip rules
			iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
		fi
		if [ "$ipv6_flag" == "0" ]; then
			echo_date "【方案二】清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			lan_bypass4
			iptables -t mangle -A PREROUTING -p udp -j merlinclash
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash
		fi	
		if [ "$ipv6_flag" == "1" ]; then
			echo_date "【方案二】清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			load_tproxy
			#modprobe xt_TPROXY	
			ip -6 rule add fwmark 1 lookup 100
			ip -6 route add local default dev lo table 100
			ip6tables -t mangle -N merlinclash
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			ip6tables -t mangle -F merlinclash
			#强制转发clash
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set ipset_proxy6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
			ip6tables -t mangle -A merlinclash -p udp -m set --match-set ipset_proxy6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
			#强制绕行clash
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set ipset_proxyarround6 dst -j RETURN
			ip6tables -t mangle -A merlinclash -p udp -m set --match-set ipset_proxyarround6 dst -j RETURN
			#局域网&排除地址绕行
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set direct_list6 dst -j RETURN
			ip6tables -t mangle -A merlinclash -p udp -m set --match-set direct_list6 dst -j RETURN
			#
			ip6tables -t mangle -N merlinclash_NOR
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash_NOR】链" >> $LOG_FILE
			ip6tables -t mangle -A merlinclash_NOR -p udp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
			ip6tables -t mangle -A merlinclash_NOR -p tcp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01

			ip6tables -t mangle -N merlinclash_CHN
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash_CHN】链" >> $LOG_FILE
			ip6tables -t mangle -A merlinclash_CHN -p udp -m set ! --match-set china_ip_route6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											
			ip6tables -t mangle -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											
			
			#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x01/0x01 -j TPROXY --on-port "${dnslistenport}"
            #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x01/0x01					
			#ip6tables -t mangle -I PREROUTING -m addrtype ! --src-type LOCAL --dst-type LOCAL -p udp --dport 53 -j TPROXY --on-ip ::1 --on-port "${dnslistenport}" --tproxy-mark 0x01/0x01
			if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
				# fake-ip rules
				ip6tables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
			fi
			lan_bypass4
			iptables -t mangle -A PREROUTING -p udp -j merlinclash
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash
			ip6tables -t mangle -A PREROUTING -p udp -j merlinclash
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash

			#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
		fi
		#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
		if [ "$dnsplan" != "fi" ]; then
			#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
			if [ "$dnsgoclash" == "1" ]; then
				#OUTPUT dns default-nameserver不经过clash避免回环
				dednss=$(yq r $yamlpath "dns.default-nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss" ]; then
					for dedns in $dednss; do
						iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
					done
				fi
				dednss2=$(yq r $yamlpath "dns.nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss2" ]; then
					for dedns in $dednss2; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				dednss3=$(yq r $yamlpath "dns.fallback" | awk -F " " '{print $2}')
				if [ -n "$dednss3" ]; then
					for dedns in $dednss3; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				iptables -t nat -A OUTPUT  -p udp --dport 53 -j REDIRECT --to-port 53
				iptables -t mangle -I PREROUTING -p tcp -m set --match-set router dst -i br0 -m mark --mark 0x2333 -j merlinclash
              	iptables -t mangle -I OUTPUT -p tcp -m set --match-set router dst -j MARK --set-mark 0x2333
			fi
		fi
	elif [ "$tproxymode" == "tcp" ]; then 
		echo_date "【方案二】当前为Tproxy【TCP】透明代理模式" >> $LOG_FILE
		echo_date "【方案二】DNS方案是$dnsplan;配置文件DNS方案是$dem2" >> $LOG_FILE
		echo_date "【方案二】Lan_ip是$lan_ipaddr" >> $LOG_FILE
		if [ "$ipv6switch" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
			echo_date "【方案二】开启IPv6模式" >> $LOG_FILE
		fi
		#SSH端口
		#iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		#iptables -t mangle -A PREROUTING -p tcp --dport $ssh_port -j ACCEPT
		# 设置策略路由
		#modprobe xt_TPROXY	
		load_tproxy
		ip -4 rule add fwmark 1 lookup 100
		ip -4 route add local default dev lo table 100
		iptables -t mangle -N merlinclash
		echo_date "【方案二】创建【mangle】表【merlinclash】链" >> $LOG_FILE
		iptables -t mangle -F merlinclash

		#ip集强制绕过
		iptables -t mangle -A PREROUTING -p tcp -m set --match-set ipset_proxyarround dst -j RETURN
		#局域网&排除地址绕行
		iptables -t mangle -A PREROUTING -p tcp -m set --match-set direct_list dst -j RETURN
		#
		iptables -t mangle -N merlinclash_NOR
		echo_date "【方案二】创建【mangle】表【merlinclash_NOR】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t mangle -A merlinclash_NOR -p tcp -m set --match-set ipset_proxy dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
		iptables -t mangle -A merlinclash_NOR -p tcp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
		
		iptables -t mangle -N merlinclash_CHN
		echo_date "【方案二】创建【mangle】表【merlinclash_CHN】链" >> $LOG_FILE
		#ip集强制代理
		iptables -t mangle -A merlinclash_CHN -p tcp -m set --match-set ipset_proxy dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01
		iptables -t mangle -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											

		if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
			# fake-ip rules
			iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
		fi
		if [ "$ipv6_flag" == "0" ]; then
			echo_date "【方案二】清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			lan_bypass4
			iptables -t mangle -A PREROUTING -p tcp -j merlinclash
		fi
		# ipv6设置策略路由
		if [ "$ipv6_flag" == "1" ]; then
			echo_date "【方案二】清除wanduck监听规则" >> $LOG_FILE
			wanduck1_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18017/=' | sort -r)
			for wanduck1_index in $wanduck1_indexs; do
				iptables -t nat -D PREROUTING $wanduck1_index >/dev/null 2>&1
			done
			wanduck2_indexs=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/18018/=' | sort -r)
			for wanduck2_index in $wanduck2_indexs; do
				iptables -t nat -D PREROUTING $wanduck2_index >/dev/null 2>&1
			done
			ip -6 rule add fwmark 1 lookup 100
			ip -6 route add local default dev lo table 100
			ip6tables -t mangle -N merlinclash
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash】链" >> $LOG_FILE
			ip6tables -t mangle -F merlinclash
			#强制转发clash
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set ipset_proxy6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01	
			#强制绕行clash
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set ipset_proxyarround6 dst -j RETURN
			#局域网&排除地址绕行
			ip6tables -t mangle -A merlinclash -p tcp -m set --match-set direct_list6 dst -j RETURN
			#
			ip6tables -t mangle -N merlinclash_NOR
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash_NOR】链" >> $LOG_FILE
			ip6tables -t mangle -A merlinclash_NOR -p tcp -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01

			ip6tables -t mangle -N merlinclash_CHN
			echo_date "【方案二】创建【ipv6-mangle】表【merlinclash_CHN】链" >> $LOG_FILE
			ip6tables -t mangle -A merlinclash_CHN -p tcp -m set ! --match-set china_ip_route6 dst -j TPROXY --on-port "$tproxy_port" --tproxy-mark 0x01/0x01											

			#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x01/0x01 -j TPROXY --on-port "${dnslistenport}"
            #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x01/0x01					
			#ip6tables -t mangle -I PREROUTING -m addrtype ! --src-type LOCAL --dst-type LOCAL -p udp --dport 53 -j TPROXY --on-ip ::1 --on-port "${dnslistenport}" --tproxy-mark 0x01/0x01
			if [ "$dnsplan" == "fi" ] || [ "$dem2" == "fake-ip" ];then
				# fake-ip rules
				ip6tables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
			fi

			lan_bypass4
			#iptables -t mangle -A PREROUTING -p tcp -j merlinclash
			#ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash

			iptables -t mangle -A PREROUTING -p tcp -j merlinclash	
			ip6tables -t mangle -A PREROUTING -p tcp -j merlinclash
		
			#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
		fi

		#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
		if [ "$dnsplan" != "fi" ]; then
			#iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dnslistenport
			if [ "$dnsgoclash" == "1" ]; then
				#OUTPUT dns default-nameserver不经过clash避免回环
				dednss=$(yq r $yamlpath "dns.default-nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss" ]; then
					for dedns in $dednss; do
						iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
					done
				fi
				dednss2=$(yq r $yamlpath "dns.nameserver" | awk -F " " '{print $2}')
				if [ -n "$dednss2" ]; then
					for dedns in $dednss2; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				dednss3=$(yq r $yamlpath "dns.fallback" | awk -F " " '{print $2}')
				if [ -n "$dednss3" ]; then
					for dedns in $dednss3; do
						#检测为纯IP设为直连
						detect_ip ${dedns}
						a=$?
						if [ "$a" == "4" ]; then	
							iptables -t nat -A OUTPUT -p udp -d $dedns --dport 53 -j RETURN
						fi
					done
				fi
				iptables -t nat -A OUTPUT  -p udp --dport 53 -j REDIRECT --to-port 53
				iptables -t mangle -I PREROUTING -p tcp -m set --match-set router dst -i br0 -m mark --mark 0x2333 -j merlinclash
              	iptables -t mangle -I OUTPUT -p tcp -m set --match-set router dst -j MARK --set-mark 0x2333
			fi
		fi
	fi

	

	# 控制面板的端口转发
	if [ "$merlinclash_dashboardswitch" == "1" ]; then
		echo_date "检测到控制面板公网访问开关开启" >> $LOG_FILE
		open_port
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
		echo_date "【方案二】检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $LOG_FILE
		echo_date "【方案二】检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $SIMLOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
		#ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
        #ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
	fi
	if [ "${LINUX_VER}" -lt "41" ] && [ $(ipv6_mode) == "true" ]; then
		load_tproxy
		echo_date "【方案二】检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $LOG_FILE
		echo_date "【方案二】检测到路由IPv6开启，但未开启Tproxy代理，仅开启IPv6劫持解析" >> $SIMLOG_FILE
		ip -6 route add local default dev lo table 233
		ip -6 rule add fwmark 0x2333         table 233
		#ip6tables -t mangle -I OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		#ip6tables -t mangle -I OUTPUT -m set --match-set macblacklist_dns src -p udp --dport 53 -j RETURN
	fi
	if [ "$dnsplan" == "fi" ]; then
		#ip6tables -t mangle -D PREROUTING -p udp --dport 53 -m mark --mark 0x2333 -j TPROXY --on-port "${dnslistenport}"
        #ip6tables -t mangle -D OUTPUT -p udp --dport 53 -j MARK --set-mark 0x2333
		ip6tables -t mangle -I PREROUTING -p udp --dport 53 -m set --match-set lan_blacklist src -j DROP #阻断黑名单设备ipv6dns查询
		#iptables -t nat -I PREROUTING 3 -p udp --dport 53 -m set --match-set lan_blacklist src -j RETURN
		if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
	        iptables -t nat -A OUTPUT -p tcp -m set --match-set router dst -j merlinclash
        else 
	        iptables -t mangle -I PREROUTING -p tcp -m set --match-set router dst -m mark --mark 0x2333 -j merlinclash_PREROUTING
            iptables -t mangle -I OUTPUT -p tcp -m set --match-set router dst -j MARK --set-mark 0x2333
        fi
	fi
	echo_date "【方案二】iptable规则创建完成" >> $LOG_FILE
}
lan_bypass4(){	
	# deivce_nu 获取已存数据序号
	echo_date ------------------- 【方案二】设备管理检查区 开始 --------------------- >> $LOG_FILE
	OS=$(uname -r)
	whitelist_nu=$(get_list merlinclash_whitelist_ip 1 4)
	device_nu=$(get_list merlinclash_device_ip 1 4)
	#KOOLPROXY&UnblockNeteaseMusic兼容
	KP_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | head -n1)
	CL_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/cloud_music/=' | head -n1)
	if [ "$CL_NU" != "" ]; then
		INSET_NU=$(expr "$CL_NU" + 1)
	else
		if [ "$KP_NU" == "" ]; then
			KP_NU=0
		fi
		INSET_NU=$(expr "$KP_NU" + 1)
	fi
	wlnum=0
	if lsmod | grep ip_set_hash_mac &>/dev/null; then
		echo_date "ip_set_hash_mac模块已加载" >> $LOG_FILE; 
	else
		#检查是否固件是否有ip_set_hash_mac模块
		if [ -f "/lib/modules/${OS}/kernel/net/netfilter/ipset/ip_set_hash_mac.ko" ]; then
			echo_date "加载ip_set_hash_mac模块" >> $LOG_FILE; 
			modprobe ip_set_hash_mac
		else
			echo_date "ip_set_hash_mac模块不存在，尝试使用黑白名单功能" >> $LOG_FILE
		fi
	fi
	#KOOLPROXY兼容重写
	kppid=$(pidof koolproxy)
	if [ -z "$kppid" ] || [ "$kpenable" == "0" ];then
		mnm=$(get merlinclash_nokpacl_method)
		echo_date "【方案二】未开启护网大师，已设置【$(get_method_name $mnm)】过滤" >> $LOG_FILE
		list_flag="0"
		tproxymode=$(get merlinclash_tproxymode)
		if [ "$tproxymode" == "closed" ] || [ "$tproxymode" == "udp" ]; then
			list_flag="1" #REDIR-TCP / TPROXY-UDP
		elif [ "$tproxymode" == "tcp" ] || [ "$tproxymode" == "tcpudp" ]; then
			list_flag="2" #TPROXY-TCP / TCP&UDP
		fi
		nokpacl_nu=$(get_list merlinclash_nokpacl_ip 1 4)
		if [ -f "/jffs/softcenter/res/macblacklist_dns.ipset" ]; then
			ipset destroy macblacklist_dns >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/macwhitelist_dns.ipset" ]; then
			ipset destroy macwhitelist_dns >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/lan_blacklist.ipset" ]; then
			ipset destroy lan_blacklist >/dev/null 2>&1
		fi
		if [ -f "/jffs/softcenter/res/lan_whitelist.ipset" ]; then
			ipset destroy lan_whitelist >/dev/null 2>&1
		fi
		echo "create macblacklist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macblacklist_dns.ipset
		echo "create macwhitelist_dns hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/macwhitelist_dns.ipset
		if [ "$mnm" != "2" ]; then
			echo "create lan_blacklist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:mac hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
		else
			echo "create lan_blacklist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
		fi
		echo "create ipblacklist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipblacklist_dns.ipset
		echo "create ipwhitelist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipwhitelist_dns.ipset
		if [ "$list_flag" == "1" ]; then
			if [ -n "$nokpacl_nu" ]; then
				for nokpacl in $nokpacl_nu; do
					echo_date "【方案二】处理当前第$nokpacl条规则" >> $LOG_FILE
					ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
					macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					[ "$mnm" == "1" ] && echo_date "【方案二】设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "2" ] && macaddr="" && "【方案二】设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "3" ] && ipaddr="" && "【方案二】设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
						echo_date "【方案二】设备$proxy_name MAC地址为空，不做处理，跳过。" >> $LOG_FILE
						continue
					fi
					if [ "$proxy_mode" == "0" ] && [ "$mnm" != "2" ]; then
						echo_date "【方案二】$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					elif [ "$proxy_mode" == "0" ] && [ "$mnm" == "2" ]; then
						echo_date "【方案二】$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" == "all" ]; then
						echo_date "【方案二】$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" == "all" ]; then
						echo_date "【方案二】$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" != "all" ]; then
						echo_date "【方案二】$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" != "all" ]; then
						echo_date "【方案二】$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
					fi
					#访问自定端口走代理
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "【方案二】$proxy_name 访问指定端口【$ports】转发进Clash" >> $LOG_FILE
						#iptables -t nat -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport ! --dport") -j RETURN
							iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						fi
					fi
					# 2 acl in OUTPUT（used by koolproxy）
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					# 3 acl in SHADOWSOCKS for mangle
				done
				if [ "$mnm" != "2" ]; then
					ipset -! flush macblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
					ipset -! flush macwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
				else
					ipset -! flush ipblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
					ipset -! flush ipwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				fi
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
			#iptables写法		
				iptables -t nat -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t mangle -I PREROUTING -i br1 -j RETURN
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t mangle -I PREROUTING -i br2 -j RETURN
				if [ "$tproxymode" == "udp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				#20201122
				iptables -t mangle -I merlinclash -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1

			#2.白名单内再放行
				if [ "$cirswitch" == "1" ]; then
					echo_date "【方案二】设置白名单走merlinclash_CHN链" >> $LOG_FILE		
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_CHN
					else
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp -j RETURN
					fi
				else
					echo_date "【方案二】设置白名单走merlinclash_NOR链" >> $LOG_FILE
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR
					if [ "$tproxymode" == "udp" ]; then
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_NOR
					else
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp -j RETURN
					fi
				fi
			#3.剩余主机处理
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载ACL规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问全端口通过clash
						#iptables写法
						#大陆白判断
						#echo_date "路由IP：DNS端口为${lan_ipaddr}:${dnslistenport}" >> $LOG_FILE
						if [ "$cirswitch" == "1" ]; then				
							iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
							#	iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
								iptables -t mangle -I PREROUTING -m set --match-set macblacklist_dns src -p udp -j RETURN >/dev/null 2>&1 #20210104
								iptables -t mangle -I PREROUTING -m set --match-set china_ip_route dst -p udp -j RETURN >/dev/null 2>&1 #20210104
							fi
						else
							iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
								iptables -t mangle -I PREROUTING -m set --match-set macblacklist_dns src -p udp -j RETURN >/dev/null 2>&1 #20210104
							fi
						fi
					else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
						echo_date "【方案二】剩余主机全端口不通过clash，只给通过clash的设备转发dns端口" >> $LOG_FILE
						#iptables写法
						if [ "$cirswitch" == "1" ]; then				
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
													
							fi
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
							fi
						else
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
							fi
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
							fi
						fi
					fi
				else 
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载ACL规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问指定端口通过clash
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN				
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							fi
						else
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "udp" ]; then
								iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							fi
						fi
					fi
				fi
			else
				echo_date "【方案二】未设置设备绕行，使用默认：全设备转发进Clash" >> $LOG_FILE
				merlinclash_nokpacl_default_mode="1"
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					echo_date 加载ACL规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
						fi
					else
						iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
													
							fi
						if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
						fi
					fi
				else
					echo_date 【方案二】加载ACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					# 1 acl in SHADOWSOCKS for nat
					#iptables -t nat -A merlinclash $(factor $ipaddr "-m mac --mac-source") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
												
							fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
						fi
					else
						iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
							fi
						if [ "$tproxymode" == "udp" ]; then
							iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
						fi
					fi
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
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
					echo_date "【方案二】处理当前第$nokpacl条规则" >> $LOG_FILE
					ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
					#ipaddr_hex=$(echo $ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}')
					macaddr=$(eval echo \$merlinclash_nokpacl_mac_$nokpacl)
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl) #0不通过clash  1通过clash
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					[ "$mnm" == "1" ] && echo_date "【方案二】设备IP地址：【$ipaddr】，MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "2" ] && macaddr="" && "【方案二】设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					[ "$mnm" == "3" ] && ipaddr="" && "【方案二】设备MAC地址：【$macaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$mnm" == "3" ] && [ "$macaddr" == "" ]; then
						echo_date "【方案二】设备$proxy_name MAC地址为空，不做处理，跳过。" >> $LOG_FILE
						continue
					fi
					if [ "$proxy_mode" == "0" ] && [ "$mnm" != "2" ]; then
						echo_date "【方案二】$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${macaddr}" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add macblacklist_dns ${macaddr}" >> /jffs/softcenter/res/macblacklist_dns.ipset
					elif [ "$proxy_mode" == "0" ] && [ "$mnm" == "2" ]; then
						echo_date "【方案二】$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" == "all" ]; then
						echo_date "【方案二】$proxy_name 全端口代理，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${macaddr}" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" == "all" ]; then
						echo_date "【方案二】$proxy_name 全端口转发进Clash，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if ([ "$proxy_mode" == "1" ] && [ "$mnm" != "2" ]) && [ "$ports" != "all" ]; then
						echo_date "【方案二】$proxy_name 指定端口代理，添加进转发DNS集" >> $LOG_FILE
						echo "add macwhitelist_dns ${macaddr}" >> /jffs/softcenter/res/macwhitelist_dns.ipset
					elif ([ "$proxy_mode" == "1" ] && [ "$mnm" == "2" ]) && [ "$ports" != "all" ]; then
						echo_date "【方案二】$proxy_name 指定端口转发进Clash，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
					fi
					# 1 acl in SHADOWSOCKS for nat
					#访问自定端口走代理
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "【方案二】$proxy_name 访问指定端口【$ports】走代理" >> $LOG_FILE
						#iptables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						if [ "$ipv6_flag" == "1" ]; then
							#ip6tables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
							ip6tables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
							ip6tables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport ! --dport") -j RETURN
							iptables -t mangle -A merlinclash $(factor $ipaddr "-s") $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport ! --dport") -j RETURN
								ip6tables -t mangle -A merlinclash $(factor $macaddr "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
							fi
						fi
					fi
					# 2 acl in OUTPUT（used by koolproxy）
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					# 3 acl in SHADOWSOCKS for mangle
				done
				if [ "$mnm" != "2" ]; then
					ipset -! flush macblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macblacklist_dns.ipset 2>/dev/null
					ipset -! flush macwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/macwhitelist_dns.ipset 2>/dev/null
				else
					ipset -! flush ipblacklist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
					ipset -! flush ipwhitelist_dns 2>/dev/null
					ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				fi
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
			#iptables写法	
				echo_date "【方案二】iptables处理中" >> $LOG_FILE		
				echo_date "【方案二】黑名单内先过滤" >> $LOG_FILE		
				iptables -t mangle -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t mangle -I PREROUTING -i br1 -j RETURN
				ip6tables -t mangle -I PREROUTING -i br1 -j RETURN
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				ip6tables -t mangle -I PREROUTING -i br2 -j RETURN
				iptables -t mangle -I PREROUTING -i br2 -j RETURN
				if [ "$tproxymode" == "udp" ] || [ "$tproxymode" == "tcpudp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
						ip6tables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				if [ "$ipv6_flag" == "1" ]; then
					#ip6tables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
					ip6tables -t mangle -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				fi
				#20201122
				if [ "$tproxymode" == "tcpudp" ]; then
					iptables -t mangle -I merlinclash -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
					if [ "$ipv6_flag" == "1" ]; then
						#ip6tables -t mangle -I merlinclash_PREROUTING -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
						ip6tables -t mangle -I merlinclash -m set --match-set lan_blacklist src -p udp -j RETURN >/dev/null 2>&1
					fi
				fi
			#2.白名单内再放行
				echo_date "【方案二】白名单内再放行" >> $LOG_FILE	
				if [ "$cirswitch" == "1" ]; then		
					iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_CHN
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_CHN
						fi
					fi
				else
					iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR
					if [ "$ipv6_flag" == "1" ]; then
						ip6tables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR
					fi
					if [ "$tproxymode" == "tcpudp" ]; then
						iptables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_NOR
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -m set --match-set lan_whitelist src -p udp  -j merlinclash_NOR
						fi
					fi
				fi
			#3.剩余主机处理
				echo_date "【方案二】剩余主机处理" >> $LOG_FILE	
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载ACL规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问全端口通过clash
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then				
							iptables -t mangle -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p tcp -j merlinclash_CHN
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
								if [ "$ipv6_flag" == "1" ]; then
									ip6tables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
								fi
							fi
						else
							iptables -t mangle -A merlinclash -p tcp -j merlinclash_NOR
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p tcp -j merlinclash_NOR
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
								iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
								if [ "$ipv6_flag" == "1" ]; then
									ip6tables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
								fi
							fi
						fi
					else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
						echo_date "【方案二】剩余主机全端口不通过clash，只给通过clash的设备转发dns端口" >> $LOG_FILE
						#iptables写法
						#大陆白判断
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING 3 -m set --match-set macwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
						fi
					fi
				else
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载ACL规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then #剩余主机访问指定端口通过clash
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then				
							iptables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
								iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
								if [ "$ipv6_flag" == "1" ]; then
									ip6tables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
								fi
							fi
						else
							iptables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							fi
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set macblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							if [ "$tproxymode" == "tcpudp" ]; then
								iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
								if [ "$ipv6_flag" == "1" ]; then
									ip6tables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
								fi
							fi
						fi
					fi
				fi
			else
				echo_date "【方案二】未设置设备绕行，使用默认：全设备转发进Clash" >> $LOG_FILE
				merlinclash_nokpacl_default_mode="1"
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					echo_date 【方案二】加载ACL规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t mangle -A merlinclash -p tcp -j merlinclash_CHN
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -p tcp -j merlinclash_CHN
						fi
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p udp  -j merlinclash_CHN
							fi
						fi
					else
						iptables -t mangle -A merlinclash -p tcp -j merlinclash_NOR
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -p tcp -j merlinclash_NOR
						fi
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
				
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p udp  -j merlinclash_NOR
							fi
						fi
					fi
				else
					echo_date 【方案二】加载ACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					# 1 acl in SHADOWSOCKS for nat
					#iptables -t nat -A merlinclash $(factor $ipaddr "-m mac --mac-source") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						iptables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
						fi
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_CHN
							fi
						fi
					else
						iptables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
						if [ "$ipv6_flag" == "1" ]; then
							ip6tables -t mangle -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
						fi
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
						fi
						if [ "$tproxymode" == "tcpudp" ]; then
							iptables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
							if [ "$ipv6_flag" == "1" ]; then
								ip6tables -t mangle -A merlinclash -p udp -m multiport --dport $merlinclash_nokpacl_default_port  -j merlinclash_NOR
							fi
						fi
					fi
					#iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
				fi
			fi
			dbus remove merlinclash_nokpacl_ip
			dbus remove merlinclash_nokpacl_name
			dbus remove merlinclash_nokpacl_mode
			dbus remove merlinclash_nokpacl_port
		fi
	fi
	if [ ! -z "$kppid" ] && [ "$kpenable" == "1" ];then
			echo_date "【方案二】当前开启护网大师,使用【仅IP匹配】方案过滤" >> $LOG_FILE	
			nokpacl_nu=$(get_list merlinclash_nokpacl_ip 1 4)
			#20201215黑名单内设备IP DNS不走转发。
			if [ -f "/jffs/softcenter/res/ipblacklist_dns.ipset" ]; then
				ipset destroy ipblacklist_dns >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/ipwhitelist_dns.ipset" ]; then
				ipset destroy ipwhitelist_dns >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/lan_blacklist.ipset" ]; then
				ipset destroy lan_blacklist >/dev/null 2>&1
			fi
			if [ -f "/jffs/softcenter/res/lan_whitelist.ipset" ]; then
				ipset destroy lan_whitelist >/dev/null 2>&1
			fi
			echo "create ipblacklist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipblacklist_dns.ipset
			echo "create ipwhitelist_dns hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/ipwhitelist_dns.ipset
			echo "create lan_blacklist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_blacklist.ipset
			echo "create lan_whitelist hash:net family inet hashsize 1024 maxelem 65536" >/jffs/softcenter/res/lan_whitelist.ipset
			if [ -n "$nokpacl_nu" ]; then
				for nokpacl in $nokpacl_nu; do
					echo_date "【方案二】处理当前第$nokpacl条规则" >> $LOG_FILE
					ipaddr=$(eval echo \$merlinclash_nokpacl_ip_$nokpacl)
					ipaddr_hex=$(echo $ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}')
					ports=$(eval echo \$merlinclash_nokpacl_port_$nokpacl)
					proxy_mode=$(eval echo \$merlinclash_nokpacl_mode_$nokpacl)
					proxy_name=$(eval echo \$merlinclash_nokpacl_name_$nokpacl)
					echo_date "【方案二】设备IP地址：【$ipaddr】，端口：【$ports】，代理模式：【$(get_mode_name $proxy_mode)】" >> $LOG_FILE
					if [ "$proxy_mode" == "0" ]; then
						echo_date "【方案二】$proxy_name 不走代理，添加进黑名单集和绕行DNS集" >> $LOG_FILE
						echo "add lan_blacklist ${ipaddr}/32" >> /jffs/softcenter/res/lan_blacklist.ipset
						echo "add ipblacklist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipblacklist_dns.ipset
					fi
					if [ "$proxy_mode" == "1" ] && [ "$ports" == "all" ]; then
						echo_date "【方案二】$proxy_name 全端口代理，添加进白名单集和转发DNS集" >> $LOG_FILE
						echo "add lan_whitelist ${ipaddr}/32" >> /jffs/softcenter/res/lan_whitelist.ipset
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "all" ]; then
						echo_date "【方案二】$proxy_name 指定端口代理，添加进转发DNS集" >> $LOG_FILE
						echo "add ipwhitelist_dns ${ipaddr}/32" >> /jffs/softcenter/res/ipwhitelist_dns.ipset
					fi
					if [ "$ports" == "all" ]; then
						ports=""
						echo_date 【方案二】加载KoolProxyACL规则：【$proxy_name】【全部端口】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
					else
						echo_date 【方案二】加载KoolProxyACL规则：【$proxy_name】【$ports】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
					fi
					# 1 acl in SHADOWSOCKS for nat
					#访问自定端口走代理
					if [ "$proxy_mode" == "1" ] && [ "$ports" != "" ]; then
						echo_date "【方案二】$proxy_name 访问指定端口【$ports】走代理" >> $LOG_FILE
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $ports "-m multiport ! --dport") -j RETURN
						iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
						# 2 acl in OUTPUT（used by koolproxy）
						iptables -t nat -A merlinclash_EXT -p tcp $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
					fi
				done
				ipset -! flush ipblacklist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipblacklist_dns.ipset 2>/dev/null
				ipset -! flush ipwhitelist_dns 2>/dev/null
				ipset -! restore </jffs/softcenter/res/ipwhitelist_dns.ipset 2>/dev/null
				ipset -! flush lan_blacklist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_blacklist.ipset 2>/dev/null
				ipset -! flush lan_whitelist 2>/dev/null
				ipset -! restore </jffs/softcenter/res/lan_whitelist.ipset 2>/dev/null
				#IPTABLES写法
				#1.黑名单内先过滤
				#iptables写法		
				iptables -t nat -I merlinclash -m set --match-set lan_blacklist src -p tcp -j RETURN >/dev/null 2>&1
				iptables -t nat -I PREROUTING -i br1 -j RETURN >/dev/null 2>&1
				iptables -t mangle -I PREROUTING -i br1 -j RETURN
				iptables -t nat -I PREROUTING -i br2 -j RETURN >/dev/null 2>&1
				iptables -t mangle -I PREROUTING -i br2 -j RETURN
				if [ "$tproxymode" == "udp" ]; then
					    iptables -t mangle -I merlinclash_PREROUTING -p udp --dport 53 -j RETURN
				fi
				#2.白名单内再放行
				if [ "$cirswitch" == "1" ]; then		
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_CHN
				else
					iptables -t nat -A merlinclash -m set --match-set lan_whitelist src -p tcp -j merlinclash_NOR	
				fi
				#剩余主机处理
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ]; then
					merlinclash_nokpacl_default_port=""
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载KoolProxyACL规则：【剩余主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then				
							iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						else
							iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							else
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i $interface -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i pptp+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i tun+ -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
						#		iptables -t nat -A PREROUTING -p udp --dport 53 -i br0 -j REDIRECT --to-port "${dnslistenport}" >/dev/null 2>&1
								if [ "$dnsplan" == "fi" ]; then
									iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j DNAT --to ${dfib} >/dev/null 2>&1
								fi
							fi
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					else  #剩余主机全端口不通过clash，只给通过clash的设备转发dns端口
						echo_date "【方案二】剩余主机全端口不通过clash，只给通过clash的设备转发dns端口" >> $LOG_FILE
						#iptables写法
						#大陆白判断
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING 3 -m set --match-set ipwhitelist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
						fi
					fi
				else
					[ -z "$merlinclash_nokpacl_default_mode" ] && dbus set merlinclash_nokpacl_default_mode="0" && merlinclash_nokpacl_default_mode="0"
					echo_date 【方案二】加载KoolProxyACL规则：【剩余主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					if [ "$merlinclash_nokpacl_default_mode" == "1" ]; then
						#iptables写法
						#大陆白判断
						if [ "$cirswitch" == "1" ]; then	
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN		
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_CHN
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							fi
							#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						else
							iptables -t nat -A merlinclash -p tcp -m multiport ! --dport $merlinclash_nokpacl_default_port -j RETURN
							iptables -t nat -A merlinclash -p tcp -m multiport --dport $merlinclash_nokpacl_default_port -j merlinclash_NOR
							if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							fi
							#iptables -t nat -I PREROUTING -m set --match-set ipblacklist_dns src -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
				fi
			else
				echo_date "【方案二】未设置设备绕行，使用默认：全设备转发进Clash" >> $LOG_FILE
				merlinclash_nokpacl_default_mode="1"
				if [ "$merlinclash_nokpacl_default_port" == "all" ] || [ "$merlinclash_nokpacl_default_port" == "" ] ; then
					merlinclash_nokpacl_default_port=""
					echo_date 【方案二】加载KoolProxyACL规则：【全部主机】【全部端口】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					#iptables写法
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then				
						iptables -t nat -A merlinclash -p tcp -j merlinclash_CHN
						if [ "$dnshijacksel" == "front" ]; then
							iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					else
						iptables -t nat -A merlinclash -p tcp -j merlinclash_NOR
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						fi
					fi
				else
					echo_date 【方案二】加载KoolProxyACL规则：【全部主机】【$merlinclash_nokpacl_default_port】模式为：$(get_mode_name $merlinclash_nokpacl_default_mode) >> $LOG_FILE
					# 1 acl in SHADOWSOCKS for nat
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport ! --dport") -j RETURN
					
					iptables -t nat -A merlinclash $(factor $ipaddr "-s") -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					# 2 acl in OUTPUT（used by koolproxy）
					iptables -t nat -A merlinclash_EXT -p tcp $(factor $merlinclash_nokpacl_default_port "-m multiport --dport") -$(get_jump_mode $merlinclash_nokpacl_default_mode) $(get_action_chain $merlinclash_nokpacl_default_mode)
					#大陆白判断
					if [ "$cirswitch" == "1" ]; then
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
						
							fi
						#iptables -t nat -I PREROUTING -m set --match-set china_ip_route dst -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					else
						if [ "$dnshijacksel" == "front" ]; then
								iptables -t nat -I PREROUTING 3 -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
					
							fi
					fi		
				fi
			fi
			dbus remove merlinclash_nokpacl_ip
			dbus remove merlinclash_nokpacl_name
			dbus remove merlinclash_nokpacl_mode
			dbus remove merlinclash_nokpacl_port
	fi
	dbus remove merlinclash_device_ip
	dbus remove merlinclash_device_name
	dbus remove merlinclash_device_mode
	dbus remove merlinclash_whitelist_ip
	dbus remove merlinclash_ipport_ip
	dbus remove merlinclash_ipport_name
	dbus remove merlinclash_ipport_port
	echo_date ------------------- 【方案二】设备管理检查区 结束 --------------------- >> $LOG_FILE
}
restart_dnsmasq() {
    # Restart dnsmasq
	rm -rf /tmp/etc/dnsmasq.user/dns_custom.conf >/dev/null 2>&1

	#if [ "$mcenable" == "1" ]; then
	#	echo "server=127.0.0.1#${dnslistenport}" > /tmp/resolv.dnsmasq
	#	if [ "$dnsplan" == "fi" ]; then			
	#		nameservers=$(cat /tmp/resolv.conf | awk -F " " '/nameserver/{print $2}')
	#		for nameserver in $nameservers; do
	#		    detect_ip ${nameserver}
	#			b=$?
	#				if [ "$b" == "4" ]; then
	#				#echo_date "为合法IPV4格式，进行处理" >> $LOG_FILE
	#				echo "dhcp-option-force=br1,6,"${nameserver} >> /tmp/etc/dnsmasq.user/dns_custom.conf
	#			    echo "dhcp-option-force=br2,6,"${nameserver} >> /tmp/etc/dnsmasq.user/dns_custom.conf
	#				fi
	#		done
	#	fi 
	#else
	#	rm -rf /tmp/resolv.dnsmasq
	#	nameservers=$(cat /tmp/resolv.conf | awk -F " " '/nameserver/{print $2}')
	#	for nameserver in $nameservers; do
	#		echo "server=$nameserver" >> /tmp/resolv.dnsmasq
	#	done

	#fi
    echo_date "重启 dnsmasq..." >> $LOG_FILE
    service restart_dnsmasq >/dev/null 2>&1
}

startClashNormalOrPerp(){
    local clashRunLog="/tmp/clash_run.log"
    local watchdog=$(get merlinclash_watchdog)
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
	echo_date "启用$yamlname YAML配置" >> $LOG_FILE
	echo_date "启用$yamlname YAML配置" >> $SIMLOG_FILE
	rm -rf "/tmp/upload/view.txt"
	cp -rf $yamlpath /tmp/upload/view.txt
	count1=$(cat $yamlpath | grep -n "^proxies:" | awk -F ":" '{print $1}')
	count2=$(cat $yamlpath | grep -n "^proxy-groups:" | awk -F ":" '{print $1}')
	count=$(($count2-$count1-1))
	sed -i "1i 当前配置为：【$yamlname】，节点数为：$count个，DNS方案为：$(get_dns_plan $dnsplan)" /tmp/upload/view.txt
	echo_date "启动Clash程序" >> $LOG_FILE
#
# 启动clash，看看是不是需要用Perp守护进程
#
	startClashNormalOrPerp
#
# 结束
#
	if [ ! $retryTimes ] || [ $retryTimes -lt 20 ];then
		retryTimes=40
		dbus set merlinclash_check_delay_time=40
	fi

	echo_date "启动Clash程序完毕，Clash启动日志位置：/tmp/clash_run.log" >> $LOG_FILE
	echo_date "正在检查Clash进程启动是否报错，请稍候！" >> $LOG_FILE
	echo_date "尝试重试检查日志次数：$retryTimes 次"  >> $LOG_FILE
	
	until [ "$(pidof clash)" -a "$(netstat -anp | grep clash |head -n 5)" -a ! -n "$(grep "Parse config error" /tmp/clash_run.log | head -n 5)" ]; do
		if [ "$retryTimes" -lt 1 ]; then
    		echo_date "Clash 进程启动失败！请检查配置文件是否存在问题，即将退出" >> $LOG_FILE
    		echo_date "Clash 进程启动失败！请查看日志检查原因" >> $SIMLOG_FILE
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
    		dbus set merlinclash_clashstarttime=""
    		close_in_five
			return
		fi
		retryTimes=$(($retryTimes - 1))
		usleep 300000
	done
	
	usleep 300000
	echo_date "Clash 进程启动成功！(PID: $(pidof clash))"
	a_tmp=$(echo_date2)
	dbus set merlinclash_clashstarttime=$a_tmp
	rm -rf /tmp/upload/*.yaml

	sed -i '/d2s_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	if [ "$d2s" == "1" ]; then
		echo_date "检测到启用dns2socks"
		/jffs/softcenter/bin/mc_dns2socks 127.0.0.1:${socksport} ${d2s_dnsnp} 127.0.0.1:${d2s_lp} >/dev/null  2>&1 &
		if [ ! -z "$(pidof mc_dns2socks)" ]; then
			echo_date "Dns2Socks 进程启动成功！(PID: $(pidof mc_dns2socks))"
			echo_date "启动dns2socks看门狗"
			cru a d2s_watchdog "*/1 * * * * /bin/sh /jffs/softcenter/scripts/clash_d2swatchdog.sh"
		else
			echo_date "【错误】Dns2Socks进程启动失败！"
			echo_date "这将影响您的网络访问，请重启插件或者关闭Dns2Socks！"
		fi
	fi
	if [ "$LINUX_VER" != "26" ];then
		if [ "$merlinclash_open_kernel_tfo" == "1" ];then
			echo_date "开启内核 TCP Fast Open支持！";
			echo 3 >/proc/sys/net/ipv4/tcp_fastopen
		else
			echo 1 >/proc/sys/net/ipv4/tcp_fastopen
		fi
	fi
}

check_yaml(){
	#配合自定规则，此处修改为每次都从BAK恢复原版文件来操作-20200629
	#每次从/jffs/softcenter/merlinclash/yaml 复制一份上传的 上传文件名.yaml 使用
	#echo_date "从yaml_bak恢复初始文件：$yamlname.yaml" >> $LOG_FILE
	cp -rf /jffs/softcenter/merlinclash/yaml_bak/$yamlname.yaml $yamlpath
	if [ -f "$yamlpath" ]; then
		echo_date "检查到Clash配置文件存在！选中的配置文件是【$yamlname】" >> $LOG_FILE
		#插入一行免得出错
		sed -i '$a' $yamlpath
		#20220517修改订阅后，此处先合并RULE文件，根据自定义规则选择项来进行处理，值为：merlinclash_cusrule_plan
		
		if [ "$cusruleplan" == "closed" ] || [ "$cusruleplan" == "easy" ] ; then
			#合并rule_bak默认文件
			cat /jffs/softcenter/merlinclash/rule_bak/${yamlname}_rules.yaml >> $yamlpath
		else
			cat /jffs/softcenter/merlinclash/rule_use/${yamlname}_rules.yaml >> $yamlpath
		fi
		#插入一行免得出错
		sed -i '$a' $yamlpath
		cat $head_tmp >> $yamlpath
		echo_date "标准头文件合并完毕" >> $LOG_FILE
		sed -i "s/192.168.2.1:9990/$lan_ip:9990/g" $yamlpath		
		mode=$(get merlinclash_${yamlname})
		[ -n "$mode" ] && sed -i "s/mode: rule/mode: $mode/g" $yamlpath && echo_date "恢复配置默认mode模式：${mode}" >> $LOG_FILE
		

		#提取配置监听端口
		ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3} ' | xargs echo -n)
		ecip=$(cat $yamlpath | awk -F: '/external-controller/{print $2} ' | xargs echo -n)
	else
		echo_date "文件丢失，没有找到上传的配置文件！请先上传您的配置文件！" >> $LOG_FILE
		echo_date "...MerlinClash！退出中..." >> $LOG_FILE
		close_in_five
	fi
}
check_ss(){
	
	pid_ss=$(pidof ss-redir)
	pid_rss=$(pidof rss-redir)
	pid_v2ray=$(pidof v2ray)
	pid_trojan=$(pidof trojan)
	pid_trojango=$(pidof trojan-go)
	pid_koolgame=$(pidof koolgame)
	if [ -n "$pid_ss" ] || [ -n "$pid_v2ray" ] || [ -n "$pid_trojan" ] || [ -n "$pid_trojango" ] || [ -n "$pid_koolgame" ] || [ -n "$pid_rss" ]; then
    	echo_date "检测到【科学上网】插件运行中，请先关闭该插件，再运行MerlinClash！"
		echo_date "...MerlinClash！退出中..."
		close_in_five 	
    else
	    echo_date "没有检测到冲突插件，准备开启MerlinClash！"
	fi
}

get_lan_cidr() {
	local netmask=$(nvram get lan_netmask)
	local x=${netmask##*255.}
	set -- 0^^^128^192^224^240^248^252^254^ $(((${#netmask} - ${#x}) * 2)) ${x%%.*}
	x=${1%%$3*}
	suffix=$(($2 + (${#x} / 4)))
	#prefix=`nvram get lan_ipaddr | cut -d "." -f1,2,3`
	echo $lan_ipaddr/$suffix
}

#yaml面板secret段重赋值
start_custom(){
	#预删除tproxy: true跟tproxy-port:，避免一键还原的配置有问题
	sed -i '/^tproxy:/d' $yamlpath 2>/dev/null
	sed -i '/^tproxy-port:/d' $yamlpath 2>/dev/null
	#提取配置认证码
	secret=$(cat $yamlpath | awk '/secret:/{print $2}'  | xargs echo -n)
	#提取配置监听端口
	ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3} ' | xargs echo -n)
	ecip=$(cat $yamlpath | awk -F: '/external-controller/{print $2} ' | xargs echo -n)
	#端口取值
	httpport=$(cat $yamlpath | awk -F: '/^port/{print $2}' | xargs echo -n)
	socksport=$(cat $yamlpath | awk -F: '/^socks-port/{print $2}' | xargs echo -n)
	proxy_port=$(cat $yamlpath | awk -F: '/^redir-port/{print $2}' | xargs echo -n)
	tproxy_port=$(cat $yamlpath | awk -F: '/^tproxy-port/{print $2}' | xargs echo -n)
	dnslistenport=$(cat $yamlpath | awk -F: '/listen/{print $3}' | xargs echo -n)
	modesel=$(get merlinclash_clashmode)

	if [ "$modesel" == "default" ]; then
		modesel=$(cat $yamlpath | grep "^mode:" | awk -F "[: ]" '{print $3}'| xargs echo -n)
	fi

	KP_NU=$(iptables -nvL PREROUTING -t nat | sed 1,2d | sed -n '/KOOLPROXY/=' | head -n1)
	if [ "$KP_NU" != "" ]; then
		echo_date "检测到KoolProxy运行中，将Tproxy模式和IPv6代理强制关闭" >> $LOG_FILE
		echo_date "检测到KoolProxy运行中，将访问控制匹配方法设置为【仅IP匹配】" >> $LOG_FILE
		tproxymode="closed"
		dbus set merlinclash_tproxymode=$tproxymode	
		dbus set merlinclash_ipv6switch=0	
		dbus set merlinclash_nokpacl_method="2"

	fi
	if [ "$kpenable" == "1" ]; then
		echo_date "当前开启KoolProxy，将Tproxy模式和IPv6代理强制关闭" >> $LOG_FILE
		echo_date "检测到KoolProxy运行中，将访问控制匹配方法设置为【仅IP匹配】" >> $LOG_FILE
		tproxymode="closed"
		dbus set merlinclash_tproxymode=$tproxymode
		dbus set merlinclash_ipv6switch=0
		dbus set merlinclash_nokpacl_method="2"
	fi
	if [ "${LINUX_VER}" -lt "41" ]; then
		echo_date "检测到Linux内核版本小于4.1，将Tproxy模式和IPv6代理强制关闭" >> $LOG_FILE
		tproxymode="closed"
		dbus set merlinclash_tproxymode=$tproxymode	
		dbus set merlinclash_ipv6switch=0	
	fi
	ipv6switch=$(get merlinclash_ipv6switch)
	tproxymode=$(get merlinclash_tproxymode)
	#TPROXY赋值
	if [ "${LINUX_VER}" -ge "41" ]; then
		echo_date "当前Linux内核版本大于等于4.1,写入Tproxy设置至配置文件末" >> $LOG_FILE
		cat /jffs/softcenter/merlinclash/yaml_basic/tproxy.yaml >> $yamlpath
		tproxy_port=$(cat $yamlpath | awk -F: '/^tproxy-port/{print $2}' | xargs echo -n)
	fi
  #内核代理组状态记忆&fake-ip缓存启用
	if [ "${coremark}" == "1" ]; then
		echo_date "开启内核代理组状态记忆及Fake-ip缓存" >> $LOG_FILE
		sed -i "s/store-selected: false/store-selected: true/g" $yamlpath
		sed -i "s/store-fake-ip: false/store-fake-ip: true/g" $yamlpath
	fi
	#SNIFFER+++
	sni=$(get merlinclash_sniffer)
	#sni_force=$(get merlinclash_sniffer_force)
	if [ "$sni" == "1" ]; then
		#插入换行符免得出错
		sed -i '$a' $yamlpath
		cat /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml >> $yamlpath
	fi
	tcpc=$(get merlinclash_tcp_concurrent)
	#sni_force=$(get merlinclash_sniffer_force)
	if [ "$tcpc" == "1" ]; then
		#插入换行符免得出错
		sed -i '$a' $yamlpath
		cat /jffs/softcenter/merlinclash/yaml_basic/tcp.yaml >> $yamlpath
	fi
	#SNIFFER---
	mcc=$(get merlinclash_custom_cbox)
	mcp=$(get merlinclash_cus_port)
	mcsp=$(get merlinclash_cus_socksport)
	mcrp=$(get merlinclash_cus_redirsport)
	mctp=$(get merlinclash_cus_tproxyport)
	mcdp=$(get merlinclash_cus_dnslistenport)	
	mcdbp=$(get merlinclash_cus_dashboardport)
	if [ "$mcc" == "1" ]; then
		echo_date "应用自定义端口设置" >> $LOG_FILE
		sed -i "s/^port: 3333/port: $mcp/g" $yamlpath
		echo_date 修改port为：$mcp	>> $LOG_FILE
		sed -i "s/^socks-port: 23456/socks-port: $mcsp/g" $yamlpath
		echo_date 修改socks-port为：$mcsp >> $LOG_FILE
		sed -i "s/^redir-port: 23457/redir-port: $mcrp/g" $yamlpath
		echo_date 修改redir-port为：$mcrp >> $LOG_FILE
		sed -i "s/^tproxy-port: 23458/tproxy-port: $mctp/g" $yamlpath
		echo_date 修改tproxy-port为：$mctp >> $LOG_FILE
		sed -i "s/listen: 0.0.0.0:23453/listen: 0.0.0.0:$mcdp/g" $yamlpath
		echo_date 修改dns监听端口为：$mcdp >> $LOG_FILE
		echo_date "当前管理面板访问端口为：$ecport" >> $LOG_FILE
		sed -i "s/external-controller: $lan_ipaddr:$ecport/external-controller: $lan_ipaddr:$mcdbp/g" $yamlpath
		echo_date 修改管理面板访问端口为：$mcdbp >> $LOG_FILE
	else
		echo_date "应用默认端口设置" >> $LOG_FILE
	fi
	mds=$(get merlinclash_dashboard_secret)
	secret=$(cat $yamlpath | awk '/secret:/{print $2}' | xargs echo -n)
	sed -i "s/^secret: \"clash\"/secret: \"$mds\"/g" $yamlpath
	echo_date 修改管理面板密码为：$mds >> $LOG_FILE
	#设置mark值
	mcrm=$(get merlinclash_cus_routingmark)
	routing_mark=$(cat $yamlpath | awk '/routing-mark:/{print $2}' | xargs echo -n)
	sed -i "s/^routing-mark: \"255\"/routing-mark: \"$mds\"/g" $yamlpath
	echo_date "设置路由流量标记值(Routing-Mark)为：$mcrm" >> $LOG_FILE

	#端口取值
	port=$(cat $yamlpath | awk -F: '/^port/{print $2}' | xargs echo -n)
	socksport=$(cat $yamlpath | awk -F: '/^socks-port/{print $2}' | xargs echo -n)
	proxy_port=$(cat $yamlpath | awk -F: '/^redir-port/{print $2}' | xargs echo -n)
	tproxy_port=$(cat $yamlpath | awk -F: '/^tproxy-port/{print $2}' | xargs echo -n)
	ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}' | xargs echo -n)
	dnslistenport=$(cat $yamlpath | awk -F: '/listen/{print $3}' | xargs echo -n)
}


check_dnsplan(){
	#echo_date "当前dns方案是$dnsplan"
	#插入换行符免得出错
	sed -i '$a' $yamlpath
	case $dnsplan in
	rh)
		local dnsTag=$(dbus get merlinclash_dnsedit_tag)
		local yamlTmpName="redirhost.yaml"
		if [ "$dnsTag" = "rhbypass" ];then
			yamlTmpName="rhbypass.yaml"
		fi
		#默认方案
		echo_date "使用DNS方案为：Redir-Host" >> $LOG_FILE
		if [ "$d2s" == "0" ]; then
			cat /jffs/softcenter/merlinclash/yaml_dns/$yamlTmpName >> $yamlpath
		else
			echo_date "Dns2Socks开启，修改配置文件的fallback设置" >> $LOG_FILE
			cat /jffs/softcenter/merlinclash/yaml_dns/redirhost.yaml> /tmp/rh_tmp.yaml
			yq d -i /tmp/rh_tmp.yaml dns.fallback
			yq w -i /tmp/rh_tmp.yaml dns.fallback[+] "127.0.0.1:${d2s_lp}"
			cat /tmp/rh_tmp.yaml >> $yamlpath
			rm -rf /tmp/rh_tmp.yaml
		fi
		;;
	fi)
		#fake-ip方案，将/jffs/softcenter/merlinclash/上传文件名.yaml 跟 fakeip.yaml 合并
		echo_date "使用DNS方案为：Fake-IP" >> $LOG_FILE
		if [ "$d2s" == "0" ]; then 
			cat /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml >> $yamlpath
		else
			echo_date "Fake-IP不支持Dns2Socks，关闭Dns2Socks设置" >> $LOG_FILE
			dbus set merlinclash_d2s=0
			cat /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml >> $yamlpath
		fi
		;;
	esac
	#启动时对控制面板IP重赋值，不需要重订阅 20210419
	sed -i "s/external-controller: $ecip:$ecport/external-controller: $lan_ipaddr:$ecport/g" $yamlpath
}
stop_config(){
	echo_date 触发脚本stop_config >> $LOG_FILE
	#关闭TCP Fast Open
	if [ "$LINUX_VER" != "26" ];then
		echo 1 >/proc/sys/net/ipv4/tcp_fastopen
	fi
	#ss_pre_stop
	# now stop first
	echo_date ======================= MERLIN CLASH ======================== >> $LOG_FILE
	echo_date
	echo_date --------------------------- 启动 ---------------------------- >> $LOG_FILE
	#stop_status 
	echo_date ---------------------- 结束相关进程-------------------------- >> $LOG_FILE
	echo_date ---------------------- 结束相关进程-------------------------- >> $SIMLOG_FILE
	kill_cron_job
	#if [ -f "/jffs/softcenter/merlinclash/koolproxy/koolproxy" ]; then
		sh /jffs/softcenter/scripts/clash_koolproxyconfig.sh stop
	#fi
	if [ -f "/jffs/softcenter/bin/UnblockNeteaseMusic" ]; then
		sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh stop
	fi
	dbus set merlinclash_enable="0"
	restart_dnsmasq
	kill_process
	echo_date -------------------- 相关进程结束完毕 -----------------------  >> $LOG_FILE
	echo_date ----------------------清除iptables规则----------------------- >> $LOG_FILE
	echo_date ----------------------清除iptables规则----------------------- >> $SIMLOG_FILE
	flush_nat
}
check_koolproxy(){
	if [ "$mcenable" == "1" ]; then
		if [ "$kpenable" == "1" ]; then
			echo_date "检测到KoolProxy开启，开始处理" >> $LOG_FILE	
			echo_date "检测到KoolProxy开启，开始处理" >> $SIMLOG_FILE	
			sh /jffs/softcenter/scripts/clash_koolproxyconfig.sh restart
			sleep 1s
		else
			echo_date "KoolProxy未开启" >> $LOG_FILE
			sh /jffs/softcenter/scripts/clash_koolproxyconfig.sh stop					
		fi
	fi	
}
check_unblockneteasemusic(){
	if [ "$mcenable" == "1" ]; then
		if [ "$umenable" == "1" ]; then
			echo_date "检测到开启网易云音乐本地解锁功能，开始处理" >> $LOG_FILE	
			echo_date "检测到开启网易云音乐本地解锁功能，开始处理" >> $SIMLOG_FILE	
			sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh restart
			sleep 1s
		else
			echo_date "网易云音乐本地解锁未开启" >> $LOG_FILE
			sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh stop					
		fi
	fi
}
auto_start() {
	echo_date "创建开机/iptable重启任务" >> $LOG_FILE
	[ ! -L "/jffs/softcenter/init.d/S99merlinclash.sh" ] && ln -sf /jffs/softcenter/merlinclash/clashconfig.sh /jffs/softcenter/init.d/S99merlinclash.sh
	[ ! -L "/jffs/softcenter/init.d/N99merlinclash.sh" ] && ln -sf /jffs/softcenter/merlinclash/clashconfig.sh /jffs/softcenter/init.d/N99merlinclash.sh
}
set_patchmode(){
	echo_date "设置模式" >> $LOG_FILE
	curl -sv -H "Authorization: Bearer $secret" -X PATCH "http://$lan_ipaddr:$ecport/configs/"  -d "{\"mode\": \"$modesel\"}" >/dev/null 2>&1 &
	echo_date "打断连接" >> $LOG_FILE
	curl -sv -H "Authorization: Bearer $secret" -X DELETE "http://$lan_ipaddr:$ecport/connections" >/dev/null 2>&1 &
	echo_date "设置完成" >> $LOG_FILE
}
apply_mc() {
	# router is on boot
	
	WAN_ACTION=`ps|grep /jffs/scripts/wan-start|grep -v grep`
	
	# now stop first
	echo_date ======================= MERLIN CLASH ======================== >> $LOG_FILE
	echo_date --------------------- 检查是否存冲突插件 ----------------------- >> $LOG_FILE
	check_ss
	echo_date ---------------------- 重启dnsmasq -------------------------- >> $LOG_FILE
	restart_dnsmasq
	echo_date ----------------------- 结束相关进程--------------------------- >> $LOG_FILE
	kill_process
	echo_date --------------------- 相关进程结束完毕 ------------------------ >> $LOG_FILE
	kill_cron_job
	echo_date -------------------- 检查配置文件是否存在 --------------------- >> $LOG_FILE
	check_yaml
	echo_date ""
	echo_date -------------------- 添加host区 开始-------------------------- >> $LOG_FILE
	start_host
	echo_date -------------------- 添加host区 结束-------------------------- >> $LOG_FILE
	echo_date ""
	echo_date -------------------- 添加Routing-Mark 开始-------------------------- >> $LOG_FILE
	start_routingmark
	echo_date -------------------- 添加Routing-Mark 结束-------------------------- >> $LOG_FILE
	echo_date ""
	echo_date ------------------------ 确认DNS方案 -------------------------- >> $LOG_FILE
	check_dnsplan
	echo_date -------------------- 自定义规则检查区 开始-------------------------- >> $LOG_FILE
	check_rule
	echo_date -------------------- 自定义规则检查区 结束-------------------------- >> $LOG_FILE
	echo_date ""
	echo_date -------------------- 自定义延迟容差值 开始-------------------------- >> $LOG_FILE
	set_Tolerance
	echo_date -------------------- 自定义延迟容差 结束-------------------------- >> $LOG_FILE
	echo_date ""
	# 清除iptables规则和ipset...
	echo_date --------------------- 清除iptables规则 开始------------------------ >> $LOG_FILE
	flush_nat
	echo_date --------------------- 清除iptables规则 结束------------------------ >> $LOG_FILE
	echo_date ""
	echo_date -------------------- 自定义参数区 开始-------------------------- >> $LOG_FILE
	check_coremark
	start_custom
	echo_date -------------------- 自定义参数区 结束-------------------------- >> $LOG_FILE
	echo_date ""
	echo_date --------------------- 创建相关ipset集 开始------------------------ >> $LOG_FILE
	creat_ipset
	echo_date --------------------- 创建相关ipset集 结束------------------------ >> $LOG_FILE
	echo_date ""
	echo_date --------------------- KoolProxy功能检查区 开始------------------------ >> $LOG_FILE
	check_koolproxy
	echo_date --------------------- KoolProxy功能检查区 结束------------------------ >> $LOG_FILE
	echo_date ""
	# 检测jffs2脚本是否开启
	detect
	#启动haveged，为系统提供更多的可用熵！
	set_sys
	echo_date ---------------------- 启动插件相关功能 ------------------------ >> $LOG_FILE
	start_clash
	echo_date ------------------------ 恢复记忆节点 开始---------------------- >> $LOG_FILE 
	start_remark
	echo_date ------------------------ 恢复记忆节点 结束---------------------- >> $LOG_FILE
	echo_date ""
	echo_date ------------------------ 运行模式设置 开始---------------------- >> $LOG_FILE 
	set_patchmode
	echo_date ------------------------ 运行模式设置 结束---------------------- >> $LOG_FILE
	echo_date ""
	echo_date --------------------- 创建router_ipset集 开始------------------------ >> $LOG_FILE
	creat_router_ipset
	echo_date --------------------- 创建router_ipset集 结束------------------------ >> $LOG_FILE
	echo_date ""
	[ "$closeproxy" == "0" ] && echo_date --------------------- 创建iptables规则 开始------------------------ >> $LOG_FILE
	[ "$closeproxy" == "0" ] && load_nat
	[ "$closeproxy" == "0" ] && echo_date --------------------- 创建iptables规则 结束------------------------ >> $LOG_FILE
	echo_date ""
	#----------------------------------KCP进程--------------------------------
	echo_date ---------------------- KCP设置检查区 开始 ------------------------ >> $LOG_FILE
	start_kcp
	echo_date ---------------------- KCP设置检查区 结束 ------------------------ >> $LOG_FILE
	#----------------------------------应用节点记忆----------------------------
	restart_dnsmasq
	#auto_start
	#watchdog
	#httpdwatchdog
	echo_date ---------------------- 节点后台记忆区 开始 ------------------------ >> $LOG_FILE
	write_setmark_cron_job
	echo_date ---------------------- 节点后台记忆区 结束 ------------------------ >> $LOG_FILE
	echo_date "" >>$LOG_FILE
	echo_date ---------------------- 定时订阅检查区 开始 ------------------------ >> $LOG_FILE
	write_regular_cron_job
	echo_date ---------------------- 定时订阅检查区 结束 ------------------------ >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date ---------------------- 定时重启检查区 开始 ------------------------ >> $LOG_FILE
	write_clash_restart_cron_job
	echo_date ---------------------- 定时重启检查区 结束 ------------------------ >> $LOG_FILE

	dnsmasqpid=$(pidof dnsmasq)
	for d in $dnsmasqpid; do
		procs=$((procs+1))  
	done
	echo_date "dnsmasq进程数量为：$procs个" >> $LOG_FILE
	if [ "$procs" -gt "1" ]; then
		service restart_dnsmasq >/dev/null 2>&1
	fi
    echo_date "" >> $LOG_FILE
	echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo_date "             +        管理面板：$lan_ipaddr:$ecport     +" >> $LOG_FILE
    echo_date "             +       Http代理：$lan_ipaddr:$httpport     +"  >> $LOG_FILE
    echo_date "             +      Socks代理：$lan_ipaddr:$socksport    +" >> $LOG_FILE
    echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
    echo_date "                     恭喜！开启MerlinClash成功！" >> $LOG_FILE
	echo_date "恭喜！开启MerlinClash成功！" >> $SIMLOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date   "如果不能科学上网，请刷新设备dns缓存，或者等待几分钟再尝试" >> $LOG_FILE
	echo_date "如果不能科学上网，请刷新设备dns缓存，或者等待几分钟再尝试" >> $SIMLOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date ==================== 【MERLIN CLASH】 启动完毕 ==================== >> $LOG_FILE
}

restart_mc_quickly(){
	echo_date ----------------------- 结束相关进程--------------------------- >> $LOG_FILE
	kill_clash
	echo_date ---------------------- 启动插件相关功能 ------------------------ >> $LOG_FILE
	start_clash && echo_date "start_clash" >> $LOG_FILE
	echo_date ------------------------ 恢复记忆节点 开始---------------------- >> $LOG_FILE 
	check_coremark
	start_remark
	echo_date ------------------------ 恢复记忆节点 结束---------------------- >> $LOG_FILE
	restart_dnsmasq
	#===load nat end===
	# 创建开机/IPT重启任务！
	#auto_start
	dnsmasqpid=$(pidof dnsmasq)
	for d in $dnsmasqpid; do
		procs=$((procs+1))  
	done
	echo_date "dnsmasq进程数量为：$procs个" >> $LOG_FILE
	if [ "$procs" -gt "1" ]; then
		service restart_dnsmasq >/dev/null 2>&1
	fi
    echo_date "" >> $LOG_FILE
	echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo_date "             +        管理面板：$lan_ipaddr:$ecport      +" >> $LOG_FILE
    echo_date "             +        Http代理：$lan_ipaddr:$httpport      +"  >> $LOG_FILE
    echo_date "             +       Socks代理：$lan_ipaddr:$socksport     +" >> $LOG_FILE
    echo_date "             ++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
    echo_date "                     恭喜！开启MerlinClash成功！" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date   "如果不能科学上网，请刷新设备dns缓存，或者等待几分钟再尝试" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	
	echo_date ==================== 【MERLIN CLASH】 启动完毕 ==================== >> $LOG_FILE	
}

open_port() {
	if [ ! -n "$ecport" ]; then
		ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}' | xargs echo -n)
	fi
 	local CM=$(lsmod | grep xt_comment)
	local OS=$(uname -r)
	if [ -z "${CM}" -a -f "/lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko" ];then
		insmod /lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko
	fi
	local lan_ipaddr=$(ifconfig br0|grep -Eo "inet addr.+"|awk -F ":| " '{print $3}' 2>/dev/null)
	echo_date "添加防火墙入站规则，打开控制面板端口： ${ecport}" >> $LOG_FILE
	local MATCH=$(iptables -t filter -S INPUT | grep -w "mcdash_rule")
	if [ -z "${MATCH}" ];then
		iptables -t filter -I INPUT -d ${lan_ipaddr} -p tcp -m conntrack --ctstate DNAT -m tcp --dport ${ecport} -j ACCEPT -m comment --comment "mcdash_rule" >/dev/null 2>&1
	fi

	local MATCH=$(iptables -t nat -S VSERVER | grep -w "mcdash_rule")
	if [ -z "${MATCH}" ];then
		iptables -t nat -I VSERVER -p tcp -m tcp --dport ${ecport} -j DNAT --to-destination ${lan_ipaddr}:${ecport} -m comment --comment "mcdash_rule" >/dev/null 2>&1
	fi

	local MATCH=$(ip6tables -t filter -S INPUT | grep -w "mcdash_rule")
	if [ -z "${MATCH}" ];then
		ip6tables -t filter -I INPUT -p tcp -m tcp --dport ${ecport} -j ACCEPT -m comment --comment "mcdash_rule" >/dev/null 2>&1
	fi
}

close_port(){
	echo_date "关闭控制面板端口..." >> $LOG_FILE
  	while [ $(iptables -t filter -S INPUT | grep -cw "mcdash_rule") -ge 1 ];
	do
		`iptables -t filter -S INPUT | grep -w "mcdash_rule" | sed 's/-A/iptables -t filter -D/g'` >/dev/null 2>&1
	done
	while [ $(iptables -t nat -S VSERVER | grep -cw "mcdash_rule") -ge 1 ];
	do
		`iptables -t nat -S VSERVER | grep -w "mcdash_rule" | sed 's/-A/iptables -t nat -D/g'` >/dev/null 2>&1
	done
	while [ $(ip6tables -t filter -S INPUT | grep -cw "mcdash_rule") -ge 1 ];
	do
		`ip6tables -t filter -S INPUT | grep -w "mcdash_rule" | sed 's/-A/ip6tables -t filter -D/g'` >/dev/null 2>&1
	done
}

case $ACTION in
prenetflix)
	pre_netflix_nslookup "back" >> $LOG_FILE
	;;
start)

	mkdir -p /tmp/lock
	logger "[软件中心-开机自启]: 开机启动MerlinClash插件！"
	echo_date "[软件中心-开机自启]: 开机启动MerlinClash插件！" >> $LOG_FILE
	echo_date "[软件中心-开机自启]: MerlinClash开关状态为：【$mcenable】" >> $LOG_FILE
	#set_lock
	if [ ! -n "$mcenable" ]; then	
		logger "[软件中心-开机自启]: MerlinClash开关状态获取失败，强制休眠120秒！"
		echo_date "[软件中心-开机自启]: MerlinClash开关状态获取失败，强制休眠120秒！" >> $LOG_FILE
		sleep 120s
		logger "[软件中心-开机自启]: 120秒休眠结束！退出脚本"
		echo_date "[软件中心-开机自启]: 120秒休眠结束！退出脚本" >> $LOG_FILE
		mcenable=$(get merlinclash_enable)
		exit 1
	fi
	if [ "$mcenable" == "1" ]; then
		logger "[软件中心-开机自启]: MerlinClash为开启状态"
		echo_date "[软件中心-开机自启]: MerlinClash为开启状态"  >> $LOG_FILE
		lf=$(get merlinclash_lockfile)
		lcfiletmp=/tmp/lock/$lf.txt
		echo_date "[软件中心-开机自启]: 前一进程锁文件:$lcfiletmp"  >> $LOG_FILE

		lc=$$	
		merlinclash_lockfile="$lc"
		dbus set merlinclash_lockfile="$merlinclash_lockfile"
		lcfile1=/tmp/lock/$lc.txt
		echo_date "[软件中心-开机自启]: 触发重启任务pid:$lc"  >> $LOG_FILE
		
		echo_date "[软件中心-开机自启]: 创建本重启进程锁文件${lcfile1}" >> $LOG_FILE 
		touch $lcfile1
		
		i=60

		echo_date "[软件中心-开机自启]: 将本任务pid写入lockfile:$merlinclash_lockfile" >> $LOG_FILE
		echo $$ > ${lcfile1}

		while [ $i -ge 0 ]; do
			if [ -e ${lcfiletmp} ] && kill -0 `cat ${lcfiletmp}`; then 
				echo_date "[软件中心-开机自启]: $merlinclash_lockfile 锁进程中" >> $LOG_FILE
				echo $$ > ${lcfile1}
				sleep 5s
			else
				let i=0
				echo_date "[软件中心-开机自启]: 上个重启进程文件锁解除" >> $LOG_FILE
			fi
			let i--
		done
		
		# 确保退出时，锁文件被删除 
		trap "rm -rf ${lcfile1}; exit" INT TERM EXIT 
		
		echo $$ > ${lcfile1} 
		echo_date "[软件中心-开机自启]: 2次创建本重启进程锁文件${lcfile1}" >> $LOG_FILE
		apply_mc >>"$LOG_FILE"
	else
		logger "[软件中心-开机自启]: MerlinClash插件未开启，不启动！"
		echo_date "[软件中心-开机自启]: MerlinClash插件未开启，不启动！" >> $LOG_FILE
	fi
	rm -rf ${lcfile1} 
	;;
upload)
	move_config >>"$LOG_FILE"
	http_response 'success'
	;;
stop)
	set_lock
	stop_config
	echo_date >> $LOG_FILE
	echo_date 你已经成功关闭Merlin Clash~ >> $LOG_FILE
	echo_date 你已经成功关闭Merlin Clash~ >> $SIMLOG_FILE
	echo_date See you again! >> $LOG_FILE
	echo_date >> $LOG_FILE
	echo_date ======================= Merlin Clash ======================== >> $LOG_FILE
	echo_date ======================= Merlin Clash ======================== >> $SIMLOG_FILE
	unset_lock
	;;
restart)
	#set_lock
	mkdir -p /tmp/lock
	lf=$(get merlinclash_lockfile)
	lcfiletmp=/tmp/lock/$lf.txt
	echo_date "[应用启动]: 前一进程锁文件:$lcfiletmp"  >> $LOG_FILE
	lc=$$	
	merlinclash_lockfile="$lc"
	dbus set merlinclash_lockfile="$merlinclash_lockfile"
	lcfile1=/tmp/lock/$lc.txt
	echo_date "[应用启动]: 触发启动任务pid:$lc"  >> $LOG_FILE
	echo_date "[应用启动]: 触发启动任务pid:$lc"  >> $SIMLOG_FILE
	echo_date "[应用启动]: 创建本启动进程锁文件${lcfile1}" >> $LOG_FILE 
	touch $lcfile1
	
	i=60
	echo_date "[应用启动]: 将本任务pid写入lockfile:$merlinclash_lockfile" >> $LOG_FILE
	echo $$ > ${lcfile1}

	while [ $i -ge 0 ]; do
		if [ -e ${lcfiletmp} ] && kill -0 `cat ${lcfiletmp}`; then 
			echo_date "[应用启动]: $merlinclash_lockfile 锁进程中" >> $LOG_FILE
			echo $$ > ${lcfile1}
			sleep 5s
		else
			let i=0
			echo_date "[应用启动]: 上个启动进程文件锁解除" >> $LOG_FILE
		fi
		let i--
	done
		
	# 确保退出时，锁文件被删除 
	trap "rm -rf ${lcfile1}; exit" INT TERM EXIT 
		
	echo $$ > ${lcfile1} 
	echo_date "[应用启动]: 2次创建本启动进程锁文件${lcfile1}" >> $LOG_FILE
	apply_mc
	#echo_date >> $LOG_FILE
	#echo_date "Across the Great Wall we can reach every corner in the world!" >> $LOG_FILE
	#echo_date >> $LOG_FILE
	#echo_date ======================= Merlin Clash ======================== >> $LOG_FILE
	#unset_lock
	rm -rf ${lcfile1} 
	;;
quicklyrestart)
	#set_lock
	mkdir -p /tmp/lock
	lf=$(get merlinclash_lockfile)
	lcfiletmp=/tmp/lock/$lf.txt
	echo_date "[快速重启]: 前一进程锁文件:$lcfiletmp"  >> $LOG_FILE
	lc=$$	
	merlinclash_lockfile="$lc"
	dbus set merlinclash_lockfile="$merlinclash_lockfile"
	lcfile1=/tmp/lock/$lc.txt
	echo_date "[快速重启]: 触发重启任务pid:$lc"  >> $LOG_FILE
	
	echo_date "[快速重启]: 创建本重启进程锁文件${lcfile1}" >> $LOG_FILE 
	touch $lcfile1
	
	i=60
	echo_date "[快速重启]: 将本任务pid写入lockfile:$merlinclash_lockfile" >> $LOG_FILE
	echo $$ > ${lcfile1}

	while [ $i -ge 0 ]; do
		if [ -e ${lcfiletmp} ] && kill -0 `cat ${lcfiletmp}`; then 
			echo_date "[快速重启]: $merlinclash_lockfile 锁进程中" >> $LOG_FILE
			echo $$ > ${lcfile1}
			sleep 5s
		else
			let i=0
			echo_date "[快速重启]: 上个重启进程文件锁解除" >> $LOG_FILE
		fi
		let i--
	done
		
	# 确保退出时，锁文件被删除 
	trap "rm -rf ${lcfile1}; exit" INT TERM EXIT 
		
	echo $$ > ${lcfile1} 
	echo_date "[快速重启]: 2次创建本重启进程锁文件${lcfile1}" >> $LOG_FILE
	restart_mc_quickly
	#echo_date >> $LOG_FILE
	#echo_date "Across the Great Wall we can reach every corner in the world!" >> $LOG_FILE
	#echo_date >> $LOG_FILE
	#echo_date ======================= Merlin Clash ======================== >> $LOG_FILE
	#unset_lock
	rm -rf ${lcfile1} 	
	;;
start_nat)
	mkdir -p /tmp/lock

  echo_date "============= Merlin Clash iptable 重写开始=============" >> $LOG_FILE
	lf=$(get merlinclash_lockfile)
	lcfiletmp=/tmp/lock/$lf.txt
	echo_date "[软件中心-NAT重启]: 前一进程锁文件:$lcfiletmp"  >> $LOG_FILE

	lc=$$	
	merlinclash_lockfile="$lc"
	dbus set merlinclash_lockfile="$merlinclash_lockfile"
	lcfile1=/tmp/lock/$lc.txt
	echo_date "[软件中心-NAT重启]: 触发重启任务pid:$lc"  >> $LOG_FILE
		
	echo_date "[软件中心-NAT重启]: 创建本重启进程锁文件${lcfile1}" >> $LOG_FILE 
	touch $lcfile1
		
	i=60

	echo_date "[软件中心-NAT重启]: 将本任务pid写入lockfile:$merlinclash_lockfile" >> $LOG_FILE
	echo $$ > ${lcfile1}
		

	while [ $i -ge 0 ]; do
		if [ -e ${lcfiletmp} ] && kill -0 `cat ${lcfiletmp}`; then 
			echo_date "[软件中心-NAT重启]: $merlinclash_lockfile 锁进程中" >> $LOG_FILE
			sleep 5s
		else
			let i=0
			echo_date "[软件中心-NAT重启]: 上个重启进程文件锁解除" >> $LOG_FILE
		fi
		let i--
	done
		
	# 确保退出时，锁文件被删除 
	trap "rm -rf ${lcfile1}; exit" INT TERM EXIT 
		
	echo $$ > ${lcfile1}
	echo_date "[软件中心-NAT重启]: 2次创建本重启进程锁文件${lcfile1}" >> $LOG_FILE 
	sleep 1s
	
		
	#初始化iptables，防止重复数据写入
	echo_date --------------------- 清除iptables规则 开始------------------------ >> $LOG_FILE
	flush_nat
	echo_date --------------------- 清除iptables规则 结束------------------------ >> $LOG_FILE
	echo_date ""
	mcrm=$(get merlinclash_cus_routingmark)
	   echo_date ""
	echo_date --------------------- 创建相关ipset集 开始------------------------ >> $LOG_FILE
	creat_ipset
	echo_date --------------------- 创建相关ipset集 结束------------------------ >> $LOG_FILE
	echo_date ""
	echo_date --------------------- KoolProxy功能检查区 开始------------------------ >> $LOG_FILE
	#写入koolproxy iptables
	if [ "$kpenable" == "1" ]; then
		sh /jffs/softcenter/scripts/clash_koolproxyconfig.sh restart
	fi
	echo_date --------------------- KoolProxy功能检查区 结束------------------------ >> $LOG_FILE
	echo_date ""
	echo_date --------------------- 创建router_ipset集 开始------------------------ >> $LOG_FILE
	creat_router_ipset
	echo_date --------------------- 创建router_ipset集 结束------------------------ >> $LOG_FILE
	echo_date ""
	[ "$closeproxy" == "0" ] && echo_date --------------------- 创建iptables规则 开始------------------------ >> $LOG_FILE
	[ "$closeproxy" == "0" ] && load_nat
	[ "$closeproxy" == "0" ] && echo_date --------------------- 创建iptables规则 结束------------------------ >> $LOG_FILE
	echo_date ""
	restart_dnsmasq
	echo_date "============= Merlin Clash iptable 重写完成=============" >> $LOG_FILE
	rm -rf ${lcfile1} 
	echo_date "=================  Merlin Clash iptable 重写结束 =================" >> $LOG_FILE
	;;
esac
