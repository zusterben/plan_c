#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
lan_ipaddr=$(nvram get lan_ipaddr)
clash_type=$(/jffs/softcenter/bin/clash -v | grep Meta)
#提取配置认证码
if [ -s "$yamlpath" ] ; then
	rm -rf /tmp/upload/*.mark
	secret=$(cat $yamlpath | awk '/secret:/{print $2}' | sed 's/"//g')
	#提取配置监听端口
	ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}')
	
	curl -s -X GET "http://$lan_ipaddr:$ecport/proxies" -H "Authorization: Bearer $secret" | sed 's/\},/\},\n/g'  | grep "Selector" |grep -Eo "name.*" > /tmp/upload/${yamlname}.mark
	filename=/tmp/upload/${yamlname}.mark

	#filename=$dirtmp/mark/${yamlname}_new.txt
	markMD5tmp=$(md5sum $yamlpath|awk '{print $1}')
	
	dbus set merlinclash_mark_MD52="$markMD5tmp"

		rm -rf /tmp/upload/proxygroups.txt
		rm -rf /tmp/upload/proxytype.txt
		lines=$(cat $filename | wc -l)
		i=1
		while [ "$i" -le "$lines" ]
		do
			line=$(sed -n ''$i'p' "$filename")
			#echo $line
			#echo ""
			names=$(echo $line |grep -o "name.*"|awk -F\" '{print $3}')
			echo $names >> /tmp/upload/proxygroups.txt
				let i=i+1
		done
		#往头部插入两个连接方式，删除GLOBAL
		sed -i '/GLOBAL/d' /tmp/upload/proxygroups.txt
		sed -i "1i\REJECT" /tmp/upload/proxygroups.txt
		sed -i "1i\DIRECT" /tmp/upload/proxygroups.txt
		dbus set merlinclash_mark_MD51="$markMD5tmp"
		

	#fi	
		
		echo "SRC-IP-CIDR" >> /tmp/upload/proxytype.txt
		echo "IP-CIDR" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-SUFFIX" >> /tmp/upload/proxytype.txt
		echo "DOMAIN" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-KEYWORD" >> /tmp/upload/proxytype.txt
		echo "DST-PORT" >> /tmp/upload/proxytype.txt
		echo "SRC-PORT" >> /tmp/upload/proxytype.txt
		echo "SCRIPT" >> /tmp/upload/proxytype.txt
		echo "GEOIP" >> /tmp/upload/proxytype.txt
		if [ -n "$clash_type" ]; then
			echo "AND" >> /tmp/upload/proxytype.txt
			echo "OR" >> /tmp/upload/proxytype.txt
			echo "NOT" >> /tmp/upload/proxytype.txt
			echo "IN-TYPE" >> /tmp/upload/proxytype.txt
			echo "GEOSITE" >> /tmp/upload/proxytype.txt
		fi
		
fi

http_response $1

