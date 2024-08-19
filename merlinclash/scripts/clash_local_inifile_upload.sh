#!/bin/sh
 
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
upload_path=/tmp/upload
mkdir -p /jffs/softcenter/merlinclash/subconverter/customconfig
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
ininame=$(get merlinclash_uploadininame)
move_ini(){
	#查找upload文件夹是否有刚刚上传的yaml文件，正常只有一份
	#name=$(find $uploadpath  -name "$yamlname.yaml" |sed 's#.*/##')
	echo_date "上传的文件名是$ininame" >> $LOG_FILE
	if [ -f "/tmp/upload/$ininame" ]; then
		#后台执行上传文件名.yaml处理工作，包括去注释，去空白行，去除dns以上头部，将标准头部文件复制一份到/tmp/ 跟tmp的标准头部文件合并，生成新的head.yaml，再将head.yaml复制到/jffs/softcenter/merlinclash/并命名为上传文件名.yaml
		#echo_date "后台执行yaml文件处理工作"
		#sh /jffs/softcenter/scripts/clash_yaml_sub.sh >/dev/null 2>&1 &
		cp -rf /tmp/upload/$ininame /jffs/softcenter/merlinclash/subconverter/customconfig/$ininame
		rm -rf /tmp/upload/$ininame

		rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamlscus.txt
		echo_date "创建自定义订阅文件列表"

		find /jffs/softcenter/merlinclash/subconverter/customconfig  -name "*.ini" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> /jffs/softcenter/merlinclash/yaml_bak/yamlscus.txt
		#创建软链接
		ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamlscus.txt /tmp/upload/yamlscus.txt
		#
	else
		echo_date "没找到上传的ini配置文件" >> $LOG_FILE
		rm -rf /tmp/upload/$ininame
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi


}

case $2 in
28)
	echo "本地上传ini配置文件" > $LOG_FILE
	http_response "$1"
	move_ini >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE	
	;;
esac
