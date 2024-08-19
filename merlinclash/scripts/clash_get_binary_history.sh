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
#CDN地址示例
#https://cdn.jsdelivr.net/gh/flyhigherpi/merlinclash_clash_related/clash_binary_history/clashP-armv8-2020.08.16/md5sum.txt         
url_back=""
yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml

UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36';
url_main="https://raw.githubusercontent.com/zusterben/plan_c/master/clash_binary_history"
url_cdn="https://raw.iqiq.io/zusterben/plan_c/master/clash_binary_history"

get_binary_history_cdn(){
    rm -rf /jffs/softcenter/merlinclash/clash_binary_history.txt
	rm -rf /tmp/upload/clash_binary_history.txt
	
    echo_date "从CDN地址下载Clash二进制文件列表..." >> $LOG_FILE	
    curl -4sk --connect-timeout 5 ${url_cdn}/clash_binary_history.txt > /tmp/upload/clash_binary_history.txt
	if [ "$?" == "0" ];then
		echo_date "检查文件完整性" >> $LOG_FILE
       		if [ -z "$(cat /tmp/upload/clash_binary_history.txt)" ];then 
			echo_date "获取Clash二进制文件列表失败！" >> $LOG_FILE
			failed_warning_clash
		fi
        #if [ -n "$(cat /tmp/upload/clash_binary_history.txt|grep "404")" ];then
		#	echo_date "error:404 | 获取clash版本文件失败！" >> $LOG_FILE
		#	failed_warning_clash
		#fi
		if [ -n "$(cat /tmp/upload/clash_binary_history.txt|grep "clash")" ];then
			echo_date "已获取服务器端Clash二进制文件列表" >> $LOG_FILE
			mv -f /tmp/upload/clash_binary_history.txt /jffs/softcenter/merlinclash/clash_binary_history.txt        
		else
			echo_date "获取Clash二进制文件列表失败！" >> $LOG_FILE
			failed_warning_clash
		fi
		
	else
		echo_date "获取Clash二进制文件列表失败！" >> $LOG_FILE
		failed_warning_clash
	fi
    
}
get_binary_history(){
    rm -rf /jffs/softcenter/merlinclash/clash_binary_history.txt
	rm -rf /tmp/upload/clash_binary_history.txt
	
    echo_date "下载Clash二进制文件列表..." >> $LOG_FILE	
    curl -4sk --connect-timeout 5 ${url_main}/clash_binary_history.txt > /tmp/upload/clash_binary_history.txt
	if [ "$?" == "0" ];then
		echo_date "检查文件完整性" >> $LOG_FILE
       	if [ -z "$(cat /tmp/upload/clash_binary_history.txt)" ];then 
			echo_date "获取Clash二进制文件列表失败！使用CDN地址下载" >> $LOG_FILE
			get_binary_history_cdn
		fi
        #if [ -n "$(cat /tmp/upload/clash_binary_history.txt|grep "404")" ];then
		#	echo_date "error:404 | 获取clash版本文件失败！" >> $LOG_FILE
		#	failed_warning_clash
		#fi
		if [ -n "$(cat /tmp/upload/clash_binary_history.txt|grep "clash")" ];then
			echo_date "已获取服务器端Clash二进制文件列表" >> $LOG_FILE
			mv -f /tmp/upload/clash_binary_history.txt /jffs/softcenter/merlinclash/clash_binary_history.txt        
		else
			echo_date "获取Clash二进制文件列表失败！使用CDN地址下载" >> $LOG_FILE
			get_binary_history_cdn
		fi
		
	else
		echo_date "获取Clash二进制文件列表失败！使用CDN地址下载" >> $LOG_FILE
		get_binary_history_cdn
	fi
    
}

failed_warning_clash(){
	rm -rf /jffs/softcenter/merlinclash/clash_binary_history.txt
	rm -rf /tmp/upload/clash_binary_history.txt
	echo_date "获取文件失败！！请检查网络！应该是raw.githubusercontent.com解析污染" >> $LOG_FILE
	echo_date "请尝试打开【高级模式】--【代理路由自身访问】！" >> $LOG_FILE
	echo_date "===================================================================" >> $LOG_FILE
	echo BBABBBBC
	exit 1
}

replace_clash_binary(){
	url_cdn=""
	echo_date "选中Clash二进制版本为：$(get merlinclash_clashbinarysel)" >> $LOG_FILE
	echo_date "开始替换处理" >> $LOG_FILE
	binarysel=$(get merlinclash_clashbinarysel)

	rm -rf /tmp/clash_binary
	mkdir -p /tmp/clash_binary && cd /tmp/clash_binary
	echo_date "从服务器1下载校验文件：md5sum.txt" >> $LOG_FILE
	wget --user-agent="$UA" --no-check-certificate --timeout=20 -qO - ${url_main}/$binarysel/md5sum.txt > /tmp/clash_binary/md5sum.txt

	if [ "$?" != "0" ];then
		echo_date "md5sum.txt下载失败！" >> $LOG_FILE
		md5sum_ok=0
	else
		md5sum_ok=1
		echo_date "md5sum.txt下载成功..." >> $LOG_FILE
	fi
	#20200818从cdn地址下载md5sum进行比对，决定二进制下载路径
	url_cdn="https://raw.githubusercontents.com/zusterben/plan_c/master/clash_binary_history"

	echo_date "从服务器2下载校验文件：md5sum.txt" >> $LOG_FILE
	wget --user-agent="$UA" --no-check-certificate --timeout=20 -qO - $url_cdn/$binarysel/md5sum.txt > /tmp/clash_binary/md5sum2.txt
	if [ "$?" != "0" ];then
		echo_date "md5sum2.txt下载失败！" >> $LOG_FILE
		md5sum2_ok=0
	else
		md5sum2_ok=1
		echo_date "md5sum2.txt下载成功..." >> $LOG_FILE
	fi

	if [ "$md5sum_ok" == "1" ] && [ "$md5sum2_ok" == "1" ]; then
		echo_date "对比md5sum与md5sum2" >> $LOG_FILE
		cd /tmp/clash_binary
		MD5_1=$(cat md5sum.txt|awk '{print $1}')
		MD5_2=$(cat md5sum2.txt|awk '{print $1}')
		if [ "$MD5_1"x = "$MD5_2"x ]; then
			echo_date "将从服务器2下载Clash二进制" >> $LOG_FILE
			down_flag=2
		fi

		if [ "$MD5_1"x != "$MD5_2"x ]; then
			echo_date "将从服务器1下载Clash二进制" >> $LOG_FILE
			down_flag=1
		fi	
	else
		down_flag=0
	fi
	
	echo_date "开始下载Clash二进制" >> $LOG_FILE
	
	if [ "$down_flag" == "0" ]; then
		
		wget --user-agent="$UA" --no-check-certificate --timeout=20 --tries=1 ${url_main}/$binarysel/clash
		#curl -4sSk --connect-timeout 20 $url_main/$binarysel/clash > /tmp/clash_binary/clash
		if [ "$?" != "0" ];then
			echo_date "Clash下载失败！" >> $LOG_FILE
			clash_ok=0
		else
			clash_ok=1
			echo_date "Clash程序下载成功..." >> $LOG_FILE
		fi
	fi

	if [ "$down_flag" == "1" ]; then
		
		wget --user-agent="$UA" --no-check-certificate --timeout=20 --tries=1 ${url_main}/$binarysel/clash
		#curl -4sSk --connect-timeout 20 $url_main/$binarysel/clash > /tmp/clash_binary/clash
		if [ "$?" != "0" ];then
			echo_date "Clash下载失败！" >> $LOG_FILE
			clash_ok=0
		else
			clash_ok=1
			echo_date "Clash程序下载成功..." >> $LOG_FILE
		fi
	fi

	if [ "$down_flag" == "2" ]; then
		wget --user-agent="$UA" --no-check-certificate --timeout=20 --tries=1 $url_cdn/$binarysel/clash
		#curl -4sSk --connect-timeout 20 $url_main/$binarysel/clash > /tmp/clash_binary/clash
		if [ "$?" != "0" ];then
			echo_date "Clash下载失败！" >> $LOG_FILE
			clash_ok=0
		else
			clash_ok=1
			echo_date "Clash程序下载成功..." >> $LOG_FILE
		fi
	fi

	if [ "$md5sum_ok" == "1" ] && [ "$clash_ok" == "1" ]; then
		check_md5sum
	else
		echo_date "下载失败，请检查你的网络！" >> $LOG_FILE
		 echo_date "请尝试打开【高级模式】--【代理路由自身访问】" >> $LOG_FILE
		echo_date "===================================================================" >> $LOG_FILE
		echo BBABBBBC
		exit 1
	fi
}

check_md5sum(){
	cd /tmp/clash_binary
	echo_date "校验下载的文件!" >> $LOG_FILE
	clash_LOCAL_MD5=$(md5sum clash|awk '{print $1}')
	clash_ONLINE_MD5=$(cat md5sum.txt|awk '{print $1}')
	if [ "$clash_LOCAL_MD5"x = "$clash_ONLINE_MD5"x ]; then
		echo_date "文件校验通过!" >> $LOG_FILE
		replace_binary
	else
		echo_date "校验未通过，下载文件不完整，请检查你的网络！" >> $LOG_FILE
		rm -rf /tmp/clash_binary/*
		echo_date "===================================================================" >> $LOG_FILE
		echo BBABBBBC
		exit 1
	fi
}
replace_binary(){
	echo_date "开始替换Clash二进制!" >> $LOG_FILE
	if [ "$(pidof clash)" ];then
		echo_date "为了保证更新正确，关闭Clash主进程... " >> $LOG_FILE
		echo_date "为了保证更新正确，关闭Clash看门狗... " >> $LOG_FILE
		sed -i '/clash_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		killall clash >/dev/null 2>&1
		move_binary
		sleep 1
		start_clash
	else
		move_binary
	fi
}

move_binary(){
	echo_date "检查空间" >> $LOG_FILE
	SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
	SPACE_NEED=$(du -s /tmp/clash_binary/clash | awk '{print $1}')
	if [ "$SPACE_NEED" -eq "0" ]; then
		echo_date "文件大小为0，异常" >> $LOG_FILE
		rm -rf /tmp/clash_binary/clash >/dev/null 2>&1
        sleep 1s
        echo BBABBBBC >> $LOG_FILE  
        exit 1
	else
		echo_date "文件大小大于0，通过检查" >> $LOG_FILE
	fi
	if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间满足，继续安装！ >> $LOG_FILE
		echo_date "开始替换Clash二进制文件... " >> $LOG_FILE
		mv /tmp/clash_binary/clash /jffs/softcenter/bin/clash
		chmod +x /jffs/softcenter/bin/clash
		local clashTmpV1=$(/jffs/softcenter/bin/clash -v 2>/dev/null | head -n 1 | cut -d " " -f2)
		local clashTmpV2=$(/jffs/softcenter/bin/clash -v 2>/dev/null | head -n 1 | cut -d " " -f3)
		if [ "$clashTmpV1" = "Meta" ];then
			clash_local_ver="$clashTmpV1 $clashTmpV2"; 
		else
			clash_local_ver=$clashTmpV1
		fi
		[ -n "$clash_local_ver" ] && dbus set merlinclash_clash_version="$clash_local_ver"
		echo_date "Clash二进制文件替换成功... " >> $LOG_FILE
	else
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 二进制需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
		echo_date 退出安装！ >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		rm -rf /tmp/clash_binary/clash
		exit 1
	fi
}

start_clash(){
	#echo_date "开启clash进程... " >> $LOG_FILE
	#cd /jffs/softcenter/bin
	#export GOGC=30
	#echo_date "启用$yamlname YAML配置" >> $LOG_FILE 
	#/jffs/softcenter/bin/clash -d /jffs/softcenter/merlinclash/ -f $yamlpath >/dev/null 2>/tmp/upload/clash_error.log &
	#local i=10
	#until [ -n "$clashPID" ]
	#do
	#	i=$(($i-1))
	#	clashPID=$(pidof clash)
	#	if [ "$i" -lt 1 ];then
	#		echo_date "clash进程启动失败！" >> $LOG_FILE
	#		close_in_five
	#	fi
	#	sleep 1
	#done
	#echo_date clash启动成功，pid：$clashPID >> $LOG_FILE
	echo_date "开启Clash进程... " >> $LOG_FILE
	/bin/sh /jffs/softcenter/merlinclash/clashconfig.sh restart
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
	sh /jffs/softcenter/merlinclash/clashconfig.sh stop
}

case $2 in
10)
	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "获取远程服务器Clash版本号" >> $LOG_FILE
	get_binary_history >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
11)
	echo "替换clash二进制" > $LOG_FILE
	http_response "$1"
	replace_clash_binary >> $LOG_FILE 2>&1
	echo BBABBBBC >> $LOG_FILE
	;;
esac
