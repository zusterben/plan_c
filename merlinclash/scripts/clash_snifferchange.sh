#! /bin/sh

alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
source /jffs/softcenter/scripts/base.sh
eval `dbus export merlinclash`
SOFT_DIR=/koolshare
lan_ipaddr=$(nvram get lan_ipaddr)
LOG_FILE=/tmp/upload/merlinclash_log.txt

OS=$(uname -r)
#=======================================

rm -rf /tmp/upload/clash_snifferrules.log
rm -rf /tmp/upload/clash_snifferrules.txt

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

count=$(get merlinclash_sniffer_content_count)
sleep 1

if [ -n "$count" ];then
	i=0
	while [ "$i" -lt "$count" ]
	do
		txt=$(get merlinclash_sniffer_content_$i)
		#开始拼接文件值，然后进行base64解码，写回文件
		content=${content}${txt}
		let i=i+1
	done
	echo $content| base64_decode > /tmp/sniffer.txt
	if [ -f /tmp/sniffer.txt ]; then
		echo_date "中间文件已经创建" >> $LOG_FILE
		echo_date "生成新文件" >> $LOG_FILE
		cat /tmp/sniffer.txt | urldecode > /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml 2>&1
		rm -rf /tmp/sniffer.txt
	fi
	#dbus remove jdqd_jd_script_content_custom
	customs=`dbus list merlinclash_sniffer_content_ | cut -d "=" -f 1`
	for custom in $customs
	do
		dbus remove $custom
	done
fi


ln -sf /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml /tmp/upload/clash_sniffercontent.txt

http_response "$1"


