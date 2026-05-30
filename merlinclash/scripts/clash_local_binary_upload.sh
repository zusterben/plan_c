#!/bin/sh
 
source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
upload_path=/tmp/upload

yamlname=$(get merlinclash_set_yamlsel_start)
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
			echo_date "上传内核二进制版本为：$clash_upload_ver" >> $LOG_FILE
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
			if [ "${merlinclash_enable}" == 1 ];then
				echo_date "为了保证更新正确，正在关闭插件... " >> $LOG_FILE
				sh /jffs/softcenter/scripts/clash_config.sh stop stop
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
	esac
}

move_binary(){
	case $1 in 
	clash)
		echo_date "开始替换Clash二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/bin/clash
		chmod +x /jffs/softcenter/bin/clash
		clash_local_ver=$(getClashVersion /jffs/softcenter/bin/clash)
		[ -n "$clash_local_ver" ] && dbus set merlinclash_binary_ver="$clash_local_ver"
		echo_date "Clash二进制上传完成... " >> $LOG_FILE
		;;
	subconverter)
		echo_date "开始替换Subconverter二进制文件... " >> $LOG_FILE
		mv $upload_file /jffs/softcenter/merlinclash/subconverter/subconverter
		chmod +x /jffs/softcenter/merlinclash/subconverter/subconverter
		echo_date "Subconverter二进制上传完成... " >> $LOG_FILE
		;;
	esac
	
}

start_clash(){
	echo_date "开启Clash进程... " >> $LOG_FILE
	dbus set merlinclash_enable="1"
	sh /jffs/softcenter/scripts/clash_config.sh restart restart
}

close_in_five() {
	echo_date "插件将在5秒后自动关闭！！"
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1
		echo_date $i
		let i--
	done
	sh /jffs/softcenter/scripts/clash_config.sh stop stop
}

case $2 in
12)
	set_lock
	echo_date ======================== 删除YAM配置 ======================== >> $LOG_FILE
	http_response "$1"
	local_binary_replace >> $LOG_FILE
	echo_date ======================== 删除YAM配置 ======================== >> $LOG_FILE
	unset_lock
	echo BBABBBBC >> $LOG_FILE	
	;;
esac

