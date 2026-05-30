#!/bin/sh

source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
ipv6_flag="0"
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')

ipv6_mode(){
	[ -n "$(ip addr | grep -w inet6 | awk '{print $2}')" ] && echo true || echo false
}

mcipv6=$(get merlinclash_ipt_ipv6_sw)
mcv=$(get merlinclash_binary_ver)
mtm=$(get merlinclash_ipt_tproxy_type)

dgc=$(get merlinclash_ipt_proxyrouter_sw)
echo_version() {
	if [ "$mcipv6" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
	fi
	echo_date
	SOFVERSION=$(cat /jffs/softcenter/merlinclash/version)
	
	
	echo ① 程序版本（插件版本：$SOFVERSION）：
	echo -----------------------------------------------------------
	echo "程序			版本		备注"
	echo "内核		$mcv"
	echo -----------------------------------------------------------
}

check_status() {
	#echo
	pid_clash=$(pidof clash)
	watchdog=$(ps | grep clash_dog.sh | grep -v grep)
	echo_version
	echo
	echo ② 检测当前相关进程工作状态：（你正在使用clash）
	echo -----------------------------------------------------------
	echo "程序		状态	PID"
	[ -n "$pid_clash" ] && echo "内核		工作中	pid：$pid_clash" || echo "内核		未运行"
	[ -n "$watchdog" ] && echo "进程守护		工作中	" || echo "进程守护		未运行"
	echo -----------------------------------------------------------
	echo
	echo ③ 检测iptables工作状态：
	echo ------------------------------------------------------ nat表 PREROUTING 链 ---------------------------------------------------------
	iptables -nvL PREROUTING -t nat --line-number
	echo ------------------------------------------------------- nat表 OUTPUT 链 ------------------------------------------------------------
	iptables -nvL OUTPUT -t nat --line-number
	echo
	echo ---------------------------------------------------------- MerlinClash -------------------------------------------------------------
	echo
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && echo ------------------------------------------------------ nat表 merlinclash 链 ---------------------------------------------------------
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && iptables -nvL merlinclash -t nat --line-number
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && echo ----------------------------------------------------- nat表 merlinclash_NOR 链 --------------------------------------------------------
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && iptables -nvL merlinclash_NOR -t nat --line-number
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && echo ----------------------------------------------------- nat表 merlinclash_CHN 链 --------------------------------------------------------
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && iptables -nvL merlinclash_CHN -t nat --line-number
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && echo ----------------------------------------------------- nat表 merlinclash_EXT 链 --------------------------------------------------------
	[ "$mtm" == "closed" ] || [ "$mtm" == "udp" ] && iptables -nvL merlinclash_EXT -t nat --line-number
	[ "$dgc" == "1" ] && echo ----------------------------------------------------- nat表 merlinclash_OUTPUT 链 --------------------------------------------------------
	[ "$dgc" == "1" ] && iptables -nvL merlinclash_OUTPUT -t nat --line-number
	[ "$mtm" != "closed" ] && echo ------------------------------------------------------ mangle表 PREROUTING 链 ---------------------------------------------------------
	[ "$mtm" != "closed" ] && iptables -nvL PREROUTING -t mangle --line-number
	[ "$mtm" != "closed" ] && echo -------------------------------------------------------- mangle表 OUTPUT 链 -----------------------------------------------------------
	[ "$mtm" != "closed" ] && iptables -nvL OUTPUT -t mangle --line-number
	[ "$mtm" != "closed" ] && echo ------------------------------------------------------ mangle表 merlinclash 链 ---------------------------------------------------------
	[ "$mtm" != "closed" ] && iptables -nvL merlinclash -t mangle --line-number
	[ "$mtm" != "closed" ] && echo ----------------------------------------------------- mangle表 merlinclash_PREROUTING 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && iptables -nvL merlinclash_PREROUTING -t mangle --line-number
	[ "$mtm" != "closed" ] && echo ----------------------------------------------------- mangle表 merlinclash_divert 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && iptables -nvL merlinclash_divert -t mangle --line-number
	[ "$mtm" != "closed" ] && [ "$dgc" == "1" ] && echo ----------------------------------------------------- mangle表 merlinclash_OUTPUT 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$dgc" == "1" ] && iptables -nvL merlinclash_OUTPUT -t mangle --line-number
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo ---------------------------------------------------------- MerlinClash-ipv6 -------------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo ------------------------------------------------------ ipv6-mangle表 PREROUTING 链 ---------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && ip6tables -nvL PREROUTING -t mangle --line-number
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo -------------------------------------------------------- ipv6-mangle表 OUTPUT 链 -----------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ])  && ip6tables -nvL OUTPUT -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && echo ------------------------------------------------------ ipv6-mangle表 merlinclash 链 ---------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && ip6tables -nvL merlinclash -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_PREROUTING 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && ip6tables -nvL merlinclash_PREROUTING -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && [ "$dgc" == "1" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_OUTPUT 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && [ "$dgc" == "1" ] && ip6tables -nvL merlinclash_OUTPUT -t mangle --line-number
	echo -----------------------------------------------------------------------------------------------------------------------------------
	echo
}

if [ "$merlinclash_enable" == "1" ]; then
	check_status >/tmp/upload/clash_proc_status.txt 2>&1
else
	echo 插件尚未启用！ >/tmp/upload/clash_proc_status.txt 2>&1
fi

http_response $1

