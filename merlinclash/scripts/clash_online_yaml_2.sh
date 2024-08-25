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
subscription_type=""
dictionary=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
updateflag=""

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
mcflag=$(get merlinclash_flag)
Regularlog=/tmp/upload/merlinclash_regular.log
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
	local_domain=$(nvram get local_domain)
	updateflag="start_online_update"
	links2=$(get merlinclash_links2)
	links=$(decode_url_link $links2)
	merlinc_link=$(echo $links | sed 's/%0A/%7C/g')
	subscription_type="2"
	upname_tmp=$(get merlinclash_uploadrename2)
		#echo_date "订阅文件重命名为：$upname_tmp" >> $LOG_FILE
	time=$(date "+%Y%m%d-%H%M%S")
	newname=$(echo $time | awk -F'-' '{print $2}')
	echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
	sleep 3s
	_name="Ne_"
#华硕安全措施禁止curl访问非域名
#	links="http://127.0.0.1:25500/sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2FZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	links="http://${local_domain}:25500/sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2FZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	echo_date "生成订阅链接：$links" >> $LOG_FILE
	if [ -n "$upname_tmp" ]; then
		upname="$_name$upname_tmp.yaml"
	else
		upname="$_name$newname.yaml"
	fi
			UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
			echo_date "使用常规网络下载..." >> $LOG_FILE
			curl -4sSk --user-agent "$UA" --connect-timeout 30 "$links" $upname
			echo_date "配置文件下载完成" >>$LOG_FILE
			#虽然为0但是还是要检测下是否下载到正确的内容
			if [ "$?" == "0" ];then
				#下载为空...
				if [ -z "$(cat /tmp/upload/$upname)" ]; then
					echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
					rm /tmp/upload/$upname
					wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
				fi
				echo_date "检查文件完整性" >> $LOG_FILE
				if [ -z "$(cat /tmp/upload/$upname)" ];then 
					echo_date "获取clash配置文件失败！" >> $LOG_FILE
					failed_warning_clash
				else
					echo_date "检查下载是否正确" >> $LOG_FILE
					local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
					local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
					local blakflg="0"				
					if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
						echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
						echo_date "curl下载出错，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					
					#下载为空...
					if [ -z "$(cat /tmp/upload/$upname)" ]; then
						echo_date "下载内容为空..." >> $LOG_FILE
						failed_warning_clash
					fi
					echo_date "已获取clash配置文件" >> $LOG_FILE
					echo_date "yaml文件合法性检查" >> $LOG_FILE	
					check_yamlfile
					if [ $? == "1" ]; then
					#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
						echo_date "执行yaml文件处理工作" >> $LOG_FILE
						sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
						#20200803写入字典
						write_dictionary
						echo_date "订阅完成" >> $LOG_FILE
					else
						echo_date "yaml文件格式不合法" >> $LOG_FILE
					fi
				fi
			else
				echo_date "下载超时" >> $LOG_FILE
				failed_warning_clash
			fi
	#fi
}

start_regular_update(){
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14}
	
	#merlinc_link=$3
	merlinc_link=""
	upname=""
	subscription_type=""
	local_domain=$(nvram get local_domain)
	merlinc_link=$(echo $3 | sed 's/%0A/%7C/g')
	upname_tmp=$1
	subscription_type="2"

	echo_date "订阅地址是：$merlinc_link" >> $Regularlog
	echo_date "【配置名是：$upname_tmp】"  >> $Regularlog
	echo_date "subconverter进程：$(pidof subconverter)" >> $Regularlog
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $Regularlog
	sleep 3s
	_name="Ne_"
#华硕安全措施禁止curl访问非域名
#	links="http://127.0.0.1:25500/sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2FZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	links="http://${local_domain}:25500/sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2FZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	
	echo_date "生成订阅链接：$links" >> $Regularlog
	upname="${_name}${upname_tmp}.yaml"
	
	#wget下载文件
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
	UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
	echo_date "使用常规网络下载..." >> $Regularlog
	curl --user-agent "$UA" --connect-timeout 30 -s "$links" > /tmp/upload/$upname
	echo_date "配置文件下载完成" >>$Regularlog
	if [ "$?" == "0" ];then
		#下载为空...
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $Regularlog
			rm /tmp/upload/$upname
			wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
		fi
		echo_date "检查文件完整性" >> $Regularlog
		if [ -z "$(cat /tmp/upload/$upname)" ];then 
			echo_date "获取clash配置文件失败！" >> $Regularlog
			failed_warning_clash
		else
			echo_date "检查下载是否正确" >> $Regularlog
			local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
			local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
			local blakflg="0"				
			if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
				echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
				echo_date "curl下载出错，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "下载内容为空..." >> $Regularlog
				failed_warning_clash
	 	 	fi
			echo_date "已获取clash配置文件" >> $Regularlog
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
		fi
	else
		echo_date "下载超时" >> $Regularlog
		failed_warning_clash
	fi
}
start_online_update_384(){
	subcsel=$(get merlinclash_subconverter_addr_sel)
	if [ "$subcsel" == "custom" ]; then
		addr$(get merlinclash_subconverter_addr_cus)
	else
		addr=$(get merlinclash_subconverter_addr)
	fi
	updateflag="start_online_update"
	links2=$(get merlinclash_links2)
	links=$(decode_url_link $links2)
	merlinc_link=$(echo $links | sed 's/%0A/%7C/g')
	subscription_type="3"
	upname_tmp=$(get merlinclash_uploadrename2)

	time=$(date "+%Y%m%d-%H%M%S")
	newname=$(echo $time | awk -F'-' '{print $2}')
	#echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
	sleep 1s
	_name="Ne_"
	links="${addr}sub?target=clash&new_name=true&url=$merlinc_link&insert=fals&config=https%3a%2f%2fraw.githubusercontent.com%2fflyhigherpi%2fmerlinclash_clash_related%2fmaster%2fRule_config%2fZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	
	echo_date "生成订阅链接：$links" >> $LOG_FILE
	if [ -n "$upname_tmp" ]; then
		upname="$_name$upname_tmp.yaml"
	else
		upname="$_name$newname.yaml"
	fi
			#links="https://subcon.dlj.tf/sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=https%3A%2F%2Fraw.githubusercontent.com%2FACL4SSR%2FACL4SSR%2Fmaster%2FClash%2Fconfig%2FACL4SSR_Online.ini"
			#echo_date merlinclash_link=$merlinc_link >> $LOG_FILE
			#wget下载文件
			#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
			UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
			curl --user-agent "$UA" --connect-timeout 30 -s "$links" > /tmp/upload/$upname
			if [ "$?" == "0" ];then
				echo_date "检查文件完整性" >> $LOG_FILE
				if [ -z "$(cat /tmp/upload/$upname)" ];then 
					echo_date "获取clash配置文件失败！" >> $LOG_FILE
					failed_warning_clash
				else
					echo_date "检查下载是否正确" >> $LOG_FILE
					local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
					local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
					local blakflg="0"				
					if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
						echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
						echo_date "curl下载出错，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					echo_date "已获取clash配置文件" >> $LOG_FILE
					echo_date "yaml文件合法性检查" >> $LOG_FILE	
					check_yamlfile
					if [ $? == "1" ]; then
					#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
						echo_date "执行yaml文件处理工作" >> $LOG_FILE
						sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
						#20200803写入字典
						write_dictionary
						echo_date "订阅完成" >> $LOG_FILE
					else
						echo_date "yaml文件格式不合法" >> $LOG_FILE
					fi
				fi
			else
				echo_date "下载超时" >> $LOG_FILE
				failed_warning_clash
			fi
	#fi
}

start_regular_update_384(){
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14}
	merlinc_link=""
	upname=""
	subscription_type=""
	addr=""

	addr="$4"
	subscription_type="3"
	#merlinc_link=$3	
	merlinc_link=$(echo $3 | sed 's/%0A/%7C/g')
	upname_tmp=$1
	echo_date "订阅地址是：$merlinc_link" >> $Regularlog
	echo_date "【配置名是：$upname_tmp】" >> $Regularlog
	#echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $Regularlog
	sleep 1s
	_name="Ne_"
	links="${addr}sub?target=clash&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontent.com%2fflyhigherpi%2fmerlinclash_clash_related%2fmaster%2fRule_config%2fZHANG.ini&include=&exclude=&append_type=false&emoji=true&udp=false&fdn=true&sort=true&scv=false&tfo=false"
	
	echo_date "生成订阅链接：$links" >> $Regularlog
	upname="${_name}${upname_tmp}.yaml"
		
	#wget下载文件
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
	UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
	curl --user-agent "$UA" --connect-timeout 30 -s "$links" > /tmp/upload/$upname
	if [ "$?" == "0" ];then
		echo_date "检查文件完整性" >> $Regularlog
		if [ -z "$(cat /tmp/upload/$upname)" ];then 
			echo_date "获取clash配置文件失败！" >> $Regularlog
			failed_warning_clash
		else
			echo_date "检查下载是否正确" >> $Regularlog
			local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
			local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
			local blakflg="0"				
			if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
				echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
				echo_date "curl下载出错，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					#wget -t3 --no-check-certificate --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					#wget -t3 --timeout=30 -qO /tmp/upload/$upname "$links"	
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "下载内容为空..." >> $Regularlog
				failed_warning_clash
			fi
			echo_date "已获取clash配置文件" >> $Regularlog
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
		fi
	else
		echo_date "下载超时" >> $Regularlog
		failed_warning_clash
	fi
}
write_dictionary(){
	if [ "$subscription_type" == "2" ]; then
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" 
	else
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "none" "none" "none" "none" "none" "none" "none" "none" "none" "none" "none" "$addr"
 	fi
}


check_yamlfile(){
	/bin/sh /jffs/softcenter/scripts/clash_checkyaml.sh "/tmp/upload/$upname"
}

failed_warning_clash(){
	rm -rf /tmp/upload/$upname
	echo_date "本地获取文件失败！！！" >> $LOG_FILE
	#echo_date "因使用github远程规则，尝试使用redir-host+模式订阅" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $LOG_FILE
		killall subconverter >/dev/null 2>&1
	fi
	echo_date "===================================================================" >> $LOG_FILE
	echo BBABBBBC
	exit 1
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
17)
	#set_lock
	if [ "$mcflag" == "HND" ]; then
		echo "" > $LOG_FILE
		http_response "$1"
		echo_date "小白一键转换订阅" >> $LOG_FILE
		#20200802启动subconverter进程
		/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
		start_online_update >> $LOG_FILE
		sc_process=$(pidof subconverter)
		if [ -n "$sc_process" ]; then
			echo_date 关闭subconverter进程... >> $LOG_FILE
			killall subconverter >/dev/null 2>&1
		fi
		echo BBABBBBC >> $LOG_FILE
	else
		
		echo "" > $LOG_FILE
		http_response "$1"
		echo_date "小白一键转换订阅384" >> $LOG_FILE
		start_online_update_384 >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
	fi
	;;
2)
	echo_date "本地SC_小白订阅定时更新" >> $LOG_FILE
	echo_date "本地SC_小白订阅定时更新" >> $Regularlog
	echo_date "启动subconverter进程" >> $Regularlog
	/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
	#$name $type $link 
	#$1    $2    $3    
	start_regular_update "$1" "$2" "$3" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $Regularlog
		killall subconverter >/dev/null 2>&1
	fi
	echo_date "" >> $Regularlog

	#echo BBABBBBC >> $LOG_FILE
	;;
3)
	echo_date "ACL4SSR_小白订阅定时更新" >> $LOG_FILE
	echo_date "ACL4SSR_小白订阅定时更新" >> $Regularlog
	#$name $type $link $addr 
	#$1    $2    $3    $4
	start_regular_update_384 "$1" "$2" "$3" "$4" >> $LOG_FILE
	echo_date "" >> $Regularlog

	#echo BBABBBBC >> $LOG_FILE
	;;
esac

