#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

rm -rf /tmp/upload/merlinclash_log.txt
rm -rf /tmp/upload/*.yaml
LOCK_FILE=/var/lock/yaml_online_update.lock
flag=0
upname=""
upname_tmp=""
#subscription_type：1:Clash-Yaml配置下载 2:HND_小白订阅 3：384_小白订阅 4：HND_SC订阅 5:384_ACL订阅 
#subscription_type：6：HND_自定订阅 7：HND_远程订阅 8:384_远程订阅
subscription_type="1"
dictionary=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
updateflag=""
Regularlog=/tmp/upload/merlinclash_regular.log

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
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
		echo_date "【错误】固件缺少base64decode文件，无法正常订阅，直接退出" >> $LOG_FILE
		echo_date "解决办法请查看MerlinClash Wiki" >> $LOG_FILE
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


start_online_update(){
	updateflag="start_online_update"
	link1=$(get merlinclash_links)
	links=$(decode_url_link $link1)
	merlinc_link=$links
	LINK_FORMAT=$(echo "$merlinc_link" | grep -E "^http://|^https://")
	echo_date "订阅地址是：$LINK_FORMAT"
	if [ -z "$LINK_FORMAT" ]; then
		echo_date "订阅地址错误！检测到你输入的订阅地址并不是标准网址格式！"
		sleep 2
		echo_date "退出订阅程序" >> $LOG_FILE
	else
		upname_tmp=$(get merlinclash_uploadrename)
		
		time=$(date "+%Y%m%d-%H%M%S")
		newname=$(echo $time | awk -F'-' '{print $2}')
		if [ -n "$upname_tmp" ]; then
			upname=$upname_tmp.yaml
		else
			upname=$newname.yaml
		fi
		echo_date "上传文件重命名为：$upname" >> $LOG_FILE
		#echo_date merlinclash_link=$merlinc_link >> $LOG_FILE
		#wget下载文件
		#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
		echo_date "使用常规网络下载..." >> $LOG_FILE
		curl --user-agent 'clash' -4sSk --connect-timeout 20 $merlinc_link > /tmp/upload/$upname
		echo_date "配置文件下载完成" >>$LOG_FILE
		#虽然为0但是还是要检测下是否下载到正确的内容
		if [ "$?" == "0" ];then
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				#echo_date "下载内容为空..."
				echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
				rm /tmp/upload/$upname
				if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
					#wget --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
					wget --user-agent='clash' --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
				else
					#wget --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
					wget --user-agent='clash' -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
				fi
			else	
				#订阅地址有跳转
				local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
				if [ -n "$blank" ]; then
					echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $LOG_FILE
					rm /tmp/upload/$upname
					if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
						#wget --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
						wget --user-agent='clash' --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
					else
						#wget --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
						wget --user-agent='clash' -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
					fi
				fi
			fi
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "wget下载内容为空..." >> $LOG_FILE
				failed_warning_clash
			fi
		else
			echo_date "使用curl下载订阅失败，尝试更换wget进行下载..." >> $LOG_FILE
			rm /tmp/upload/$upname
			if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
				wget --user-agent='clash' --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
			else
				wget --user-agent='clash' --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
			fi

			if [ "$?" == "0" ]; then
				#下载为空...
				if [ -z "$(cat /tmp/upload/$upname)" ]; then
					echo_date "wget下载内容为空..." >> $LOG_FILE
					failed_warning_clash
				fi
			else
				echo_date "wget下载超时" >> $LOG_FILE
				echo_date "wget下载订阅失败..." >> $LOG_FILE
				failed_warning_clash
			fi
		fi
		echo_date "已获取Clash配置文件" >> $LOG_FILE
		echo_date "yaml文件合法性检查" >> $LOG_FILE
		check_yamlfile
		if [ $? == "1" ]; then
		#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
			echo_date "执行yaml文件预处理工作" >> $LOG_FILE
			sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
			#20200803写入字典
			echo_date "开始创建字典" >> $LOG_FILE
			write_dictionary
			echo_date "字典创建完成" >> $LOG_FILE	
			echo_date "订阅完成" >> $LOG_FILE				
		else
			echo_date "yaml文件格式不合法" >> $LOG_FILE
		fi		
	fi
}

start_regular_update(){
	updateflag="start_regular_update"
	merlinc_link=""
	upname=""
	subscription_type=""
	
	merlinc_link=$2
	upname=$1
	echo_date "【配置名是：$upname" >> $Regularlog
	upname=$upname.yaml
	subscription_type="1"
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
	echo_date "使用常规网络下载..." >> $Regularlog
	curl --user-agent 'clash' -4sSk --connect-timeout 20 $merlinc_link > /tmp/upload/$upname
	echo_date "订阅下载完成" >> $Regularlog
	#虽然为0但是还是要检测下是否下载到正确的内容
	if [ "$?" == "0" ];then
		#下载为空...
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			#echo_date "下载内容为空..."
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $Regularlog
			rm /tmp/upload/$upname
			if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
				#wget --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
				wget --user-agent='clash' --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"	
			else
				#wget --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
				wget --user-agent='clash' -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
			fi
		else	
			#订阅地址有跳转
			local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
			if [ -n "$blank" ]; then
				echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
					#wget --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
					wget --user-agent='clash' --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"	
				else
					#wget --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
					wget --user-agent='clash' -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
				fi
			fi
		fi
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			echo_date "wget下载内容为空..." >> $Regularlog
			failed_warning_clash
		fi
	else
		echo_date "使用curl下载订阅失败，尝试更换wget进行下载..." >> $Regularlog
		rm /tmp/upload/$upname
		if [ -n $(echo $merlinc_link | grep -E "^https") ]; then
			#wget --no-check-certificate --timeout=15 -qO /tmp/upload/$upname $merlinc_link
			wget --user-agent='clash' --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"	
		else
			#wget --timeout=15 -qO /tmp/upload/$upname $merlinc_link	
			wget --user-agent='clash' -t3 -T30 -4 -O /tmp/upload/$upname "$merlinc_link"
		fi
		if [ "$?" == "0" ]; then
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "wget下载内容为空..." >> $Regularlog
				failed_warning_clash
			fi
		else
			echo_date "wget下载超时" >> $Regularlog
			echo_date "wget下载订阅失败..." >> $Regularlog
			failed_warning_clash
		fi
	fi
	echo_date "已获取Clash配置文件" >> $Regularlog
	echo_date "yaml文件合法性检查" >> $Regularlog
	check_yamlfile
	if [ $? == "1" ]; then
	#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
		echo_date "执行yaml文件处理工作" >> $Regularlog
		sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
		#20200803写入字典
		#write_dictionary	
		echo_date "订阅完成" >> $Regularlog				
	else
		echo_date "yaml文件格式不合法" >> $Regularlog
	fi
}

write_dictionary(){
	/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" 
}

failed_warning_clash(){
	rm -rf /tmp/upload/$upname
	echo_date "获取文件失败！！请检查网络！" >> $LOG_FILE
	echo_date "===================================================================" >> $LOG_FILE
	echo BBABBBBC
	exit 1
}

check_yamlfile(){
	/bin/sh /jffs/softcenter/scripts/clash_checkyaml.sh "/tmp/upload/$upname"
}
set_lock(){
	exec 233>"$LOCK_FILE"
	flock -n 233 || {
		echo_date "订阅脚本已经在运行，请稍候再试！" >> $LOG_FILE	
		unset_lock
	}
}

unset_lock(){
	flock -u 233
	rm -rf "$LOCK_FILE"
}

case $2 in
2)
	#set_lock
	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "在线clash订阅" >> $LOG_FILE
	echo_date "clash订阅链接处理" >> $LOG_FILE
	start_online_update >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
	#unset_lock
	;;
1)
	echo_date "clash订阅定时更新" >> $LOG_FILE
	echo_date "clash订阅定时更新" >> $Regularlog
	start_regular_update "$1" "$3" >> $LOG_FILE
	echo_date "" >> $Regularlog
	#echo BBABBBBC >> $LOG_FILE
	;;
esac

