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
upload_path=/tmp/upload
rulename=$(get merlinclash_uploadrulename)
name=$(echo "$rulename"|sed 's/.tar.gz//g')
upload_file=/tmp/upload/$rulename
MODEL=$(nvram get productid)

yamlname=$(get merlinclash_yamlsel)
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml

clean(){
	[ -n "$name" ] && rm -rf /tmp/kprule >/dev/null 2>&1
	rm -rf /tmp/upload/*.tar.gz >/dev/null 2>&1
}

check_rulename(){
	chmod +x $upload_file
	rm -rf /tmp/kprule
	mkdir -p /tmp/kprule
	mv $upload_file /tmp/kprule
	cd /tmp/kprule

	echo_date 尝试解压补丁包 >> $LOG_FILE
	tar -zxvf $rulename >/dev/null 2>&1
	if [ "$?" == "0" ];then
		echo_date 解压完成！ >> $LOG_FILE
	else
		echo_date 解压错误，错误代码："$?"！ >> $LOG_FILE
		echo_date 估计是错误或者不完整的的离线安装包！ >> $LOG_FILE
		echo_date 删除相关文件并退出... >> $LOG_FILE
		cd
		clean
		echo BBABBBBC >> $LOG_FILE
		exit
	fi
	#检查规则包是否有规则，否则为不合法规则包
	if [ -f "/tmp/kprule/$name/rules/kp.dat" ] || [ -f "/tmp/kprule/$name/rules/daily.txt" ] || [ -f "/tmp/kprule/$name/rules/koolproxy.txt" ]; then
			echo_date "规则文件检查通过!" >> $LOG_FILE
			local_rule_replace
	else
		echo_date "获取不到规则文件！" >> $LOG_FILE
		echo_date "清除上传文件，退出。" >> $LOG_FILE
		cd
		clean
		echo BBABBBBC
		exit 1
	fi



	
}

local_rule_replace(){
	echo_date 检测jffs分区剩余空间...
	SPACE_AVAL=$(df|grep jffs|head -n 1 | awk '{print $4}')
	SPACE_NEED=$(du -s /tmp/kprule/$name | awk '{print $1}')
	if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 规则安装需要"$SPACE_NEED" KB，空间满足，继续安装！		
		replace_rule
	else
		echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 规则安装需要"$SPACE_NEED" KB，空间不足！
		echo_date 退出安装！
		cd
		clean
		echo BBABBBBC
		exit 1
	fi
	
}

replace_rule(){
	echo_date "开始更新规则!" >> $LOG_FILE
	if [ "$(pidof koolproxy)" ];then
		echo_date "为了保证更新正确，先关闭koolproxy进程... " >> $LOG_FILE
		killall koolproxy >/dev/null 2>&1
		move_rule
		sleep 1
		start_koolproxy
	else
		move_rule
	fi
}
#更新补丁，检查setup.sh文件，存在更新，否则退出，重启clash；
#更新完成，重新对version赋值
#	CUR_VERSION=$(cat /jffs/softcenter/merlinclash/version)
#	dbus set merlinclash_version_local="$CUR_VERSION"
#	dbus set softcenter_module_merlinclash_version="$CUR_VERSION"
#	dbus set merlinclash_patch_version="$patchlocal"
move_rule(){
	echo_date "检查koolproxy进程完毕，继续更新规则... " >> $LOG_FILE
	install_rule
	echo_date "规则更新完成" >> $LOG_FILE
}

install_rule(){
	echo_date 开始复制文件！ >> $LOG_FILE	
	cp -rf /tmp/kprule/$name/rules/daily.txt /jffs/softcenter/merlinclash/koolproxy/data/rules/
	cp -rf /tmp/kprule/$name/rules/koolproxy.txt /jffs/softcenter/merlinclash/koolproxy/data/rules
	cp -rf /tmp/kprule/$name/rules/kp.dat /jffs/softcenter/merlinclash/koolproxy/data/rules
	echo_date 规则更新完毕! >> $LOG_FILE
}
start_koolproxy(){
	echo_date "开启koolproxy进程... " >> $LOG_FILE

	/bin/sh /jffs/softcenter/scripts/clash_koolproxyconfig.sh restart
	cd
	rm -rf /tmp/kprule
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
33)
	echo "本地上传规则包" > $LOG_FILE
	http_response "$1"
	check_rulename >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
esac
