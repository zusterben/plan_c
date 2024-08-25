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

Regularlog=/tmp/upload/merlinclash_regular.log
#rm -rf $Regularlog
local_domain=$(nvram get local_domain)

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
mcflag=$(get merlinclash_flag)
URLflag=$(get merlinclash_customurl_cbox)
get_subcsel_name(){
	case "$1" in
		tshl)
			echo "天枢互联"
		;;
		id9)
			echo "品云"
		;;
		maoxiong)
			echo "猫熊"
		;;
		heroku)
			echo "HEROKU"
		;;
		custom)
			echo "自定义"
		;;
	esac
}	
get_acl4ssrsel_name() {
	case "$1" in
		ZHANG)
			echo "Merlin Clash_常规规则"
		;;
		ZHANG_NoAuto)
			echo "Merlin Clash_常规无测速"
		;;
		ZHANG_Media)
			echo "Merlin Clash_多媒体全量"
		;;
		ZHANG_Media_NoAuto)
			echo "Merlin Clash_多媒体全量无测速"
		;;
		ZHANG_Media_Area_UrlTest)
			echo "Merlin Clash_多媒体全量分地区测速"
		;;
		ZHANG_Media_Area_FallBack)
			echo "Merlin Clash_多媒体全量分地区故障转移"
		;;
		ACL4SSR_Online)
			echo "Online默认版_分组比较全"
		;;
		ACL4SSR_Online_AdblockPlus)
			echo "AdblockPlus_更多去广告"
		;;
		ACL4SSR_Online_NoAuto)
			echo "NoAuto_无自动测速"
		;;
		ACL4SSR_Online_NoReject)
			echo "NoReject_无广告拦截规则"
		;;
		ACL4SSR_Online_Mini)
			echo "Mini_精简版"
		;;
		ACL4SSR_Online_Mini_AdblockPlus)
			echo "Mini_AdblockPlus_精简版更多去广告"
		;;
		ACL4SSR_Online_Mini_NoAuto)
			echo "Mini_NoAuto_精简版无自动测速"
		;;
		ACL4SSR_Online_Mini_Fallback)
			echo "Mini_Fallback_精简版带故障转移"
		;;
		ACL4SSR_Online_Mini_MultiMode)
			echo "Mini_MultiMode_精简版自动测速故障转移负载均衡"
		;;
		ACL4SSR_Online_Full)
			echo "Full全分组_重度用户使用"
		;;
		ACL4SSR_Online_Full_NoAuto)
			echo "Full全分组_无自动测速"
		;;
		ACL4SSR_Online_Full_AdblockPlus)
			echo "Full全分组_更多去广告"
		;;
		ACL4SSR_Online_Full_Netflix)
			echo "Full全分组_奈飞全量"
		;;
		ACL4SSR_Online_Full_Google)
			echo "Full全分组_谷歌细分"
		;;
		ACL4SSR_Online_Full_MultiMode)
			echo "Full全分组_多模式"
		;;
		ACL4SSR_Online_Mini_MultiCountry)
			echo "Full全分组_多国家地区"
		;;
	esac
}

start_online_update_hnd(){
	clashtarget=$(get merlinclash_clashtarget)
	acl4ssrsel=$(get merlinclash_acl4ssrsel)
	emoji=$(get merlinclash_subconverter_emoji)
	udp=$(get merlinclash_subconverter_udp)
	xudp=$(get merlinclash_subconverter_xudp)
	appendtype=$(get merlinclash_subconverter_append_type)
	sort=$(get merlinclash_subconverter_sort)
	fnd=$(get merlinclash_subconverter_fdn)
	scv=$(get merlinclash_subconverter_scv)
	tfo=$(get merlinclash_subconverter_tfo)
	include=$(get merlinclash_subconverter_include)
	exclude=$(get merlinclash_subconverter_exclude)
	updateflag="start_online_update"
	customrule=$(get merlinclash_customrule_cbox)
	subscription_type="4"
	if [ "$emoji" == "1" ]; then
		emoji="true"
	else
		emoji="false"
	fi
	if [ "$udp" == "1" ]; then
		udp="true"
	else
		udp="false"
	fi
	if [ "$xudp" == "1" ]; then
		xudp="true"
	else
		xudp="false"
	fi
	if [ "$appendtype" == "1" ]; then
		appendtype="true"
	else
		appendtype="false"
	fi
	if [ "$sort" == "1" ]; then
		sort="true"
	else
		sort="false"
	fi
	if [ "$fnd" == "1" ]; then
		fnd="true"
	else
		fnd="false"
	fi
	if [ "$scv" == "1" ]; then
		scv="true"
	else
		scv="false"
	fi
	if [ "$tfo" == "1" ]; then
		tfo="true"
	else
		tfo="false"
	fi
	#20200807处理%0A替换成%7C，换行替换成|
	links3=$(get merlinclash_links3)
	links=$(decode_url_link $links3)
	merlinc_link=$(echo $links | sed 's/%0A/%7C/g')
	echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE
	upname_tmp=$(get merlinclash_uploadrename4)
	#echo_date "订阅文件重命名为：$upname_tmp" >> $LOG_FILE
	time=$(date "+%Y%m%d-%H%M%S")
	newname=$(echo $time | awk -F'-' '{print $2}')
	echo_date "配置名是：$upname_tmp" >> $LOG_FILE
	if [ "$customrule" == "0" ]; then
		case $acl4ssrsel in
		ZHANG)
			_name="MCC_"
			;;
		ZHANG_NoAuto)
			_name="MNA_"
			;;
		ZHANG_Media)
			_name="MM_"
			;;	
		ZHANG_Media_NoAuto)
			_name="MMN_"
			;;	
		ZHANG_Media_Area_UrlTest)
			_name="MAU_"
			;;	
		ZHANG_Media_Area_FallBack)
			_name="MAF_"
			;;
		ACL4SSR_Online)
			_name="OL_"
			;;
		ACL4SSR_Online_AdblockPlus)
			_name="AP_"
			;;
		ACL4SSR_Online_NoAuto)
			_name="NA_"
			;;
		ACL4SSR_Online_NoReject)
			_name="NR_"
			;;
		ACL4SSR_Online_Mini)
			_name="Mini_"
			;;
		ACL4SSR_Online_Mini_AdblockPlus)
			_name="MAP_"
			;;
		ACL4SSR_Online_Mini_NoAuto)
			_name="MNA_"
			;;
		ACL4SSR_Online_Mini_Fallback)
			_name="MF_"
			;;
		ACL4SSR_Online_Mini_MultiMode)
			_name="MMM_"
			;;
		ACL4SSR_Online_Full)
			_name="Full_"
			;;
		ACL4SSR_Online_Full_NoAuto)
			_name="FNA_"
			;;
		ACL4SSR_Online_Full_AdblockPlus)
			_name="FAP_"
			;;
		ACL4SSR_Online_Full_Netflix)
			_name="FNX_"
			;;
		ACL4SSR_Online_Full_Google)
			_name="FGG_"
			;;
		ACL4SSR_Online_Full_MultiMode)
			_name="FMM_"
			;;
		ACL4SSR_Online_Mini_MultiCountry)
			_name="MMC_"
			;;
		esac
		subscription_type="4"
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2F${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	else
		acl4ssrsel=$(get merlinclash_acl4ssrsel_cus)
		_name="CUS_"
		subscription_type="6"
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=customconfig%2F${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	fi
	if [ "$URLflag" == "1" ]; then
		_name="MY_"
		urlinilink=$(dbus get merlinclash_uploadiniurl)
		urlinilink=$(decode_url_link $urlinilink)
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
		dbus set merlinclash_customrule_cbox="0"
		subscription_type="7"
		customrule=$(dbus get merlinclash_customrule_cbox)
	fi
	if [ "$customrule" == "0" ] && [ "$URLflag" == "0" ]; then
		echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acl4ssrsel)" >> $LOG_FILE
	elif [ "$URLflag" == "1" ]; then
		echo_date "订阅规则是：远程订阅" >> $LOG_FILE
	else
		echo_date "订阅规则是：$acl4ssrsel" >> $LOG_FILE
	fi
	echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
	sleep 3s
	echo_date "生成订阅链接：$links" >> $LOG_FILE
	if [ -n "$upname_tmp" ]; then
		upname="$_name$upname_tmp.yaml"
	else
		upname="$_name$newname.yaml"
	fi
	#wget下载文件
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
	UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
	echo_date "使用常规网络下载..." >> $LOG_FILE
	curl -4sSk --user-agent "$UA" --connect-timeout 30 "$links" > /tmp/upload/$upname
	echo_date "配置文件下载完成" >>$LOG_FILE
	#虽然为0但是还是要检测下是否下载到正确的内容
	if [ "$?" == "0" ];then
		#下载为空...
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
			rm /tmp/upload/$upname
			wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"--no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
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
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
				echo_date "curl下载出错，尝试更换wget进行下载..." >> $LOG_FILE
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "下载内容为空..."
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
				failed_warning_clash
			fi
		fi
	else
		echo_date "下载超时" >> $LOG_FILE
		failed_warning_clash
	fi
}

start_dc_online_update_hnd(){
	clashtarget=$(get merlinclash_dc_clashtarget)
	acl4ssrsel=$(get merlinclash_dc_acl4ssrsel)
	emoji=$(get merlinclash_dc_subconverter_emoji)
	udp=$(get merlinclash_dc_subconverter_udp)
	appendtype=$(get merlinclash_dc_subconverter_append_type)
	sort=$(get merlinclash_dc_subconverter_sort)
	fnd=$(get merlinclash_dc_subconverter_fdn)
	scv=$(get merlinclash_dc_subconverter_scv)
	tfo=$(get merlinclash_dc_subconverter_tfo)
	include=$(get merlinclash_dc_subconverter_include)
	exclude=$(get merlinclash_dc_subconverter_exclude)
	DCURLflag=$(dbus get merlinclash_dc_customurl_cbox)
	customrule="0"
	updateflag="start_online_update"
	subscription_type="4"
	if [ "$emoji" == "1" ]; then
		emoji="true"
	else
		emoji="false"
	fi
	if [ "$udp" == "1" ]; then
		udp="true"
	else
		udp="false"
	fi
	if [ "$appendtype" == "1" ]; then
		appendtype="true"
	else
		appendtype="false"
	fi
	if [ "$sort" == "1" ]; then
		sort="true"
	else
		sort="false"
	fi
	if [ "$fnd" == "1" ]; then
		fnd="true"
	else
		fnd="false"
	fi
	if [ "$scv" == "1" ]; then
		scv="true"
	else
		scv="false"
	fi
	if [ "$tfo" == "1" ]; then
		tfo="true"
	else
		tfo="false"
	fi
	#20200807处理%0A替换成%7C，换行替换成|
	#links=$(decode_url_link $merlinclash_dc_links3)
	dclink3=$(get merlinclash_dc_links3)
	links=$(decode_url_link $dclink3)
	merlinc_link=$(echo $links | sed 's/%0A/%7C/g')
	echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE
		upname_tmp=$(get merlinclash_dc_uploadrename4)
		#echo_date "订阅文件重命名为：$upname_tmp" >> $LOG_FILE
		time=$(date "+%Y%m%d-%H%M%S")
		newname=$(echo $time | awk -F'-' '{print $2}')
		if [ "$DCURLflag" == "0" ]; then
			echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acl4ssrsel)"
			echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
			echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
			sleep 3s
			case $acl4ssrsel in
			ZHANG)
				_name="MCC_"
				;;
			ZHANG_NoAuto)
				_name="MNA_"
				;;
			ZHANG_Media)
				_name="MM_"
				;;	
			ZHANG_Media_NoAuto)
				_name="MMN_"
				;;	
			ZHANG_Media_Area_UrlTest)
				_name="MAU_"
				;;	
			ZHANG_Media_Area_FallBack)
				_name="MAF_"
				;;
			ACL4SSR_Online)
				_name="OL_"
				;;
			ACL4SSR_Online_AdblockPlus)
				_name="AP_"
				;;
			ACL4SSR_Online_NoAuto)
				_name="NA_"
				;;
			ACL4SSR_Online_NoReject)
				_name="NR_"
				;;
			ACL4SSR_Online_Mini)
				_name="Mini_"
				;;
			ACL4SSR_Online_Mini_AdblockPlus)
				_name="MAP_"
				;;
			ACL4SSR_Online_Mini_NoAuto)
				_name="MNA_"
				;;
			ACL4SSR_Online_Mini_Fallback)
				_name="MF_"
				;;
			ACL4SSR_Online_Mini_MultiMode)
				_name="MMM_"
				;;
			ACL4SSR_Online_Full)
				_name="Full_"
				;;
			ACL4SSR_Online_Full_NoAuto)
				_name="FNA_"
				;;
			ACL4SSR_Online_Full_AdblockPlus)
				_name="FAP_"
				;;
			ACL4SSR_Online_Full_Netflix)
				_name="FNX_"
				;;
			ACL4SSR_Online_Full_Google)
				_name="FGG_"
				;;
			ACL4SSR_Online_Full_MultiMode)
				_name="FMM_"
				;;
			ACL4SSR_Online_Mini_MultiCountry)
				_name="MMC_"
				;;
			esac
			links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2F${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo"
		else
			echo_date "订阅规则类型是：远程订阅"
			echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
			echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
			sleep 3s
			_name="MY_"
			urlinilink=$(dbus get merlinclash_dc_uploadiniurl)
			urlinilink=$(decode_url_link $urlinilink)
			echo_date "远程配置的地址是：$urlinilink" >> $LOG_FILE
			links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo"
			dbus set merlinclash_customrule_cbox="0"
			subscription_type="7"
			customrule="0"
		fi
		echo_date "生成订阅链接：$links" >> $LOG_FILE
		if [ -n "$upname_tmp" ]; then
			upname="$_name$upname_tmp.yaml"
		else
			upname="$_name$newname.yaml"
		fi
			#wget下载文件
			#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
			UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
			echo_date "使用常规网络下载..." >> $LOG_FILE
			curl -4k --tlsv1 --user-agent "$UA" --connect-timeout 30 "$links" > /tmp/upload/$upname
			echo_date "配置文件下载完成" >>$LOG_FILE
			if [ "$?" == "0" ];then
				#下载为空...
				if [ -z "$(cat /tmp/upload/$upname)" ]; then
					echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
					rm /tmp/upload/$upname
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
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
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
						echo_date "curl下载出错，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
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
						failed_warning_clash
					fi
				fi
			else
				echo_date "下载超时" >> $LOG_FILE
				failed_warning_clash
			fi
	#fi
}

start_regular_update_hnd(){
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo      $xudp
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14}    ${16}
	emoji=$6
	echo_date "emoji:$emoji" >> $Regularlog

	udp=$7
	echo_date "udp:$udp" >> $Regularlog

    xudp=${16}
	echo_date "xudp:$xudp" >> $Regularlog

	appendtype=$8
	echo_date "节点显示类型:$appendtype" >> $Regularlog

	sort=$9
	echo_date "节点排序:$sort" >> $Regularlog

	fnd=${10}
	echo_date "过滤非法节点:$fnd" >> $Regularlog
	
	scv=${13}
	echo_date "跳过证书验证:$scv" >> $Regularlog

	tfo=${14}
	echo_date "TCP FAST OPEN:$tfo" >> $Regularlog

	include=${11}
	echo_date "包含节点:$include" >> $Regularlog

	exclude=${12}
	echo_date "排除节点:$exclude" >> $Regularlog

	customrule=${15}
	echo_date "自定订阅标记:$customrule" >> $Regularlog

	updateflag="start_regular_update"
	merlinc_link=""
	upname=""
	urlinilink=""
	subscription_type=$2 #值可能为4、6、7
	if [ "$subscription_type" == "7" ]; then
		urlinilink="${17}"
	fi
	merlinc_link=$3	
	upname_tmp=$1
	acltype_tmp=$5
	clashtarget=$4
	dbus set merlinclash_clashtarget=$clashtarget
	echo_date "clashtarget: $clashtarget" >> $Regularlog
	echo_date "订阅地址是：$merlinc_link" >> $Regularlog
	echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE
	echo_date "【配置名是：$upname_tmp】" >> $Regularlog
	if [ "$subscription_type" == "4" ]; then
		case $acltype_tmp in
		ZHANG)
			_name="MCC_"
			;;
		ZHANG_NoAuto)
			_name="MNA_"
			;;
		ZHANG_Media)
			_name="MM_"
			;;	
		ZHANG_Media_NoAuto)
			_name="MMN_"
			;;	
		ZHANG_Media_Area_UrlTest)
			_name="MAU_"
			;;	
		ZHANG_Media_Area_FallBack)
			_name="MAF_"
			;;
		ACL4SSR_Online)
			_name="OL_"
			;;
		ACL4SSR_Online_AdblockPlus)
			_name="AP_"
			;;
		ACL4SSR_Online_NoAuto)
			_name="NA_"
			;;
		ACL4SSR_Online_NoReject)
			_name="NR_"
			;;
		ACL4SSR_Online_Mini)
			_name="Mini_"
			;;
		ACL4SSR_Online_Mini_AdblockPlus)
			_name="MAP_"
			;;
		ACL4SSR_Online_Mini_NoAuto)
			_name="MNA_"
			;;
		ACL4SSR_Online_Mini_Fallback)
			_name="MF_"
			;;
		ACL4SSR_Online_Mini_MultiMode)
			_name="MMM_"
			;;
		ACL4SSR_Online_Full)
			_name="Full_"
			;;
		ACL4SSR_Online_Full_NoAuto)
			_name="FNA_"
			;;
		ACL4SSR_Online_Full_AdblockPlus)
			_name="FAP_"
			;;
		ACL4SSR_Online_Full_Netflix)
			_name="FNX_"
			;;
		ACL4SSR_Online_Full_Google)
			_name="FGG_"
			;;
		ACL4SSR_Online_Full_MultiMode)
			_name="FMM_"
			;;
		ACL4SSR_Online_Mini_MultiCountry)
			_name="MMC_"
			;;
		esac
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=ruleconfig%2F${acltype_tmp}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	elif [ "$subscription_type" == "6" ]; then
		_name="CUS_"
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=customconfig%2F${acltype_tmp}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	else
		_name="MY_"
		links="http://${local_domain}:25500/sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
		dbus set merlinclash_customrule_cbox="0"
		subscription_type="7"
		customrule=$(dbus get merlinclash_customrule_cbox)
	fi
	if [ "$subscription_type" == "4" ]; then
		echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acltype_tmp)" >> $Regularlog
		echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acltype_tmp)" >> $LOG_FILE
	elif [ "$subscription_type" == "6" ]; then
		echo_date "订阅规则是：$acltype_tmp" >> $Regularlog
		echo_date "订阅规则是：$acltype_tmp" >> $LOG_FILE
	else
		echo_date "订阅规则是：远程订阅" >> $Regularlog
		echo_date "订阅规则是：远程订阅" >> $LOG_FILE
	fi
	echo_date "subconverter进程：$(pidof subconverter)" >> $Regularlog
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $Regularlog
	sleep 3s	
	echo_date "生成订阅链接：$links" >> $Regularlog
	echo_date "生成订阅链接：$links" >> $LOG_FILE
	upname="${_name}${upname_tmp}.yaml"
		
	#wget下载文件
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
	UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
	echo_date "使用常规网络下载..." >> $Regularlog
	curl -4k --tlsv1 --user-agent "$UA" --connect-timeout 30 "$links" > /tmp/upload/$upname
	echo_date "配置文件下载完成" >>$Regularlog
	if [ "$?" == "0" ];then
		#下载为空...
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $Regularlog
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
			rm /tmp/upload/$upname
			wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
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
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
				echo_date "curl下载出错，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
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
			echo_date "已获取clash配置文件" >> $LOG_FILE
			echo_date "yaml文件合法性检查" >> $Regularlog
			check_yamlfile
			if [ $? == "1" ]; then
			#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
				echo_date "执行yaml文件处理工作" >> $Regularlog
				sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
				#20200803写入字典
				#write_dictionary
				echo_date "订阅完成" >> $Regularlog
				echo_date "订阅完成" >> $LOG_FILE
			else
				echo_date "yaml文件格式不合法" >> $Regularlog
				echo_date "yaml文件格式不合法" >> $LOG_FILE
				failed_warning_clash
			fi
		fi
	else
		echo_date "下载超时" >> $Regularlog
		echo_date "下载超时" >> $LOG_FILE
		failed_warning_clash
	fi
}
start_online_update_384(){
	clashtarget=$(get merlinclash_clashtarget)
	acl4ssrsel=$(get merlinclash_acl4ssrsel)
	emoji=$(get merlinclash_subconverter_emoji)
	udp=$(get merlinclash_subconverter_udp)
	xudp=$(get merlinclash_subconverter_xudp)
	appendtype=$(get merlinclash_subconverter_append_type)
	sort=$(get merlinclash_subconverter_sort)
	fnd=$(get merlinclash_subconverter_fdn)
	scv=$(get merlinclash_subconverter_scv)
	tfo=$(get merlinclash_subconverter_tfo)
	include=$(get merlinclash_subconverter_include)
	exclude=$(get merlinclash_subconverter_exclude)
	subcsel=$(get merlinclash_subconverter_addr_sel)
	if [ "$subcsel" == "custom" ]; then
		addr=$(get merlinclash_subconverter_addr_cus)
	else
		addr=$(get merlinclash_subconverter_addr)
	fi
	updateflag="start_online_update"
	subscription_type="5"
	if [ "$emoji" == "1" ]; then
		emoji="true"
	else
		emoji="false"
	fi
	if [ "$udp" == "1" ]; then
		udp="true"
	else
		udp="false"
	fi
	if [ "$xudp" == "1" ]; then
		xudp="true"
	else
		xudp="false"
	fi
	if [ "$appendtype" == "1" ]; then
		appendtype="true"
	else
		appendtype="false"
	fi
	if [ "$sort" == "1" ]; then
		sort="true"
	else
		sort="false"
	fi
	if [ "$fnd" == "1" ]; then
		fnd="true"
	else
		fnd="false"
	fi
	if [ "$scv" == "1" ]; then
		scv="true"
	else
		scv="false"
	fi
	if [ "$tfo" == "1" ]; then
		tfo="true"
	else
		tfo="false"
	fi
	#20200807处理%0A替换成%7C，换行替换成|
	links3=$(get merlinclash_links3)
	links=$(decode_url_link $links3)
	merlinc_link=$(echo $links | sed 's/%0A/%7C/g')
	echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE
		upname_tmp=$(get merlinclash_uploadrename4)
		time=$(date "+%Y%m%d-%H%M%S")
		newname=$(echo $time | awk -F'-' '{print $2}')
		echo_date "配置名是：$upname_tmp" >> $LOG_FILE
		if [ "$URLflag" == "0" ]; then
			echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acl4ssrsel)" >> $LOG_FILE
			echo_date "订阅后端是：$(get_subcsel_name $subcsel)" >> $LOG_FILE
			echo_date "订阅后端地址是：$addr" >> $LOG_FILE
			echo_date "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
			sleep 3s
			acl_flag="ACL4SSR"
			case $acl4ssrsel in
			ZHANG)
				_name="MCC_"
				acl_flag="ZHANG"
				;;
			ZHANG_NoAuto)
				_name="MNA_"
				acl_flag="ZHANG"
				;;
			ZHANG_Media)
				_name="MM_"
				acl_flag="ZHANG"
				;;	
			ZHANG_Media_NoAuto)
				_name="MMN_"
				acl_flag="ZHANG"
				;;	
			ZHANG_Media_Area_UrlTest)
				_name="MAU_"
				acl_flag="ZHANG"
				;;	
			ZHANG_Media_Area_FallBack)
				_name="MAF_"
				acl_flag="ZHANG"
				;;
			ACL4SSR_Online)
				_name="OL_"
				;;
			ACL4SSR_Online_AdblockPlus)
				_name="AP_"
				;;
			ACL4SSR_Online_NoAuto)
				_name="NA_"
				;;
			ACL4SSR_Online_NoReject)
				_name="NR_"
				;;
			ACL4SSR_Online_Mini)
				_name="Mini_"
				;;
			ACL4SSR_Online_Mini_AdblockPlus)
				_name="MAP_"
				;;
			ACL4SSR_Online_Mini_NoAuto)
				_name="MNA_"
				;;
			ACL4SSR_Online_Mini_Fallback)
				_name="MF_"
				;;
			ACL4SSR_Online_Mini_MultiMode)
				_name="MMM_"
				;;
			ACL4SSR_Online_Full)
				_name="Full_"
				;;
			ACL4SSR_Online_Full_NoAuto)
				_name="FNA_"
				;;
			ACL4SSR_Online_Full_AdblockPlus)
				_name="FAP_"
				;;
			ACL4SSR_Online_Full_Netflix)
				_name="FNX_"
				;;
			ACL4SSR_Online_Full_Google)
				_name="FGG_"
				;;
			ACL4SSR_Online_Full_MultiMode)
				_name="FMM_"
				;;
			ACL4SSR_Online_Mini_MultiCountry)
				_name="MMC_"
				;;
			esac
			mcc=$(get merlinclash_cdn_cbox)
			if [ "$acl_flag" == "ACL4SSR" ] && [ "$mcc" == "0" ]; then
				links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontent.com%2FACL4SSR%2FACL4SSR%2Fmaster%2FClash%2Fconfig%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
			elif [ "$acl_flag" == "ZHANG" ] && [ "$mcc" == "0" ]; then
				links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontent.com%2Fflyhigherpi%2Fmerlinclash_clash_related%2Fmaster%2FRule_config%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
			elif [ "$acl_flag" == "ACL4SSR" ] && [ "$mcc" == "1" ]; then
				links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontents.com%2FACL4SSR%2FACL4SSR%2Fmaster%2FClash%2Fconfig%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
			elif [ "$acl_flag" == "ZHANG" ] && [ "$mcc" == "1" ]; then
				links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontents.com%2Fflyhigherpi%2Fmerlinclash_clash_related%2Fmaster%2FRule_config%2FZHANG_CDN%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
			fi
		else
			_name="MY_"
			urlinilink=$(dbus get merlinclash_uploadiniurl)
			urlinilink=$(decode_url_link $urlinilink)
			links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
			subscription_type="8"
		fi	
		if [ -n "$upname_tmp" ]; then
			upname="$_name$upname_tmp.yaml"
		else
			upname="$_name$newname.yaml"
		fi
			#wget下载文件
			#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
			echo_date "订阅地址是：$links" >> $LOG_FILE
			UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
			echo_date "使用常规网络下载..." >> $LOG_FILE
			curl -4k --tlsv1 --user-agent "$UA" --connect-timeout 30 "$links" > /tmp/upload/$upname
			echo_date "配置文件下载完成" >>$LOG_FILE
			if [ "$?" == "0" ];then
				#下载为空...
				if [ -z "$(cat /tmp/upload/$upname)" ]; then
					echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
					rm /tmp/upload/$upname
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
				fi
				echo_date "检查文件完整性" >> $LOG_FILE
				if [ -z "$(cat /tmp/upload/$upname)" ];then 
					echo_date "获取clash配置文件失败！" >> $LOG_FILE
					failed_warning_clash
				else
					#虽然为0但是还是要检测下是否下载到正确的内容
					echo_date "检查下载是否正确" >> $LOG_FILE
					#订阅地址有跳转
					local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
					local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
					local blakflg="0"				
					if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
						echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
						echo_date "curl下载出错，尝试更换wget进行下载..." >> $LOG_FILE
						rm /tmp/upload/$upname
						if [ -n $(echo $links | grep -E "^https") ]; then
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
						else
							wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
						fi
						blakflg="1"
					fi
					#下载为空...
					if [ -z "$(cat /tmp/upload/$upname)" ]; then
						echo_date "下载内容为空..."  >> $LOG_FILE
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
						failed_warning_clash
					fi
				fi
			else
				echo_date "下载超时" >> $LOG_FILE
				failed_warning_clash
			fi
	#fi
}

start_regular_update_384(){
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $addr $xudp
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14} ${15} ${16}
	emoji=$6
	echo_date "emoji:$emoji" >> $Regularlog

	udp=$7
	echo_date "udp:$udp" >> $Regularlog

	xudp=${16}
	echo_date "xudp:$xudp" >> $Regularlog

	appendtype=$8
	echo_date "节点显示类型:$appendtype" >> $Regularlog

	sort=$9
	echo_date "节点排序:$sort" >> $Regularlog

	fnd=${10}
	echo_date "过滤非法节点:$fnd" >> $Regularlog
	
	scv=${13}
	echo_date "跳过证书验证:$scv" >> $Regularlog

	tfo=${14}
	echo_date "TCP FAST OPEN:$tfo" >> $Regularlog

	include=${11}
	echo_date "包含节点:$include" >> $Regularlog

	exclude=${12}
	echo_date "排除节点:$exclude" >> $Regularlog

	addr=${15}
	echo_date "后端地址:$addr" >> $Regularlog
	
	updateflag="start_regular_update"
	merlinc_link=""
	upname=""
	urlinilink=""
	subscription_type=$2 #值可能为5、8
	if [ "$subscription_type" == "8" ]; then
		urlinilink="${17}"
	fi
	merlinc_link=$3	
	upname_tmp=$1
	acltype_tmp=$5
	clashtarget=$4
	dbus set merlinclash_clashtarget=$clashtarget
	echo_date "clashtarget: $clashtarget" >> $Regularlog
	echo_date "订阅地址是：$merlinc_link" >> $Regularlog
	echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE
	echo_date "【配置名是：$upname_tmp】" >> $Regularlog
	echo_date "后端地址是：$addr" >> $Regularlog
	
	#echo_date "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
	echo_date "即将开始转换，需要一定时间，请等候处理" >> $Regularlog
	sleep 3s
	acl_flag="ACL4SSR"
	if [ "$subscription_type" == "5" ]; then
		echo_date "订阅规则类型是：$(get_acl4ssrsel_name $acltype_tmp)" >> $Regularlog
		case $acltype_tmp in
		ZHANG)
			_name="MCC_"
			acl_flag="ZHANG"
			;;
		ZHANG_NoAuto)
			_name="MNA_"
			acl_flag="ZHANG"
			;;
		ZHANG_Media)
			_name="MM_"
			acl_flag="ZHANG"
			;;	
		ZHANG_Media_NoAuto)
			_name="MMN_"
			acl_flag="ZHANG"
			;;	
		ZHANG_Media_Area_UrlTest)
			_name="MAU_"
			acl_flag="ZHANG"
			;;	
		ZHANG_Media_Area_FallBack)
			_name="MAF_"
			acl_flag="ZHANG"
			;;
		ACL4SSR_Online)
			_name="OL_"
			;;
		ACL4SSR_Online_AdblockPlus)
			_name="AP_"
			;;
		ACL4SSR_Online_NoAuto)
			_name="NA_"
			;;
		ACL4SSR_Online_NoReject)
			_name="NR_"
			;;
		ACL4SSR_Online_Mini)
			_name="Mini_"
			;;
		ACL4SSR_Online_Mini_AdblockPlus)
			_name="MAP_"
			;;
		ACL4SSR_Online_Mini_NoAuto)
			_name="MNA_"
			;;
		ACL4SSR_Online_Mini_Fallback)
			_name="MF_"
			;;
		ACL4SSR_Online_Mini_MultiMode)
			_name="MMM_"
			;;
		ACL4SSR_Online_Full)
			_name="Full_"
			;;
		ACL4SSR_Online_Full_NoAuto)
			_name="FNA_"
			;;
		ACL4SSR_Online_Full_AdblockPlus)
			_name="FAP_"
			;;
		ACL4SSR_Online_Full_Netflix)
			_name="FNX_"
			;;
		ACL4SSR_Online_Full_Google)
			_name="FGG_"
			;;
		ACL4SSR_Online_Full_MultiMode)
			_name="FMM_"
			;;
		ACL4SSR_Online_Mini_MultiCountry)
			_name="MMC_"
			;;
		esac
	fi
	mcc=$(get merlinclash_cdn_cbox)
	if [ "$acl_flag" == "ACL4SSR" ] && [ "$mcc" == "0" ]; then
		links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontent.com%2fACL4SSR%2fACL4SSR%2fmaster%2fClash%2Fconfig%2f${acltype_tmp}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	elif [ "$acl_flag" == "ZHANG" ] && [ "$mcc" == "0" ]; then
		links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontent.com%2fflyhigherpi%2fmerlinclash_clash_related%2fmaster%2fRule_config%2f${acltype_tmp}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	elif [ "$acl_flag" == "ACL4SSR" ] && [ "$mcc" == "1" ]; then
		links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontents.com%2FACL4SSR%2FACL4SSR%2Fmaster%2FClash%2Fconfig%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	elif [ "$acl_flag" == "ZHANG" ] && [ "$mcc" == "1" ]; then
		links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=https%3a%2f%2fraw.githubusercontents.com%2Fflyhigherpi%2Fmerlinclash_clash_related%2Fmaster%2FRule_config%2FZHANG_CDN%2f${acl4ssrsel}.ini&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	fi	
	if [ "$subscription_type" == "8" ]; then
		_name="MY_"
		links="${addr}sub?target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo&xudp=$xudp"
	fi
	upname="${_name}${upname_tmp}.yaml"
	echo_date "生成订阅链接：$links" >> $Regularlog
	echo_date "生成订阅链接：$links" >> $LOG_FILE	
	#wget下载文件
	#wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
	UA='Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
	echo_date "使用常规网络下载..." >> $Regularlog
	curl -4k --tlsv1 --user-agent "$UA" --connect-timeout 30 "$links" > /tmp/upload/$upname	
	echo_date "配置文件下载完成" >>$Regularlog
	if [ "$?" == "0" ];then
		#下载为空...
		if [ -z "$(cat /tmp/upload/$upname)" ]; then
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $Regularlog
			echo_date "使用curl下载成功，但是内容为空，尝试更换wget进行下载..."	>> $LOG_FILE
			rm /tmp/upload/$upname
			wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
		fi
		echo_date "检查文件完整性" >> $Regularlog
		if [ -z "$(cat /tmp/upload/$upname)" ];then 
			echo_date "获取clash配置文件失败！" >> $Regularlog
			failed_warning_clash
		else
			#虽然为0但是还是要检测下是否下载到正确的内容
			echo_date "检查下载是否正确" >> $Regularlog
			#订阅地址有跳转
			local blank=$(cat /tmp/upload/$upname | grep -E " |Redirecting|301")
			local blank2=$(cat /tmp/upload/$upname | grep -E " |The following link doesn't contain any valid node info")
			local blakflg="0"				
			if [ "$blakflg" == "0" ] && [ -n "$blank" ]; then
				echo_date "订阅链接可能有跳转，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			if [ "$blakflg" == "0" ] && [ -n "$blank2" ]; then
				echo_date "curl下载出错，尝试更换wget进行下载..." >> $Regularlog
				rm /tmp/upload/$upname
				if [ -n $(echo $links | grep -E "^https") ]; then
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"						
				else
					wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" -t3 -T30 -4 -O /tmp/upload/$upname "$links"	
				fi
				blakflg="1"
			fi
			#下载为空...
			if [ -z "$(cat /tmp/upload/$upname)" ]; then
				echo_date "下载内容为空..."  >> $Regularlog
				failed_warning_clash
			fi
			echo_date "已获取clash配置文件" >> $Regularlog
			echo_date "已获取clash配置文件" >> $LOG_FILE
			echo_date "yaml文件合法性检查" >> $Regularlog	
			check_yamlfile
			if [ $? == "1" ]; then
			#执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为upload.yaml
				echo_date "执行yaml文件处理工作" >> $Regularlog
				sh /jffs/softcenter/scripts/clash_yaml_sub.sh #>/dev/null 2>&1 &
				#20200803写入字典
				#write_dictionary
				echo_date "订阅完成" >> $Regularlog
				echo_date "订阅完成" >> $LOG_FILE
			else
				echo_date "yaml文件格式不合法" >> $Regularlog
				echo_date "yaml文件格式不合法" >> $LOG_FILE
				failed_warning_clash
			fi
		fi
	else
		echo_date "下载超时" >> $Regularlog
		echo_date "下载超时" >> $LOG_FILE
		failed_warning_clash
	fi
}
write_dictionary(){
	if [ "$subscription_type" == "4" ]; then #HND_SC订阅 
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acl4ssrsel" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "none" "$xudp"
	elif [ "$subscription_type" == "5" ]; then #384_ACL订阅 
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acl4ssrsel" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp"
	elif [ "$subscription_type" == "6" ]; then #HND_自定订阅 
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acl4ssrsel" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "none" "$xudp"
	elif [ "$subscription_type" == "7" ]; then #HND_远程订阅 
		echo_date "远程配置地址是：$urlinilink" >> $LOG_FILE
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "none" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "none" "$xudp" "$urlinilink"
	else # "8"=384_远程订阅 
		/bin/sh /jffs/softcenter/scripts/clash_dictionary.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "none" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp" "$urlinilink"
	fi
}


check_yamlfile(){
	/bin/sh /jffs/softcenter/scripts/clash_checkyaml.sh "/tmp/upload/$upname"
}

failed_warning_clash(){
	echo_date "本地获取文件失败！！！" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $LOG_FILE
		killall subconverter >/dev/null 2>&1
	fi
	echo_date "===================================================================" >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
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
16)
	#set_lock
	if [ "$mcflag" == "HND" ]; then
		echo "" > $LOG_FILE
		http_response "$1"
		echo_date "subconverter转换处理" >> $LOG_FILE
		#20200802启动subconverter进程
		/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
		start_online_update_hnd >> $LOG_FILE
		sc_process=$(pidof subconverter)
		if [ -n "$sc_process" ]; then
			echo_date 关闭subconverter进程... >> $LOG_FILE
			killall subconverter >/dev/null 2>&1
		fi
		echo BBABBBBC >> $LOG_FILE
	else
		#set_lock
		echo "" > $LOG_FILE
		http_response "$1"
		echo_date "ACL4SSR转换处理" >> $LOG_FILE
		start_online_update_384 >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		#unset_lock
	fi
	;;
21)
	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "dler三合一转换" >> $LOG_FILE
	#20200802启动subconverter进程
	/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
	start_dc_online_update_hnd >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $LOG_FILE
		killall subconverter >/dev/null 2>&1
	fi
	echo BBABBBBC >> $LOG_FILE
	;;
4)
	echo_date "SubConverter本地转换定时更新" >> $LOG_FILE
	echo_date "SubConverter本地转换定时更新" >> $Regularlog
	#20200802启动subconverter进程
	/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $customrule $xudp
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14} ${15}      ${16}
	start_regular_update_hnd "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $Regularlog
		echo_date "" >> $Regularlog
		killall subconverter >/dev/null 2>&1
	fi
	#echo BBABBBBC >> $LOG_FILE
	;;
5)
	echo_date "ACL4SSR转换定时更新" >> $LOG_FILE
	echo_date "ACL4SSR转换定时更新" >> $Regularlog
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $addr $xudp
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}  ${13} ${14} ${15} ${16}
	start_regular_update_384 "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" >> $LOG_FILE
	echo_date "" >> $Regularlog
	#echo BBABBBBC >> $LOG_FILE
	;;
6)
	echo_date "本地SC自定订阅定时更新" >> $LOG_FILE
	echo_date "本地SC自定订阅定时更新" >> $Regularlog
	#20200802启动subconverter进程
	/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $customrule $xudp
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14} ${15}     ${16}
	start_regular_update_hnd "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $Regularlog
		echo_date "" >> $Regularlog
		killall subconverter >/dev/null 2>&1
	fi
	#echo BBABBBBC >> $LOG_FILE
	;;
7)
	echo_date "本地SC远程订阅定时更新" >> $LOG_FILE
	echo_date "本地SC远程订阅定时更新" >> $Regularlog
	#20200802启动subconverter进程
	/jffs/softcenter/bin/subconverter >/dev/null 2>&1 &
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $customrule $xudp $urlinilink
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13} ${14} ${15}     ${16}   ${17}
	start_regular_update_hnd "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" >> $LOG_FILE
	sc_process=$(pidof subconverter)
	if [ -n "$sc_process" ]; then
		echo_date 关闭subconverter进程... >> $Regularlog
		echo_date "" >> $Regularlog
		killall subconverter >/dev/null 2>&1
	fi
	#echo BBABBBBC >> $LOG_FILE
	;;
8)
	echo_date "ACL4SSR远程订阅定时更新" >> $LOG_FILE
	echo_date "ACL4SSR远程订阅定时更新" >> $Regularlog
	#$name $type $link $clashtarget $acltype $emoji $udp $appendtype $sort $fnd $include $exclude $scv $tfo $addr $xudp $urlinilink
	#$1    $2    $3    $4           $5       $6      $7    $8         $9   ${10} ${11}    ${12}   ${13}${14}${15} ${16}   ${17}
	start_regular_update_384 "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" >> $LOG_FILE
	echo_date "" >> $Regularlog
	#echo BBABBBBC >> $LOG_FILE
	;;
esac
