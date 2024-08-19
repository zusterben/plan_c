#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
dictionary=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
upname=$1
merlinc_link=$3
#subscription_type：1:Clash-Yaml配置下载 2:HND_小白订阅 3：384_小白订阅 4：HND_SC订阅 5:384_ACL订阅 
#subscription_type：6：HND_自定订阅 7：HND_远程订阅 8:384_远程订阅
subscription_type=$2
clashtarget=$4
acl4ssrsel=$5
emoji=$6
udp=$7
appendtype=$8
sort=${9}
fnd=${10}
include=${11}
exclude=${12}
scv=${13}
tfo=${14}
addr=${15}
xudp=${16}
urlinilink=${17}

mcflag=$(dbus get merlinclash_flag)
URLflag=$(dbus get merlinclash_customurl_cbox)
customrule=$(dbus get merlinclash_customrule_cbox)


if [ -f "$dictionary" ]; then #文件不存在则为首次订阅建立字典
	name_tmp=$(cat $dictionary | grep -w -n "$upname" | awk -F ":" '{print $1}')
		#定位配置名行数，存在，则覆写；不存在，则新增 -w全字符匹配	
		if [ -n "$name_tmp" ]; then
			echo_date "存在相同配置文件名，覆盖旧的配置文件" >> $LOG_FILE
			sed -i "$name_tmp d" $dictionary
		else
			echo_date "新建配置文件" >> $LOG_FILE
		fi
		if [ "$subscription_type" == "1" ]; then #clash-yaml下载方式
			echo_date "【在线clash订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\" >> $dictionary
		elif [ "$subscription_type" == "2" ]; then  #HND_小白订阅
			echo_date "【本地SC_小白一键订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\" >> $dictionary
		elif [ "$subscription_type" == "3" ]; then  #384_小白订阅 
			echo_date "【ACL4SSR_小白一键订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"addr\":\"$addr\" >> $dictionary
		elif [ "$subscription_type" == "4" ]; then  #HND_SC订阅 
			echo_date "【SubConverter本地转换】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"0\",\"xudp\":\"$xudp\" >> $dictionary
		elif [ "$subscription_type" == "5" ]; then  #384_ACL订阅 
			echo_date "【ACL4SSR转换处理】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"addr\":\"$addr\",\"xudp\":\"$xudp\" >> $dictionary
		elif [ "$subscription_type" == "6" ]; then  #HND_自定订阅 
			echo_date "【本地SC自定订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"1\",\"xudp\":\"$xudp\" >> $dictionary
		elif [ "$subscription_type" == "7" ]; then  #HND_远程订阅 
			echo_date "【本地SC远程订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"0\",\"url\":\"$urlinilink\",\"xudp\":\"$xudp\" >> $dictionary
		elif [ "$subscription_type" == "8" ]; then  #384_远程订阅 
			echo_date "【ACL4SSR远程订阅】" >> $LOG_FILE
			echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"addr\":\"$addr\",\"url\":\"$urlinilink\",\"xudp\":\"$xudp\" >> $dictionary
		else
			echo_date "参数超范围" >> $LOG_FILE
			return 0
		fi
else
	#为初次订阅，直接写入
	echo_date "首次订阅，开始写入新配置" >> $LOG_FILE
	if [ "$subscription_type" == "1" ]; then #clash-yaml下载方式
		echo_date "【在线clash订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\" >> $dictionary
	elif [ "$subscription_type" == "2" ]; then  #HND_小白订阅
		echo_date "【本地SC_小白一键订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\" >> $dictionary
	elif [ "$subscription_type" == "3" ]; then  #384_小白订阅 
		echo_date "【ACL4SSR_小白一键订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"addr\":\"$addr\" >> $dictionary
	elif [ "$subscription_type" == "4" ]; then  #HND_SC订阅 
		echo_date "【SubConverter本地转换】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"0\",\"xudp\":\"$xudp\" >> $dictionary
	elif [ "$subscription_type" == "5" ]; then  #384_ACL订阅 
		echo_date "【ACL4SSR转换处理】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"addr\":\"$addr\",\"xudp\":\"$xudp\" >> $dictionary
	elif [ "$subscription_type" == "6" ]; then  #HND_自定订阅 
		echo_date "【本地SC自定订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"1\",\"xudp\":\"$xudp\" >> $dictionary
	elif [ "$subscription_type" == "7" ]; then  #HND_远程订阅 
		echo_date "【本地SC远程订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"customrule\":\"0\",\"url\":\"$urlinilink\",\"xudp\":\"$xudp\" >> $dictionary
	elif [ "$subscription_type" == "8" ]; then  #384_远程订阅 
		echo_date "【ACL4SSR远程订阅】" >> $LOG_FILE
		echo \"name\":\"$upname\",\"link\":\"$merlinc_link\",\"type\":\"$subscription_type\",\"use\":\"0\",\"clashtarget\":\"$clashtarget\",\"acltype\":\"$acl4ssrsel\",\"emoji\":\"$emoji\",\"udp\":\"$udp\",\"appendtype\":\"$appendtype\",\"sort\":\"$sort\",\"fnd\":\"$fnd\",\"include\":\"$include\",\"exclude\":\"$exclude\",\"scv\":\"$scv\",\"tfo\":\"$tfo\",\"addr\":\"$addr\",\"url\":\"$urlinilink\",\"xudp\":\"$xudp\" >> $dictionary
	else
		echo_date "参数超范围" >> $LOG_FILE
		return 0
	fi
fi

return 1



