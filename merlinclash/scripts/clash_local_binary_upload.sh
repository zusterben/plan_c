#!/bin/sh
 
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
upload_path=/tmp/upload

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
binary_type=$(get merlinclash_binary_type)
uploadname=$(get merlinclash_binary_type)
upload_file=/tmp/upload/$uploadname

getClashVersion(){
	binPath=$1

	local clashTmpV1=$($binPath -v 2>/dev/null | head -n 1 | cut -d " " -f2)
	local clashTmpV2=$($binPath -v 2>/dev/null | head -n 1 | cut -d " " -f3)
	if [ "$clashTmpV1" = "Meta" ];then
		clash_version="$clashTmpV1 $clashTmpV2"
	else
		clash_version=$clashTmpV1
	fi
	echo $clash_version
}

local_binary_replace(){
	chmod +x $upload_file
	case $binary_type in
	clash)
		clash_upload_ver=$(getClashVersion $upload_file)
		if [ -n "$clash_upload_ver" ]; then
			echo_date "上传Clash二进制版本为：$clash_upload_ver" >> $LOG_FILE
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "clash"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	subconverter)
		$upload_file  -v 2>/dev/null | head -n 1 | xargs killall subconverter > /tmp/sc.txt 2>&1
		sc_upload=$(cat /tmp/2.txt | grep verter)
		if [ -n "$sc_upload" ]; then
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "subconverter"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	koolproxy)
		kp_upload_ver=$($upload_file -v 2>/dev/null | head -n 1 | cut -d " " -f2)
		if [ -n "$kp_upload_ver" ]; then
			echo_date "上传Koolproxy二进制版本为：$kp_upload_ver" >> $LOG_FILE
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "koolproxy"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	UnblockNeteaseMusic)
		UNM_upload_ver=$($upload_file -v 2>/dev/null | head -n 1 | cut -d " " -f2)
		if [ -n "$UNM_upload_ver" ]; then
			echo_date "上传UnblockNeteaseMusic二进制版本为：$UNM_upload_ver" >> $LOG_FILE
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "UnblockNeteaseMusic"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	mc_dns2socks)
		d2s_upload_ver=$($upload_file -v 2>/dev/null | head -n 2 | cut -d " " -f2 | sed '/^$/d')
		if [ -n "$d2s_upload_ver" ]; then
			echo_date "上传Dns2socks二进制版本为：$d2s_upload_ver" >> $LOG_FILE
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "mc_dns2socks"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	client_linux)
		kcp_upload_ver=$($upload_file -v | grep kcptun)
		if [ -n "$kcp_upload_ver" ]; then
			echo_date "上传KCP二进制版本为：$kcp_upload_ver" >> $LOG_FILE
			echo_date "开始替换处理" >> $LOG_FILE
			replace_binary "kcp"
		else
			echo_date "上传的二进制不合法！！！" >> $LOG_FILE
		fi
		;;
	esac
}

replace_binary(){
	case $1 in
	clash)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/clash | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换clash二进制!" >> $LOG_FILE
			if [ "$(pidof clash)" ];then
				echo_date "为了保证更新正确，先关闭Clash主进程... " >> $LOG_FILE
				echo_date "为了保证更新正确，先关闭Clash看门狗..." >> $LOG_FILE
				sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
				killall clash >/dev/null 2>&1
				move_binary "clash"
				sleep 1
				start_clash
			else
				move_binary "clash"
			fi
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/clash
			exit 1
		fi
		;;
	subconverter)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/subconverter | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换Subconverter二进制!" >> $LOG_FILE
			move_binary "subconverter"
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/subconverter
			exit 1
		fi
		;;
	koolproxy)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/koolproxy | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换Koolproxy二进制!" >> $LOG_FILE
			if [ "$(pidof koolproxy)" ];then
				echo_date "为了保证更新正确，先关闭Clash主进程... " >> $LOG_FILE
				echo_date "为了保证更新正确，先关闭Clash看门狗..." >> $LOG_FILE
				sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
				killall koolproxy >/dev/null 2>&1
				move_binary "koolproxy"
				sleep 1
				start_clash
			else
				move_binary "koolproxy"
			fi
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/koolproxy
			exit 1
		fi
		;;
	UnblockNeteaseMusic)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/UnblockNeteaseMusic | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换UnblockNeteaseMusic二进制!" >> $LOG_FILE
			if [ "$(pidof UnblockNeteaseMusic)" ];then
				echo_date "为了保证更新正确，关闭UnblockNeteaseMusic... " >> $LOG_FILE
				killall UnblockNeteaseMusic >/dev/null 2>&1
				move_binary "UnblockNeteaseMusic"
				sleep 1
			else
				move_binary "UnblockNeteaseMusic"
			fi
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/UnblockNeteaseMusic
			exit 1
		fi
		;;
	mc_dns2socks)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/mc_dns2socks | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换Dns2socks二进制!" >> $LOG_FILE
			if [ "$(pidof mc_dns2socks)" ];then
				echo_date "为了保证更新正确，先关闭Clash主进程... " >> $LOG_FILE
				echo_date "为了保证更新正确，先关闭Clash看门狗..." >> $LOG_FILE
				sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
				killall clash >/dev/null 2>&1
				move_binary "mc_dns2socks"
				sleep 1
				start_clash
			else
				move_binary "mc_dns2socks"
			fi
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/mc_dns2socks
			exit 1
		fi
		;;
	kcp)
		echo_date "检查空间" >> $LOG_FILE
		SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
		SPACE_NEED=$(du -s /tmp/upload/client_linux | awk '{print $1}')
		if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
			echo_date "开始替换KCP二进制!" >> $LOG_FILE
			if [ "$(pidof client_linux)" ];then
				echo_date "为了保证更新正确，先关闭Clash主进程... " >> $LOG_FILE
				echo_date "为了保证更新正确，先关闭Clash看门狗..." >> $LOG_FILE
				sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
				killall clash >/dev/null 2>&1
				move_binary "kcp"
				sleep 1
				start_clash
			else
				move_binary "kcp"
			fi
		else
			echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
			echo_date 退出安装！ >> $LOG_FILE
			echo BBABBBBC >> $LOG_FILE
			rm -rf /tmp/upload/client_linux
			exit 1
		fi
		;;
	esac
}

move_binary(){
	case $1 in 
	clash)
		echo_date "开始替换Clash二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/bin/clash
		chmod +x /jffs/softcenter/bin/clash
		clash_local_ver=$(getClashVersion /jffs/softcenter/bin/clash)
		[ -n "$clash_local_ver" ] && dbus set merlinclash_clash_version="$clash_local_ver"
		echo_date "Clash二进制上传完成... " >> $LOG_FILE
		;;
	subconverter)
		echo_date "开始替换Subconverter二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/merlinclash/subconverter/subconverter
		chmod +x /jffs/softcenter/merlinclash/subconverter/subconverter
		echo_date "Subconverter二进制上传完成... " >> $LOG_FILE
		;;
	koolproxy)
		echo_date "开始替换Koolproxy二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/merlinclash/koolproxy/koolproxy
		chmod +x /jffs/softcenter/merlinclash/koolproxy/koolproxy
		kp_LOCAL_VER=$(/jffs/softcenter/merlinclash/koolproxy/koolproxy -v 2>/dev/null | head -n 1 | cut -d " " -f2)
		[ -n "$kp_LOCAL_VER" ] && dbus set merlinclash_koolproxy_version="$kp_LOCAL_VER"
		echo_date "Koolproxy二进制上传完成... " >> $LOG_FILE
		;;
	UnblockNeteaseMusic)
		echo_date "开始替换UnblockNeteaseMusic二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/bin/UnblockNeteaseMusic
		chmod +x /jffs/softcenter/bin/UnblockNeteaseMusic
		UNM_LOCAL_VER=$(/jffs/softcenter/bin/UnblockNeteaseMusic -v 2>/dev/null | head -n 1 | cut -d " " -f2)
		[ -n "$UNM_LOCAL_VER" ] && dbus set merlinclash_UnblockNeteaseMusic_version="$UNM_LOCAL_VER"
		echo_date "UnblockNeteaseMusic二进制上传完成... " >> $LOG_FILE
		
		mcenable=$(get merlinclash_enable)
		muenable=$(get merlinclash_unblockmusic_enable)
		if [ "$mcenable" == "1" ] && [ "$muenable" == "1" ]; then
			sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh restart
		fi
		;;
	mc_dns2socks)
		echo_date "开始替换Dns2socks二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/bin/mc_dns2socks
		chmod +x /jffs/softcenter/bin/mc_dns2socks
		echo_date "Dns2socks二进制上传完成... " >> $LOG_FILE
		;;
	kcp)
		echo_date "开始替换KCP二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/bin/client_linux
		chmod +x /jffs/softcenter/bin/client_linux
		kcp_LOCAL_VER=$(/jffs/softcenter/bin/client_linux -v 2>/dev/null | head -n 1 | cut -d " " -f3)
		[ -n "$kcp_LOCAL_VER" ] && dbus set merlinclash_kcp_version="$kcp_LOCAL_VER"
		echo_date "KCP二进制上传完成... " >> $LOG_FILE
		;;
	esac
	
}

start_clash(){
	echo_date "开启Clash进程... " >> $LOG_FILE

	/bin/sh /jffs/softcenter/scripts/clash_config.sh quicklyrestart quicklyrestart
	
}

close_in_five() {
	echo_date "插件将在5秒后自动关闭！！"
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1
		echo_date $i
		let i--
	done
	dbus set merlinclash_enable="0"
	mue=$(get merlinclash_unblockmusic_enable)
	if [ "$mue" == "1" ]; then
		sh /jffs/softcenter/scripts/clash_unblockneteasemusic.sh stop
	fi
	sh /jffs/softcenter/scripts/clash_config.sh start
}

case $2 in
12)
	echo "本地上传二进制替换" > $LOG_FILE
	http_response "$1"
	local_binary_replace >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
esac
