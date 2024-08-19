#!/bin/sh
 
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
upload_path=/tmp/upload
mkdir -p /jffs/softcenter/merlinclash/subconverter/rules/custom

move_list(){
	#查找upload文件夹是否有刚刚上传的yaml文件，正常只有一份
	#name=$(find $uploadpath  -name "$yamlname.yaml" |sed 's#.*/##')
	echo_date "上传的文件名是$merlinclash_uploadlistfile" >> $LOG_FILE
	if [ -f "/tmp/upload/$merlinclash_uploadlistfile" ]; then		
		cp -rf /tmp/upload/$merlinclash_uploadlistfile /jffs/softcenter/merlinclash/subconverter/rules/custom/$merlinclash_uploadlistfile
		rm -rf /tmp/upload/$merlinclash_uploadlistfile

		rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamlscuslist.txt
		echo_date "创建自定义list文件列表"

		find /jffs/softcenter/merlinclash/subconverter/rules/custom  -name "*.list" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> /jffs/softcenter/merlinclash/yaml_bak/yamlscuslist.txt
		#创建软链接
		ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamlscuslist.txt /tmp/upload/yamlscuslist.txt
		#
	else
		echo_date "没找到上传的list文件" >> $LOG_FILE
		rm -rf /tmp/upload/$merlinclash_uploadlistfile
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi


}

case $2 in
29)
	echo "本地上传list文件" > $LOG_FILE
	http_response "$1"
	move_list >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
esac
