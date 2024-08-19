#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
ipv6_flag="0"
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
ipv6_mode(){
	[ -n "$(ip addr | grep -w inet6 | awk '{print $2}')" ] && echo true || echo false
}

mcipv6=$(get merlinclash_ipv6switch)
mcv=$(get merlinclash_clash_version)
#muv=$(get merlinclash_UnblockNeteaseMusic_version)
mkv=$(get merlinclash_koolproxy_version)
mkenable=$(get merlinclash_koolproxy_enable)
#muenable=$(get merlinclash_unblockmusic_enable)
mtm=$(get merlinclash_tproxymode)
d2s=$(get merlinclash_d2s)
dgc=$(get merlinclash_dnsgoclash)
echo_version() {
	if [ "$mcipv6" == "1" ] && [ $(ipv6_mode) == "true" ]; then
			ipv6_flag="1"
	fi
	echo_date
	SOFVERSION=$(cat /jffs/softcenter/merlinclash/version)
	
	
	echo ① 程序版本（插件版本：$SOFVERSION）：
	echo -----------------------------------------------------------
	echo "程序			版本		备注"
	echo "clash			$mcv"
	#echo "UnblockNeteaseMusic	$muv"
	echo "koolproxy		$mkv"
	echo "dns2socks		2.0"
	echo -----------------------------------------------------------
}

check_status() {
	#echo
	pid_clash=$(pidof clash)
	pid_d2s=$(pidof mc_dns2socks)
# 	watchdog=$(cru l | grep clash_watchdog |awk -F"#" '{print $2}')
    watchdog=$(ps | grep clash_dog.sh | grep -v grep)
	#pid_watchdog=$(ps | grep clash_watchdog.sh | grep -v grep | awk '{print $1}')
	DMQ=$(pidof dnsmasq)
	#kcp=$(pidof client_linux_arm64)
	#ubm=$(pidof UnblockNeteaseMusic)
	kp=$(pidof koolproxy)
	echo_version
	echo
	echo ② 检测当前相关进程工作状态：（你正在使用clash）
	echo -----------------------------------------------------------
	echo "程序		状态	PID"
	[ -n "$pid_clash" ] && echo "clash		工作中	pid：$pid_clash" || echo "clash		未运行"
	[ -n "$watchdog" ] && echo "进程守护		工作中	" || echo "进程守护		未运行"
	[ -n "$DMQ" ] && echo "dnsmasq		工作中	pid：$DMQ" || echo "dnsmasq		未运行"
	#[ -n "$kcp" ] && echo "kcp		工作中	pid：$kcp" || echo "kcp		未运行"
	#[ -n "$ubm" ] && echo "网易云音乐解锁	工作中	pid：$ubm" || echo "网易云音乐解锁	未运行"
	[ -n "$kp" ] && echo "KidsProtect	工作中	pid：$kp" || echo "KidsProtect	未运行"
	[ -n "$pid_d2s" ] && echo "Dns2Scosks	工作中	pid：$pid_d2s" || echo "Dns2Scosks	未运行"
	echo -----------------------------------------------------------
	echo
	echo ③ 检测iptbales工作状态：
	echo ------------------------------------------------------ nat表 PREROUTING 链 ---------------------------------------------------------
	iptables -nvL PREROUTING -t nat --line-number
	echo ------------------------------------------------------- nat表 OUTPUT 链 ------------------------------------------------------------
	iptables -nvL OUTPUT -t nat --line-number
	[ "$mkenable" == "1" ] && echo ----------------------------------------------------------- KOOLPROXY --------------------------------------------------------------
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KOOLPROXY 链 ----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KOOLPROXY -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KOOLPROXY_ACT 链 ----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KOOLPROXY_ACT -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo -------------------------------------------------------- nat表 KP_HTTP 链 ----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KP_HTTP -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KP_HTTPS 链 -----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KP_HTTPS -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KP_BLOCK_HTTP 链 -----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KP_BLOCK_HTTP -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KP_BLOCK_HTTPS 链 -----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KP_BLOCK_HTTPS -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	[ "$mkenable" == "1" ] && echo ------------------------------------------------------ nat表 KP_ALL_PORT 链 -----------------------------------------------------------
	[ "$mkenable" == "1" ] && iptables -nvL KP_ALL_PORT -t nat --line-number
	[ "$mkenable" == "1" ] && echo
	#[ "$mkenable" == "1" ] && echo ------------------------------------------------------ UnblockNeteaseMusic ---------------------------------------------------------
	#[ "$mkenable" == "1" ] && echo
	#[ "$muenable" == "1" ] && echo ------------------------------------------------------ nat表 cloud_music 链 ---------------------------------------------------------
	#[ "$muenable" == "1" ] && iptables -nvL cloud_music -t nat --line-number
	#[ "$muenable" == "1" ] && echo ------------------------------------------------------ nat表 UNM_service 链 ---------------------------------------------------------
	#[ "$muenable" == "1" ] && iptables -nvL UNM_service -t nat --line-number
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
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && echo ----------------------------------------------------- mangle表 merlinclash_PREROUTING 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && iptables -nvL merlinclash_PREROUTING -t mangle --line-number
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && echo ----------------------------------------------------- mangle表 merlinclash_divert 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && iptables -nvL merlinclash_divert -t mangle --line-number
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && echo ----------------------------------------------------- mangle表 merlinclash_NOR 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && iptables -nvL merlinclash_NOR -t mangle --line-number
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && echo ----------------------------------------------------- mangle表 merlinclash_CHN 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && iptables -nvL merlinclash_CHN -t mangle --line-number
	[ "$mtm" != "closed" ] && [ "$dgc" == "1" ] && echo ----------------------------------------------------- mangle表 merlinclash_OUTPUT 链 --------------------------------------------------------
	[ "$mtm" != "closed" ] && [ "$dgc" == "1" ] && iptables -nvL merlinclash_OUTPUT -t mangle --line-number
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo ---------------------------------------------------------- MerlinClash-ipv6 -------------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo ------------------------------------------------------ ipv6-mangle表 PREROUTING 链 ---------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && ip6tables -nvL PREROUTING -t mangle --line-number
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ]) && echo -------------------------------------------------------- ipv6-mangle表 OUTPUT 链 -----------------------------------------------------------
	[ "$ipv6_flag" == "1" ] || ([ $(ipv6_mode) == "true" ] && [ "${LINUX_VER}" -ge "41" ])  && ip6tables -nvL OUTPUT -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && echo ------------------------------------------------------ ipv6-mangle表 merlinclash 链 ---------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && ip6tables -nvL merlinclash -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_PREROUTING 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan1" ] && ip6tables -nvL merlinclash_PREROUTING -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_NOR 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && ip6tables -nvL merlinclash_NOR -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_CHN 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && [ "$merlinclash_iptablessel" == "fangan2" ] && ip6tables -nvL merlinclash_CHN -t mangle --line-number
	[ "$ipv6_flag" == "1" ] && [ "$dgc" == "1" ] && echo ----------------------------------------------------- ipv6-mangle表 merlinclash_OUTPUT 链 --------------------------------------------------------
	[ "$ipv6_flag" == "1" ] && [ "$dgc" == "1" ] && ip6tables -nvL merlinclash_OUTPUT -t mangle --line-number
	echo -----------------------------------------------------------------------------------------------------------------------------------
	echo
}

if [ "$merlinclash_enable" == "1" ]; then
	check_status >/tmp/upload/clash_proc_status.txt 2>&1
	#echo XU6J03M6 >> /tmp/upload/ss_proc_status.txt
else
	echo 插件尚未启用！ >/tmp/upload/clash_proc_status.txt 2>&1
fi

http_response $1
