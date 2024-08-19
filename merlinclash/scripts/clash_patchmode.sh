#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
LOGFILE=/tmp/upload/merlinclash_log.txt
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
#配置文件路径
yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
#提取配置认证码
secret=$(cat $yamlpath | awk '/secret:/{print $2}' | sed 's/"//g')
#提取配置监听端口
ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}')

lan_ipaddr=$(nvram get lan_ipaddr)
modesel=$(get merlinclash_clashmode)
if [ "$modesel" == "default" ]; then
    modesel=$(cat $yamlpath | grep "^mode:" | awk -F "[: ]" '{print $3}' | xargs echo -n)
fi

curl -sv \
-H "Authorization: Bearer $secret" \
-X PATCH "http://$lan_ipaddr:$ecport/configs/"  -d "{\"mode\": \"$modesel\"}" 2>&1

curl -sv \
-H "Authorization: Bearer $secret" \
-X DELETE "http://$lan_ipaddr:$ecport/connections"  2>&1

http_response $1

