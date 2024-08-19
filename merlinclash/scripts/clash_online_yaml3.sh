#!/bin/sh

source /jffs/softcenter/scripts/base.sh
#source helper.sh
eval $(dbus export ss)
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
head_tmp=/jffs/softcenter/merlinclash/yaml_basic/head.yaml
lan_ip=$(nvram get lan_ipaddr)

rm -rf /tmp/upload/merlinclash_log.txt
rm -rf /tmp/upload/*.yaml
cp -rf /jffs/softcenter/merlinclash/yaml_basic/proxies.yaml /tmp/upload/proxies.yaml
cp -rf /jffs/softcenter/merlinclash/yaml_basic/proxy-group.yaml /tmp/upload/proxy-group.yaml
LOCK_FILE=/var/lock/yaml_online_update.lock
Regularlog=/tmp/upload/merlinclash_regular.log
flag=0
upname=""
upname_tmp=""
num=0
pronum=0
n=0

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
rule_version=$(get merlinclash_proxygroup_version)

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


get_ss_rule_now(){
	echo_date "获取本地小飞机节点信息"
	#节点总数
	nums=$(echo $(dbus list ss | grep -v "ss_basic_enable" | grep -v "ssid_" | sed 's/=/=\"/' | sed 's/$/\"/g' | grep -c "^ssconf_basic_type"))
	echo_date "小飞机节点总数是$nums"
	if [ $nums -gt 0 ]; then
		echo_date "开始转换节点为clash专用yaml格式文件"
		i=1
		while [ "$i" -le "$nums" ]; do
			
			type=$(eval echo \$ssconf_basic_type_${i})
			if [ $type == "0" ]; then
			#为ss节点,进行相对应属性的赋值
				echo_date "检查到ss节点"
				type="ss"
				#节点名去空格，免得出错
				remarks=$(eval echo \$ssconf_basic_name_${i} | sed 's/ //g')
				#echo $remarks
				if [ -z $remarks ]; then
					remarks="ssnodes_$i"
				fi
				server=$(eval echo \$ssconf_basic_server_${i})
				server_port=$(eval echo \$ssconf_basic_port_${i})
				encrypt_method=$(eval echo \$ssconf_basic_method_${i})
				password=$(eval echo \$ssconf_basic_password_${i})
				password=$(echo $password | base64_decode)
				v2ray_plugin=$(eval echo \$ssconf_ss_v2ray_password_${i})
				#20200725 obfs字段添加
				obfs_tmp=$(eval echo \$ssconf_basic_ss_obfs_${i})
				obfs_host=$(eval echo \$ssconf_basic_ss_obfs_host_${i})
				#if [ $v2ray_plugin != "0" ]; then
					#echo "fuzhi"
				#fi
				#add ss节点
				echo_date "转换ss节点：$n--$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].name "$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].type "ss"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].server $server
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].port $server_port
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].cipher $encrypt_method
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].password $password
				if [ "$obfs_tmp" == "tls" ]; then
					sed -i "\$i\ \ \- { name: "\"$remarks\"", type: ss, server: "\"$server\"", port: "$server_port", password: "\"$password\"", cipher: "\"$encrypt_method\"", plugin: "obfs", plugin-opts: {mode: "\"$obfs_tmp\"", host: "\"$obfs_host\""}, udp: true}" /tmp/upload/proxies.yaml
				else
					sed -i "\$i\ \ \- { name: "\"$remarks\"", type: ss, server: "\"$server\"", port: "$server_port", password: "\"$password\"", cipher: "\"$encrypt_method\"" }" /tmp/upload/proxies.yaml
				fi
				let n++
				
			elif [ $type == "1" ]; then
				echo_date "检查到ssr节点"
				type="ssr"
				#节点名去空格，免得出错
				remarks=$(eval echo \$ssconf_basic_name_${i} | sed 's/ //g')
				#echo $remarks
				if [ -z $remarks ]; then
					remarks="ssrnodes_$i"
				fi
				server=$(eval echo \$ssconf_basic_server_${i})
				server_port=$(eval echo \$ssconf_basic_port_${i})
				encrypt_method=$(eval echo \$ssconf_basic_method_${i})
				password=$(eval echo \$ssconf_basic_password_${i})
				password=$(echo $password | base64_decode)
				protocol=$(eval echo \$ssconf_basic_rss_protocol_${i})
				protocolparam=$(eval echo \$ssconf_basic_rss_protocol_param_${i})
				obfs=$(eval echo \$ssconf_basic_rss_obfs_${i})
				obfsparam=$(eval echo \$ssconf_basic_rss_obfs_param_${i})

				#if [ $v2ray_plugin != "0" ]; then
				#	echo "fuzhi"
				#fi
				#add ss节点
				echo_date "转换ssr节点：$n--$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].name "$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].type "ssr"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].server $server
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].port $server_port
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].cipher $encrypt_method
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].password $password
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].protocol $protocol
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].protocolparam $protocolparam
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].obfs $obfs
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].obfsparam $obfsparam
				sed -i "\$i\ \ \- { name: "\"$remarks\"", type: ssr, server: "\"$server\"", port: "$server_port", password: "\"$password\"", cipher: "\"$encrypt_method\"", protocol: "\"$protocol\"", protocol-param: "\"$protocolparam\"",protocolparam: "\"$protocolparam\"", obfs: "\"$obfs\"", obfs-param: "\"$obfsparam\"", obfsparam: "\"$obfsparam\"" }" /tmp/upload/proxies.yaml
				let n++
			#为ssr节点
			elif [ $type == "2" ]; then
				echo_date "koolgame节点跳过"
			elif [ $type == "3" ]; then
			#为v2ray节点
				echo_date "检查到v2ray节点"
				type="vmess"
				#节点名去空格，免得出错
				remarks=$(eval echo \$ssconf_basic_name_${i} | sed 's/ //g')
				#echo $remarks
				if [ -z $remarks ]; then
					remarks="v2raynodes_$i"
				fi
				server=$(eval echo \$ssconf_basic_server_${i})
				server_port=$(eval echo \$ssconf_basic_port_${i})
				v2ray_id=$(eval echo \$ssconf_basic_v2ray_uuid_${i})
				v2ray_aid=$(eval echo \$ssconf_basic_v2ray_alterid_${i})
				cipher=$(eval echo \$ssconf_basic_v2ray_security_${i})
				net=$(eval echo \$ssconf_basic_v2ray_network_${i})
				network_path=$(eval echo \$ssconf_basic_v2ray_network_path_${i})
				tls_tmp=$(eval echo \$ssconf_basic_v2ray_network_security_${i})
				network_host=$(eval echo \$ssconf_basic_v2ray_network_host_${i})

				[ "$tls_tmp"x == "tls"x ] && tls="true" || tls="false"
				
				
				#add ss节点
				echo_date "转换v2ray节点：$n--$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].name "$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].type "vmess"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].server $server
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].port $server_port
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].uuid $v2ray_id
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].cipher $cipher
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].alterId $v2ray_aid
				sed -i "\$i\ \ \- { name: "\"$remarks\"", type: vmess, server: "\"$server\"", port: "$server_port", uuid: "\"$v2ray_id\"", alterId: "\"$v2ray_aid\"", cipher: "\"$cipher\"", tls: "$tls", network: "\"$net\"", ws-path: "\"$network_path\"", ws-headers: {Host: "\"$network_host\""}}" /tmp/upload/proxies.yaml
	
				let n++		
			elif [ $type == "4" ]; then
			#为trojan节点
				echo_date "检查到trojan节点"
				type="trojan"
				#节点名去空格，免得出错
				remarks=$(eval echo \$ssconf_basic_name_${i} | sed 's/ //g')
				#echo $remarks
				if [ -z $remarks ]; then
					remarks="tjnodes_$i"
				fi
				server=$(eval echo \$ssconf_basic_server_${i})
				server_port=$(eval echo \$ssconf_basic_port_${i})
				password=$(eval echo \$ssconf_basic_password_${i})
				password=$(echo $password | base64_decode)
				#if [ $v2ray_plugin != "0" ]; then
				#	echo "fuzhi"
				#fi
				#add ss节点
				echo_date "转换trojan节点：$n--$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].name "$remarks"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].type "trojan"
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].server $server
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].port $server_port
				#yq w -i /tmp/upload/proxies.yaml proxies[$n].password $password
				sed -i "\$i\ \ \- { name: "\"$remarks\"", type: trojan, server: "\"$server\"", port: "$server_port", password: "\"$password\"", sni: "\"$server\"" }" /tmp/upload/proxies.yaml
	
				let n++	
			elif [ $type == "5" ]; then
				echo_date "trojan-go节点跳过"
			fi
			let i++
			continue
		done
		echo_date "节点转换完毕"
		write_yaml	
	else
		echo_date "本地小飞机没有节点，退出"
	fi
	#
	#节点关键字段：
	#节点类型ssconf_basic_type_1 0=ss 1=ssr 2=koolgame 3=v2ray 4=trojan 5=trojan-go  2/5可以直接排除
	#节点名ssconf_basic_name_1 
	#节点服务器地址ssconf_basic_server_1
	#节点端口ssconf_basic_port_1
	#节点密码ssconf_basic_password_1
	#节点加密方式ssconf_basic_method_1
	
}


write_yaml(){
	echo_date "开始写入节点名称"
	#test=$(echo $(yq r /tmp/upload/proxies.yaml proxies[*].name))
	#20200724改用工具
	#test=$(grep  "name" /tmp/upload/proxies.yaml | awk -F","  '{print $1}' | awk -F":" '{print $2}' | awk -F "[\"\"]" '{print $2}')
	test=$(grep  "name" /tmp/upload/proxies.yaml | awk -F","  '{print $1}' | awk -F "[\"\"]" '{print $2}')
	for t in $test;
	do 
		str=$str,"\"$t"\"
	done
	proxy=$(echo $str |  awk '{print substr($1,2)}')
	sleep 1s
	sed -i "s?url-test, proxies,?url-test, proxies: [$proxy],?g" /tmp/upload/proxy-group.yaml
	sed -i "s?fallback, proxies,?fallback, proxies: [$proxy],?g" /tmp/upload/proxy-group.yaml
	sed -i "s?load-balance, proxies,?load-balance, proxies: [$proxy],?g" /tmp/upload/proxy-group.yaml
	sed -i "s?type: select, proxies}?type: select, proxies: [$proxy]}?g" /tmp/upload/proxy-group.yaml
	echo_date "写入完成,将对文件进行合并"
	#yq m -x -i /tmp/upload/proxies.yaml /tmp/upload/proxy-group.yaml
	sed -i '$a' /tmp/upload/proxies.yaml
	cat /tmp/upload/proxy-group.yaml >> /tmp/upload/proxies.yaml
	sed -i '$a' /tmp/upload/proxies.yaml
	cat $head_tmp >> /tmp/upload/proxies.yaml
	echo_date "标准头文件合并完毕" >> $LOG_FILE
	#对external-controller赋值
	#yq w -i $yaml_tmp external-controller $lan_ip:9990
	sed -i "s/192.168.2.1:9990/$lan_ip:9990/g" /tmp/upload/proxies.yaml
	
	#写入hosts
	#yq w -i $yaml_tmp 'hosts.[router.asus.com]' $lan_ip
	sed -i '$a hosts:' /tmp/upload/proxies.yaml
	sed -i '$a \ \ router.asus.com: '"$lan_ip"'' /tmp/upload/proxies.yaml
	rename_yaml
}
rename_yaml(){
	upname_tmp=$(get merlinclash_uploadrename3)
	time=$(date "+%Y%m%d-%H%M%S")
	newname=$(echo $time | awk -F'-' '{print $2}')
	if [ -n "$upname_tmp" ]; then
		upname=$upname_tmp.yaml
	else
		upname=$newname.yaml
	fi
	echo_date "文件重命名后复制到/jffs/softcenter/merlinclash/yaml_bak/" >> $LOG_FILE
	echo_date "以及/jffs/softcenter/merlinclash/yaml_use/" >> $LOG_FILE
	cp -rf /tmp/upload/proxies.yaml /jffs/softcenter/merlinclash/yaml_bak/$upname
	cp -rf /tmp/upload/proxies.yaml /jffs/softcenter/merlinclash/yaml_use/$upname
	#清理残留
	rm -rf /tmp/upload/*.yaml
	#生成新的txt文件

	rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	echo_date "重新创建yaml文件列表" >> $LOG_FILE

	find /jffs/softcenter/merlinclash/yaml_bak  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
	#
	echo_date "订阅处理完毕，请刷新页面查看下拉框是否存在配置名"
}
set_lock(){
	exec 233>"$LOCK_FILE"
	flock -n 233 || {
		echo_date "一键转换已经在运行，请稍候再试！" >> $LOG_FILE	
		unset_lock
	}
}

unset_lock(){
	flock -u 233
	rm -rf "$LOCK_FILE"
}

case $2 in
6)
	set_lock
	echo_date "飞机节点一键转换" > $LOG_FILE
	http_response "$1"
	get_ss_rule_now >> $LOG_FILE

	echo BBABBBBC >> $LOG_FILE
	unset_lock
	;;
esac

