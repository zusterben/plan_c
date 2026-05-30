#!/bin/sh

source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

yamlname=$(get merlinclash_set_yamlsel_start)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
lan_ipaddr=$(nvram get lan_ipaddr)
#提取配置认证码
if [ -s "$yamlpath" ] && [ "$(pidof clash)" -a "$(netstat -anp | grep clash | head -n 5)" ]; then
	rm -rf /tmp/upload/*.mark
	secret=$(cat $yamlpath | awk '/secret:/{print $2}' | sed 's/"//g')
	#提取配置监听端口
	ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}')
	
	curl -s -X GET "http://$lan_ipaddr:$ecport/proxies" -H "Authorization: Bearer $secret" | sed 's/\},/\},\n/g'  | grep "Selector" |grep -Eo "name.*" > /tmp/upload/${yamlname}.mark
	filename=/tmp/upload/${yamlname}.mark

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
		#插入规则类型
		echo "DOMAIN" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-SUFFIX" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-KEYWORD" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-WILDCARD" >> /tmp/upload/proxytype.txt
		echo "DOMAIN-REGEX" >> /tmp/upload/proxytype.txt
		echo "GEOSITE" >> /tmp/upload/proxytype.txt

		echo "IP-CIDR" >> /tmp/upload/proxytype.txt
		echo "SRC-IP-CIDR" >> /tmp/upload/proxytype.txt	
		echo "IP-ASN" >> /tmp/upload/proxytype.txt
		echo "SRC-IP-ASN" >> /tmp/upload/proxytype.txt
		echo "IP-SUFFIX" >> /tmp/upload/proxytype.txt
		echo "SRC-IP-SUFFIX" >> /tmp/upload/proxytype.txt
		echo "GEOIP" >> /tmp/upload/proxytype.txt
		echo "SRC-GEOIP" >> /tmp/upload/proxytype.txt

		echo "DST-PORT" >> /tmp/upload/proxytype.txt
		echo "SRC-PORT" >> /tmp/upload/proxytype.txt

		echo "IN-TYPE" >> /tmp/upload/proxytype.txt
		echo "IN-PORT" >> /tmp/upload/proxytype.txt
		echo "IN-USER" >> /tmp/upload/proxytype.txt
		echo "IN-NAME" >> /tmp/upload/proxytype.txt

		echo "AND" >> /tmp/upload/proxytype.txt
		echo "OR" >> /tmp/upload/proxytype.txt
		echo "NOT" >> /tmp/upload/proxytype.txt

		echo "NETWORK" >> /tmp/upload/proxytype.txt
		echo "DSCP" >> /tmp/upload/proxytype.txt
		echo "SUB-RULE" >> /tmp/upload/proxytype.txt
else
	rm -rf /tmp/upload/proxygroups.txt
	rm -rf /tmp/upload/proxytype.txt
	echo "请启动插件" >> /tmp/upload/proxytype.txt
	echo "请启动插件" >> /tmp/upload/proxygroups.txt		
fi

http_response $1

