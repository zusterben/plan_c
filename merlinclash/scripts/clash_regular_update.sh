#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
Regularlog=/tmp/upload/merlinclash_regular.log
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
subscribeplan=$(get merlinclash_subscribeplan)
yamlsel=$(get merlinclash_yamlsel)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml

filename=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
mcflag=$(get merlinclash_flag)
mcenable=$(get merlinclash_enable)

rm -rf $Regularlog

echo_date "定时订阅进程启动" >> $Regularlog

if [ "$subscribeplan" == "all" ]; then
	a=$(ls $filename | wc -l)
	if [ $a -gt 0 ]; then
		lines=$(cat $filename | wc -l)
		i=1
		while [ "$i" -le "$lines" ]
		do
			sleep 1s
			line=$(sed -n ''$i'p' "$filename")
			#echo $line
			#echo ""
			upname=$(echo $line |grep -o "\"name\".*"|awk -F\" '{print $4}')
			#名字去除.yaml后缀
			upname=$(echo $upname | awk -F"." '{print $1}')
			merlinc_link=$(echo $line | grep -o "\"link\".*"|awk -F\" '{print $4}')
			subscription_type=$(echo $line | grep -o "\"type\".*"|awk -F\" '{print $4}')
			use=$(echo $line | grep -o "\"use\".*"|awk -F\" '{print $4}')
			clashtarget=$(echo $line | grep -o "\"clashtarget\".*"|awk -F\" '{print $4}')
			emoji=$(echo $line | grep -o "\"emoji\".*"|awk -F\" '{print $4}')
			udp=$(echo $line | grep -o "\"udp\".*"|awk -F\" '{print $4}')
			xudp=$(echo $line | grep -o "\"xudp\".*"|awk -F\" '{print $4}')
			appendtype=$(echo $line | grep -o "\"appendtype\".*"|awk -F\" '{print $4}')
			sort=$(echo $line | grep -o "\"sort\".*"|awk -F\" '{print $4}')
			fnd=$(echo $line | grep -o "\"fnd\".*"|awk -F\" '{print $4}')
			include=$(echo $line | grep -o "\"include\".*"|awk -F\" '{print $4}')
			exclude=$(echo $line | grep -o "\"exclude\".*"|awk -F\" '{print $4}')
			scv=$(echo $line | grep -o "\"scv\".*"|awk -F\" '{print $4}')
			tfo=$(echo $line | grep -o "\"tfo\".*"|awk -F\" '{print $4}')
			acltype=$(echo $line | grep -o "\"acltype\".*"|awk -F\" '{print $4}')
			if [ "$subscription_type" == "3" ] || [ "$subscription_type" == "5" ] || [ "$subscription_type" == "8" ]; then
				addr=$(echo $line | grep -o "\"addr\".*"|awk -F\" '{print $4}')
				#echo_date "addr=$addr" >> $Regularlog
			elif [ "$subscription_type" == "4" ] || [ "$subscription_type" == "6" ]; then
				customrule=$(echo $line | grep -o "\"customrule\".*"|awk -F\" '{print $4}')
			elif [ "$subscription_type" == "7" ]; then
				customrule=$(echo $line | grep -o "\"customrule\".*"|awk -F\" '{print $4}')
				urlinilink=$(echo $line | grep -o "\"url\".*"|awk -F\" '{print $4}')
			elif [ "$subscription_type" == "8" ]; then
				urlinilink=$(echo $line | grep -o "\"url\".*"|awk -F\" '{print $4}')
			else
				echo_date "参数超范围" >> $Regularlog
			fi

			#echo_date "name=$name" >> $Regularlog
			#echo_date "link=$link" >> $Regularlog
			#echo_date "type=$type" >> $Regularlog
			#echo_date "use=$use" >> $Regularlog
			#echo_date "ruletype=$ruletype" >> $Regularlog
			#echo_date "acltype=$acltype" >> $Regularlog
			#echo_date "clashtarget=$clashtarget" >> $Regularlog
			#echo_date "emoji=$emoji" >> $Regularlog
			#echo_date "udp=$udp" >> $Regularlog
			#echo_date "appendtype=$appendtype" >> $Regularlog
			#echo_date "sort=$sort" >> $Regularlog
			#echo_date "fnd=$fnd" >> $Regularlog
			#echo_date "include=$include" >> $Regularlog
			#echo_date "exclude=$exclude" >> $Regularlog
			#echo_date "scv=$scv" >> $Regularlog
			#echo_date "tfo=$tfo" >> $Regularlog
			#echo_date "acltype=$acltype" >> $Regularlog
			#echo_date "customrule=$customrule" >> $Regularlog
			#echo_date "" >> $Regularlog
			#根据subscription_type类型调用不同订阅方法
			#subscription_type：1:Clash-Yaml配置下载 2:HND_小白订阅 3：384_小白订阅 4：HND_SC订阅 5:384_ACL订阅 
			#subscription_type：6：HND_自定订阅 7：HND_远程订阅 8:384_远程订阅
			case $subscription_type in
			1)	#1:Clash-Yaml配置下载
			#	echo "启动方案1"
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml.sh "$upname" "$subscription_type" "$merlinc_link"
				sleep 3s
				;;
			2)	#HND_小白订阅
			#	echo "启动方案2"
				#名字带前缀，先去除前缀
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				echo_date "本地SC_小白订阅定时更新" >> $Regularlog
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml_2.sh "$upname" "$subscription_type" "$merlinc_link"
				sleep 3s
				;;
			3)	#384_小白订阅
				echo_date "ACL4SSR_小白订阅定时更新" >> $Regularlog
				#名字带前缀，先去除前缀
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml_2.sh "$upname" "$subscription_type" "$merlinc_link" "$addr"
				sleep 3s
				;;
			4)	#HND_SC订阅
				#名字带前缀，先去除前缀
				echo_date "SubConverter本地转换定时更新" >> $Regularlog
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp"
				sleep 3s
				;;
			5)	#384_ACL订阅
				echo_date "ACL4SSR转换定时更新" >> $Regularlog
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp"
				sleep 3s
				;;
			6)	#HND_自定订阅
				#名字带前缀，先去除前缀
				echo_date "本地SC自定订阅定时更新" >> $Regularlog
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp"
				sleep 3s
				;;
			7)	#HND_远程订阅
				#名字带前缀，先去除前缀
				echo_date "本地SC远程订阅定时更新" >> $Regularlog
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp" "$urlinilink"
				sleep 3s
				;;
			8)	#ACL4SSR远程订阅
				#名字带前缀，先去除前缀
				echo_date "ACL4SSR远程订阅定时更新" >> $Regularlog
				#name=$(echo $name | awk -F"_" '{print $2}')
				#从左向右截取第一个 _ 后的字符串
				upname=$(echo ${upname#*_}) 
				/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp" "$urlinilink"
				sleep 3s
				;;	
			esac
			let i=i+1
		done
		if [ "$mcenable" == "1" ]; then
			#订阅后重启clash
			sleep 5s
			echo_date "订阅后重启clash" >> $Regularlog
			/bin/sh /jffs/softcenter/merlinclash/clashconfig.sh restart
		fi
	fi
else
	/bin/sh /jffs/softcenter/scripts/clash_updateyamlsel.sh 0 1 $yamlsel
	#订阅后重启clash
	sleep 5s
	echo_date "订阅后重启clash" >> $Regularlog
	/bin/sh /jffs/softcenter/merlinclash/clashconfig.sh restart
fi

