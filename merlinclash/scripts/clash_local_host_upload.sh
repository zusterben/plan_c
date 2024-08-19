#!/bin/sh
 
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
upload_path=/tmp/upload/host
fp=/jffs/softcenter/merlinclash/yaml_basic/host
name=$(find $upload_path  -name "*.yaml" |sed 's#.*/##')
echo_date "Hosts文件名是：$name" >> $LOG_FILE
host_tmp=/tmp/upload/host/$name
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
uphost=$(get merlinclash_uploadhost)
move_host(){
	#查找upload文件夹是否有刚刚上传的yaml文件，正常只有一份
	#name=$(find $uploadpath  -name "$yamlname.yaml" |sed 's#.*/##')
	echo_date "上传的文件名是$uphost" >> $LOG_FILE
	if [ -f "/tmp/upload/$uphost" ]; then
		echo_date "检查上传的Hosts是否合法" >> $LOG_FILE
		para1=$(sed -n '/^hosts:/p' /tmp/upload/$uphost)
		if [ -n "$para1" ] ; then
			echo_date "上传的Hosts合法" >> $LOG_FILE
			rm -rf /tmp/upload/host/
			mkdir -p /tmp/upload/host
			
			cp -rf /tmp/upload/$uphost /tmp/upload/host/$uphost
			mv -f /tmp/upload/host/$uphost /jffs/softcenter/merlinclash/yaml_basic/host/$uphost
			rm -rf /tmp/upload/host
			rm -rf /tmp/upload/*.yaml
			#生成新的txt文件
			rm -rf $fp/hosts.txt
			echo_date "创建Hosts文件列表" >> $LOG_FILE
			echo 
			find $fp  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $fp/hosts.txt
		
		else
			echo_date "上传的Hosts不合法，请检查，即将退出" >> $LOG_FILE
			rm -rf /tmp/upload/$uphost
			echo BBABBBBC >> $LOG_FILE
			exit 1
		fi
		
	else
		echo_date "没找到上传的Hosts文件" >> $LOG_FILE
		rm -rf /tmp/upload/$uphost
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi


}

case $2 in
22)
	echo "本地上传Hosts文件" > $LOG_FILE
	http_response "$1"
	move_host >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
esac
