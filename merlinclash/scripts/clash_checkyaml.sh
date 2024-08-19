#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

yamlpath=$1

sh /jffs/softcenter/scripts/clash_string.sh $yamlpath
#20210603增加BOM字符处理
BOM=$(grep -I -r -l $'\xEF\xBB\xBF' $yamlpath)
if [ -n "$BOM" ]; then
	sed -i $'s/\xef\xbb\xbf//' $yamlpath
fi
para1=$(sed -n '/^port:/p' $yamlpath)
para1_1=$(sed -n '/^mixed-port:/p' $yamlpath)
if [ -n "$para1_1" ] ; then
    sed -i 's/^mixed-port:/port:/g' $yamlpath
	echo_date "配置文件存在mixed-port:参数，修改成port:" >> $LOG_FILE
   fi
para2=$(sed -n '/^socks-port:/p' $yamlpath)
proxies_line=$(cat $yamlpath | grep -n "^proxies:" | awk -F ":" '{print $1}')

#COMP 左>右，值-1；左等于右，值0；左<右，值1
port_line=$(cat $yamlpath | grep -n "^port:" | awk -F ":" '{print $1}' | head -1)
echo_date "port:行数为$port_line" >> $LOG_FILE
echo_date "proxies:行数为$proxies_line" >> $LOG_FILE
if [ -z "$port_line" ] ; then
	echo_date "配置文件缺少port:参数，无法创建yaml文件" >> $LOG_FILE
	return 0
fi
if [ -z "$proxies_line" ]; then
    echo_date "配置文件缺少proxies:参数，无法创建yaml文件" >> $LOG_FILE
	return 0
fi
if [ -z "$para1" ] && [ -z "$para1_1" ]; then
	echo_date "配置文件不是合法的yaml文件，请检查订阅连接是否有误" >> $LOG_FILE
	return 0
else
	echo_date "配置文件检查通过，继续下一步" >> $LOG_FILE
	return 1
fi




