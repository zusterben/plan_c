#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
check_backup(){
	if [ "${merlinclash_bak_set}" != "1" ] && [ "${merlinclash_bak_yaml}" != "1"  ] && [ "${merlinclash_bak_acl}" != "1" ] && [ "${merlinclash_bak_db}" != "1" ] && [ "${merlinclash_bak_rule}" != "1" ] && [ "${merlinclash_bak_dns}" != "1" ] ; then
		echo_date "❌您未开启任何备份/还原选项，请至少开启一个！！！" >> $LOG_FILE
		clean
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}

backup_conf(){
	rm -rf /tmp/clash_backup
	rm -rf /tmp/mc_backup.tar.gz
	rm -rf /tmp/upload/mc_backup.tar.gz
	mkdir -p /tmp/clash_backup
	echo "1.0" > "/tmp/clash_backup/version"
	# 备份基础设置
	if [ "${merlinclash_bak_set}" == "1" ]; then
		echo_date "备份基础设置" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/set
		dbus list merlinclash_set_ >> /tmp/clash_backup/set/dbus.txt
		dbus list merlinclash_ipt_ >> /tmp/clash_backup/set/dbus.txt
		dbus list merlinclash_select_ >> /tmp/clash_backup/set/dbus.txt
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/head.yaml /tmp/clash_backup/set/
	fi
	# 备份订阅配置
	if [ "${merlinclash_bak_yaml}" == "1" ]; then
		echo_date "备份订阅配置" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/yaml
		dbus list merlinclash_sub_ >> /tmp/clash_backup/yaml/dbus.txt
		cp -rf /jffs/softcenter/merlinclash/yaml_bak/ /tmp/clash_backup/yaml/
		cp -rf /jffs/softcenter/merlinclash/yaml_use/ /tmp/clash_backup/yaml/
		cp -rf /jffs/softcenter/merlinclash/mark/ /tmp/clash_backup/yaml/ >/dev/null 2>&1
	fi	
	# 备份DNS设置
	if [ "${merlinclash_bak_dns}" == "1" ]; then
		echo_date "备份DNS设置" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/dns
		dbus list merlinclash_dns_ >> /tmp/clash_backup/dns/dbus.txt
		cp -rf /jffs/softcenter/merlinclash/yaml_dns/ /tmp/clash_backup/dns/
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml /tmp/clash_backup/dns/
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/hosts.yaml /tmp/clash_backup/dns/
	fi
	# 备份规则
	if [ "${merlinclash_bak_rule}" == "1" ]; then
		echo_date "备份规则" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/rule
		dbus list merlinclash_acl_ >> /tmp/clash_backup/rule/dbus.txt
		cp -rf /jffs/softcenter/merlinclash/rule_custom/ /tmp/clash_backup/rule/
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml /tmp/clash_backup/rule/ >/dev/null 2>&1
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml /tmp/clash_backup/rule/ >/dev/null 2>&1
	fi
	# 备份数据库
	if [ "${merlinclash_bak_db}" == "1" ]; then
		echo_date "备份规则数据库" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/db
		dbus list merlinclash_db_ >> /tmp/clash_backup/db/dbus.txt
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/ChinaIPv6.yaml /tmp/clash_backup/db/
		cp -rf /jffs/softcenter/merlinclash/yaml_basic/ChinaIP.yaml /tmp/clash_backup/db/
		cp -rf /jffs/softcenter/merlinclash/*.dat /tmp/clash_backup/db/ >/dev/null 2>&1
		cp -rf /jffs/softcenter/merlinclash/*.mmdb /tmp/clash_backup/db/ >/dev/null 2>&1
		cp -rf /jffs/softcenter/merlinclash/*.db /tmp/clash_backup/db/ >/dev/null 2>&1
	fi
	# 备份访问控制
	if [ "${merlinclash_bak_acl}" == "1" ]; then
		echo_date "备份访问控制" >> $LOG_FILE
		mkdir -p /tmp/clash_backup/acl
		dbus list merlinclash_nokpacl_ >> /tmp/clash_backup/acl/dbus.txt
	fi

	echo_date "备份完成，打包中..." >> $LOG_FILE
	cd /tmp
	tar -czf /tmp/mc_backup.tar.gz -C /tmp clash_backup
	if [ -z "$(cat /tmp/mc_backup.tar.gz)" ]; then
		echo_date "打包结束，但是内容为空，备份出错..."	>> $LOG_FILE
		rm -rf /tmp/clash_backup
		rm -rf /tmp/mc_backup.tar.gz
		echo BBABBBBC >>  $LOG_FILE
		exit 1
	else
		echo_date "打包完成，导出..." >>  $LOG_FILE
		mv -f /tmp/mc_backup.tar.gz /tmp/upload/mc_backup.tar.gz
		rm -rf /tmp/clash_backup
	fi
}

clean(){
	rm -rf /tmp/clash_backup >/dev/null 2>&1
	rm -rf /tmp/upload/mc_backup.tar.gz >/dev/null 2>&1
}

exec_dbus_config() {
    local file_path="$1"
    local total=0
    # 逐行处理
    while IFS= read -r line; do
        # 跳过空行
        [ -z "$line" ] && continue  
        total=$((total + 1))      
        dbus set "$line" 2>/dev/null
    done < "$file_path"
    # 输出统计
    echo_date "完成:共恢复 $total 个参数" >> $LOG_FILE
}

restore_conf(){
	# 还原基础设置
	if [ "${merlinclash_bak_set}" == "1" ] && [ -d "/tmp/clash_backup/set" ]; then
		echo_date "🔸开始还原基础设置..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/set/dbus.txt" ]; then
			echo_date "开始还原基础设置参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/set/dbus.txt"
		fi
		cp -rf /tmp/clash_backup/set/head.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
	fi
	# 还原订阅配置
	if [ "${merlinclash_bak_yaml}" == "1" ] && [ -d "/tmp/clash_backup/yaml" ]; then
		echo_date "🔸开始还原订阅配置..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/yaml/dbus.txt" ]; then
			echo_date "开始还原订阅配置参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/yaml/dbus.txt"
		fi
		cp -rf /tmp/clash_backup/yaml/yaml_bak/ /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/yaml/mark/ /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/yaml/yaml_use/ /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		#生成配置下拉列表
		rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt >/dev/null 2>&1
		find /jffs/softcenter/merlinclash/yaml_bak -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	fi
	# 还原DNS设置
	if [ "${merlinclash_bak_dns}" == "1" ] && [ -d "/tmp/clash_backup/dns" ]; then
		echo_date "🔸开始还原DNS设置..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/dns/dbus.txt" ]; then
			echo_date "开始还原DNS设置参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/dns/dbus.txt"
		fi
		cp -rf /tmp/clash_backup/dns/yaml_dns/ /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/dns/sniffer.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/dns/hosts.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
	fi
	# 还原规则
	if [ "${merlinclash_bak_rule}" == "1" ] && [ -d "/tmp/clash_backup/rule" ]; then
		echo_date "🔸开始还原规则..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/rule/dbus.txt" ]; then
			echo_date "先清除已有的相关参数..." >> $LOG_FILE
			acls=`dbus list merlinclash_acl_ | cut -d "=" -f 1`
			for acl in $acls
			do
				echo_date 移除$acl 
				dbus remove $acl
			done
			echo_date "开始还原规则参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/rule/dbus.txt"
		fi
		cp -rf /tmp/clash_backup/rule/rule_custom/ /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/rule/ipsetproxyarround.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/rule/ipsetproxy.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
	fi
	# 还原数据库
	if [ "${merlinclash_bak_db}" == "1" ] && [ -d "/tmp/clash_backup/db" ]; then
		echo_date "🔸开始还原数据库..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/db/dbus.txt" ]; then
			echo_date "开始还原数据库参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/db/dbus.txt"
		fi
		cp -rf /tmp/clash_backup/db/ChinaIPv6.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/db/ChinaIP.yaml /jffs/softcenter/merlinclash/yaml_basic/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/db/*.dat /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/db/*.mmdb /jffs/softcenter/merlinclash/ >/dev/null 2>&1
		cp -rf /tmp/clash_backup/db/*.db /jffs/softcenter/merlinclash/ >/dev/null 2>&1
	fi
	# 还原访问控制
	if [ "${merlinclash_bak_acl}" == "1" ] && [ -d "/tmp/clash_backup/acl" ]; then
		echo_date "🔸开始还原访问控制..." >> $LOG_FILE
		if [ -f "/tmp/clash_backup/acl/dbus.txt" ]; then
			echo_date "先清除已有的相关参数..." >> $LOG_FILE
			nokpacls=`dbus list merlinclash_nokpacl_ | cut -d "=" -f 1`
			for nokpacl in $nokpacls
			do
				echo_date 移除$nokpacl 
				dbus remove $nokpacl
			done
			echo_date "开始还原访问控制参数..." >> $LOG_FILE
			exec_dbus_config "/tmp/clash_backup/acl/dbus.txt"
		fi
	fi
}

restore_run(){
	if [ "${merlinclash_enable}" == "1" ]; then
		echo_date "正在关闭Magic Catling插件，保证设置还原成功" >> $LOG_FILE
		sh /jffs/softcenter/scripts/clash_config.sh stop stop >/dev/null 2>&1
	fi
	sleep 1s
	chmod +x /tmp/upload/mc_backup.tar.gz
	rm -rf /tmp/clash_backup
	mv /tmp/upload/mc_backup.tar.gz /tmp
	cd /tmp
	echo_date "正在解压..." >> $LOG_FILE
	tar -zxvf /tmp/mc_backup.tar.gz >/dev/null 2>&1	
	if [ "$?" == "0" ];then
		echo_date 解压完成！ >> $LOG_FILE
	else
		echo_date 解压错误，错误代码："$?"！ >> $LOG_FILE
		echo_date 估计是错误或者不完整的的压缩包！ >> $LOG_FILE
		echo_date 删除相关文件并退出... >> $LOG_FILE
		clean
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
	echo_date 检测jffs分区剩余空间... >> $LOG_FILE
	SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
	SPACE_NEED=$(du -s /tmp/clash_backup | awk '{print $1}')
	if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB,还原备份需要"$SPACE_NEED" KB，空间满足，继续！ >> $LOG_FILE
		bak_VERSION=$(cat /tmp/clash_backup/version)
		if [ "$bak_VERSION" == "1.0" ]; then
			restore_conf
			echo_date "✅恭喜！！还原完成！" >> $LOG_FILE
		else
			echo_date "❌您的备份文件版本过旧，不支持还原！退出..." >> $LOG_FILE
			clean
			echo BBABBBBC >> $LOG_FILE
			exit 1
		fi
	else
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 还原备份需要"$SPACE_NEED" KB，空间不足！ >> $LOG_FILE
		echo_date ❌退出还原！ >> $LOG_FILE
		clean
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
	clean
}

case $2 in
backup)
	echo_date "============= 开始备份 =============" > $LOG_FILE
	check_backup
	backup_conf
	http_response "$1"
	;;
restore)
	echo_date "============= 开始还原 =============" > $LOG_FILE
	http_response "$1"
	check_backup
	if [ -f "/tmp/upload/mc_backup.tar.gz" ]; then
		echo_date "检测到还原文件..." >> $LOG_FILE
		restore_run
	else
		echo_date "❌未检测到还原文件..." >> $LOG_FILE
		echo_date "退出..." >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
	echo BBABBBBC >>  $LOG_FILE
	;;
esac
