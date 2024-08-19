#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

LOGFILE=/tmp/upload/merlinclash_log.txt
LOG_FILE=/tmp/upload/merlinclash_updateyaml.txt
Regularlog=/tmp/upload/merlinclash_regular.log
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
if [ -n "$3" ]; then
	yamlname=$(get merlinclash_yamlsel)
else
	yamlname=$(get merlinclash_delyamlsel)
fi
yamlsel=$(get merlinclash_yamlsel)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
filename=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
rm -rf $LOG_FILE
mcflag=$(get merlinclash_flag)
mcenable=$(get merlinclash_enable)

update_yaml_sel(){

	dbus set merlinclash_updateflag="0"
	echo_date "待更新的配置文件为：$yamlname，日志文件位置为:$LOG_FILE" >> $LOGFILE
	echo_date "待更新的配置文件为：$yamlname，日志文件位置为:$LOG_FILE" >> $LOG_FILE
	a=$(ls $filename | wc -l)
	if [ $a -gt 0 ]; then
		echo_date "订阅字典文件存在,检查当前配置是否可以手动更新" >> $LOGFILE
		echo_date "订阅字典文件存在,检查当前配置是否可以手动更新" >> $LOG_FILE
		upfile=/tmp/updateyaml.txt
		awk -F, '/"'$yamlname.yaml'"/ {print $0}' $filename > $upfile

		lines=$(cat $upfile | wc -l)
		echo_date "存在字典数据：$lines条" >> $LOGFILE
		echo_date "存在字典数据：$lines条" >> $LOG_FILE
		if [ "$lines" == "1" ]; then
			i=1
			while [ "$i" -le "$lines" ]
			do
				echo_date "开始订阅更新处理" >> $LOGFILE
				echo_date "开始订阅更新处理" >> $LOG_FILE
				sleep 1s
				line=$(sed -n ''$i'p' "$upfile")
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
					echo_date "参数超范围" >> $LOGFILE
				fi
				echo_date "-----------------------------------------------" >> $LOGFILE
				echo_date "当前更新配置名：$upname" >> $LOGFILE
				echo_date "当前更新配置订阅链接：$merlinc_link" >> $LOGFILE
				echo_date "当前更新配置订阅类型：$subscription_type" >> $LOGFILE
				echo_date "-----------------------------------------------" >> $LOGFILE
				echo_date "-----------------------------------------------" >> $LOG_FILE
				echo_date "当前更新配置名：$upname" >> $LOG_FILE
				echo_date "当前更新配置订阅链接：$merlinc_link" >> $LOG_FILE
				echo_date "当前更新配置订阅类型：$subscription_type" >> $LOG_FILE
				echo_date "-----------------------------------------------" >> $LOG_FILE
				if [ "$yamlname" == "$yamlsel" ]; then
					dbus set merlinclash_updateflag="1"
				fi
				#echo_date "跳出" >> $LOGFILE
				#echo BBABBBBC >> $LOGFILE
				#exit 1
				#根据type类型调用不同订阅方法
				sleep 2s
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
					echo_date "本地SC_小白订阅手动更新" >> $LOGFILE
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml_2.sh "$upname" "$subscription_type" "$merlinc_link"
					sleep 3s
					;;
				3)	#384_小白订阅
					echo_date "ACL4SSR_小白订阅手动更新" >> $LOGFILE
					#名字带前缀，先去除前缀
					#name=$(echo $name | awk -F"_" '{print $2}')
					#从左向右截取第一个 _ 后的字符串
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml_2.sh "$upname" "$subscription_type" "$merlinc_link" "$addr"
					sleep 3s
					;;
				4)	#HND_SC订阅
					#名字带前缀，先去除前缀
					echo_date "SubConverter本地转换手动更新" >> $LOGFILE
					#name=$(echo $name | awk -F"_" '{print $2}')
					#从左向右截取第一个 _ 后的字符串
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp"
					sleep 3s
					;;
				5)	#384_ACL订阅
					echo_date "ACL4SSR转换手动更新" >> $LOGFILE
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp"
					sleep 3s
					;;
				6)	#HND_自定订阅
					#名字带前缀，先去除前缀
					echo_date "本地SC自定订阅手动更新" >> $LOGFILE
					#name=$(echo $name | awk -F"_" '{print $2}')
					#从左向右截取第一个 _ 后的字符串
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp"
					sleep 3s
					;;
				7)	#HND_远程订阅
					#名字带前缀，先去除前缀
					echo_date "本地SC远程订阅手动更新" >> $LOGFILE
					#name=$(echo $name | awk -F"_" '{print $2}')
					#从左向右截取第一个 _ 后的字符串
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$customrule" "$xudp" "$urlinilink"
					sleep 3s
					;;
				8)	#ACL4SSR远程订阅
					#名字带前缀，先去除前缀
					echo_date "ACL4SSR远程订阅手动更新" >> $LOGFILE
					#name=$(echo $name | awk -F"_" '{print $2}')
					#从左向右截取第一个 _ 后的字符串
					upname=$(echo ${upname#*_}) 
					/bin/sh /jffs/softcenter/scripts/clash_online_yaml4.sh "$upname" "$subscription_type" "$merlinc_link" "$clashtarget" "$acltype" "$emoji" "$udp" "$appendtype" "$sort" "$fnd" "$include" "$exclude" "$scv" "$tfo" "$addr" "$xudp" "$urlinilink"
					sleep 3s
					;;	
				esac
				let i=i+1
			done
			if [ "$yamlname" == "$yamlsel" ] && [ "$mcenable" == "1" ]; then
				#订阅后重启clash
				sleep 2s
				echo_date "订阅后重启clash" >> $Regularlog
				/bin/sh /jffs/softcenter/merlinclash/clashconfig.sh restart
			fi
		else	
			echo_date "该配置无法进行手动更新" >> $LOGFILE
			echo_date "该配置无法进行手动更新" >> $LOG_FILE
			echo BBABBBBC >> $LOGFILE
			exit 1
		fi
	else
		echo_date "字典丢失" >> $LOGFILE
		echo_date "字典丢失" >> $LOG_FILE
		echo BBABBBBC >> $LOGFILE
		exit 1
	fi
}

case $2 in
0)
	echo "" > $LOGFILE
	http_response "$1"
	echo_date "更新配置文件" >> $LOGFILE
	echo_date "更新配置文件" > $LOG_FILE
	update_yaml_sel >> $LOGFILE
	echo BBABBBBC >> $LOGFILE
	;;
1)
	echo "" > $Regularlog
	echo_date "更新当前配置文件" > $Regularlog
	update_yaml_sel $3 >> $Regularlog
	;;
esac
