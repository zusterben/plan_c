#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

mkdir -p /jffs/softcenter/merlinclash/rule_use

urldecode(){
  echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x\1/g;')"
}

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

count=$(get merlinclash_cusrule_edit_content1_count)
yamlname=$(get merlinclash_yamlsel)
sleep 1
if [ -n "$count" ];then
	i=0
	while [ "$i" -lt "$count" ]
	do
		txt=$(get merlinclash_cusrule_edit_content1_$i)
		#开始拼接文件值，然后进行base64解码，写回文件
		content=${content}${txt}
		let i=i+1
	done
	echo $content| base64_decode > /tmp/cusrule.txt
	if [ -f /tmp/cusrule.txt ]; then
		echo_date "中间文件已经创建" >> $LOG_FILE
		echo_date "生成新文件" >> $LOG_FILE
		cat /tmp/cusrule.txt | urldecode > /jffs/softcenter/merlinclash/rule_use/${yamlname}_rules.yaml 2>&1
	#	rm -rf /tmp/cusrule.txt
	fi
	#dbus remove jdqd_jd_script_content_custom
	customs=`dbus list merlinclash_cusrule_edit_content1_ | cut -d "=" -f 1`
	for custom in $customs
	do
		dbus remove $custom
	done
fi


rm -rf /tmp/upload/${yamlname}_rules.txt

if [ -f "/jffs/softcenter/merlinclash/rule_use/${yamlname}_rules.yaml" ]; then
	ln -sf /jffs/softcenter/merlinclash/rule_use/${yamlname}_rules.yaml /tmp/upload/${yamlname}_rules.txt
else
	ln -sf /jffs/softcenter/merlinclash/rule_bak/${yamlname}_rules.yaml /tmp/upload/${yamlname}_rules.txt
fi



http_response "$1"
