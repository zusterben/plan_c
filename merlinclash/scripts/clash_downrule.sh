#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

#echo_date "download" >> $LOG_FILE
#echo_date "定位文件" >> $LOG_FILE
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)

backup_conf(){
	rm -rf /tmp/clash_rulebackup
	rm -rf /tmp/clash_rulebackup.tar.gz
	rm -rf /tmp/upload/clash_rulebackup.tar.gz
	echo_date "建立备份数据文件夹" > $LOG_FILE
	mkdir -p /tmp/clash_rulebackup
	dbus list merlinclash_ipset |  sed 's/=/=\"/' | sed 's/$/\"/g'|sed 's/^/dbus set /' | sed '1 isource /jffs/softcenter/scripts/base.sh' |sed '1 i#!/bin/sh' > /tmp/clash_rulebackup/clash_rulebackup.sh
	#dbus list merlinclash_ipset |  sed 's/=/=\"/' | sed 's/$/\"/g'|sed 's/^/dbus set /' >> /tmp/clash_rulebackup/clash_rulebackup.sh #自定义绕行/转发clash内容
	echo_date "备份MerlinClash 自定义规则相关数据完成" >> $LOG_FILE
	echo_date "" >> $LOG_FILE
	echo_date "备份MerlinClash 自定义规则资料" >> $LOG_FILE
	mkdir -p /tmp/clash_rulebackup/merlinclash/rule_custom
	cp -rf /jffs/softcenter/merlinclash/rule_custom/ /tmp/clash_rulebackup/merlinclash/
	
	echo_date "打包" >> $LOG_FILE
	sleep 1s
	cd /tmp
	tar -czf /tmp/clash_rulebackup.tar.gz -C /tmp clash_rulebackup
	if [ -z "$(cat /tmp/clash_rulebackup.tar.gz)" ]; then
		echo_date "打包结束，但是内容为空，备份出错..."	>> $LOG_FILE
		rm -rf /tmp/clash_rulebackup.tar.gz
		echo BBABBBBC >>  $LOG_FILE
		exit 1
	else
		echo_date "备份打包完成，导出。" >>  $LOG_FILE
		cp -rf /tmp/clash_rulebackup.tar.gz /tmp/upload/clash_rulebackup.tar.gz
	fi
}

clean(){
	[ -n "$name" ] && rm -rf /tmp/clash_rulebackup >/dev/null 2>&1
	rm -rf /tmp/upload/*.tar.gz >/dev/null 2>&1
}

remove_silent(){
	echo_date 先清除已有的参数... >> $LOG_FILE
	acls=`dbus list merlinclash_acl_ | cut -d "=" -f 1`
	for acl in $acls
	do
		echo_date 移除$acl 
		dbus remove $acl
	done
	ipsets=`dbus list merlinclash_ipset | cut -d "=" -f 1`
	for ipset in $ipsets
	do
		echo_date 移除$ipset 
		dbus remove $ipset
	done
	echo_date "--------------------"
}

restore_backup(){
	echo_date 检测到自定义规则备份文件... >> $LOG_FILE
	echo_date 开始恢复... >> $LOG_FILE

	sleep 1s
	chmod +x /tmp/upload/clash_rulebackup.tar.gz
	rm -rf /tmp/clash_rulebackup
	mv /tmp/upload/clash_rulebackup.tar.gz /tmp
	cd /tmp
	echo_date 尝试解压压缩包 >> $LOG_FILE
	tar -zxvf /tmp/clash_rulebackup.tar.gz >/dev/null 2>&1
	if [ "$?" == "0" ];then
		echo_date 解压完成！ >> $LOG_FILE
	else
		echo_date 解压错误，错误代码："$?"！ >> $LOG_FILE
		echo_date 估计是错误或者不完整的的压缩包！ >> $LOG_FILE
		echo_date 删除相关文件并退出... >> $LOG_FILE
		cd
		clean
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
	echo_date 检测jffs分区剩余空间...
	SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
	SPACE_NEED=$(du -s /tmp/clash_rulebackup | awk '{print $1}')
	if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB,还原备份需要"$SPACE_NEED" KB，空间满足，继续！			
		if [ ! -z "$(cat /tmp/clash_rulebackup/clash_rulebackup.sh)" ]; then
			echo_date "数据还原脚本内容不为空，执行脚本"	>> $LOG_FILE
			sh /tmp/clash_backup/clash_rulebackup.sh
		fi
		
		echo_date "还原自定义规则文件" >> $LOG_FILE
		cp -rf /tmp/clash_rulebackup/merlinclash/ /jffs/softcenter/
		if [ -f "/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml" ]; then
			echo_date "当前配置存在自定义规则文件，进行规则还原" >> $LOG_FILE
			rulecusfile="/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml"
            lines=$(cat $rulecusfile | wc -l)
            echo_date "存在自定义规则：$lines条" >> $LOGFILE
            if [ $lines -gt 0 ]; then
                i=1
                while [ "$i" -le "$lines" ]
                do
                    echo_date "开始取值赋值处理" >> $LOG_FILE
                    line=$(sed -n ''$i'p' "$rulecusfile")
                    type=$(echo $line | awk -F "," '{print $1}')
                    content=$(echo $line | awk -F "," '{print $2}')
                    lianjie=$(echo $line | awk -F "," '{print $3}')
                    protocol=$(echo $line | awk -F "," '{print $4}')
                    dbus set merlinclash_acl_type_$i=$type
                    dbus set merlinclash_acl_content_$i=$content
                    dbus set merlinclash_acl_lianjie_$i=$lianjie
                    dbus set merlinclash_acl_protocol_$i=$protocol
                    let i++
                done    
            fi
		fi
		echo_date 配置恢复成功！>> $LOG_FILE


	else
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 还原备份需要"$SPACE_NEED" KB，空间不足！
		echo_date 退出安装！
		cd
		clean
		echo BBABBBBC
		exit 1
	fi
}
restore_now(){
	[ -f "/tmp/upload/clash_rulebackup.tar.gz" ] && restore_backup
	echo_date 一点点清理工作... >> $LOG_FILE
	rm -rf /tmp/upload/clash_rulebackup.tar.gz
	echo_date 完成！>> $LOG_FILE
}

case $2 in
1)
	backup_conf
	http_response "$1"
	;;
23)
	echo "还原自定义规则" > $LOG_FILE
	http_response "$1"
	remove_silent 
	restore_now 
	echo BBABBBBC >>  $LOG_FILE
	;;
esac
