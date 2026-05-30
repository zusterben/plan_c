#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
# 配置下拉列表
if [ -f "/jffs/softcenter/merlinclash/yaml_bak/yamls.txt" ]; then
    ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
else
    rm -rf /tmp/upload/yamls.txt 
fi
#host
rm -rf  /tmp/upload/clash_hosts.txt
ln -sf /jffs/softcenter/merlinclash/yaml_basic/hosts.yaml /tmp/upload/clash_hosts.txt
#head
rm -rf  /tmp/upload/clash_head.txt
ln -sf /jffs/softcenter/merlinclash/yaml_basic/head.yaml /tmp/upload/clash_head.txt
#dns
[ ! -L "/tmp/upload/clash_redirhost.txt" ] && ln -s /jffs/softcenter/merlinclash/yaml_dns/redirhost.yaml /tmp/upload/clash_redirhost.txt
[ ! -L "/tmp/upload/clash_fakeip.txt" ] && ln -s /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml /tmp/upload/clash_fakeip.txt
#sniffer
rm -rf /tmp/upload/clash_sniffercontent.txt
ln -sf /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml /tmp/upload/clash_sniffercontent.txt
#iptlist
rm -rf /tmp/upload/clash_ipsetproxyarround.txt
rm -rf /tmp/upload/clash_ipsetproxy.txt
if [ -f "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml" ]; then
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml /tmp/upload/clash_ipsetproxyarround.txt
fi
if [ -f "/jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml" ]; then
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml /tmp/upload/clash_ipsetproxy.txt
fi
#自定义规则
rm /tmp/upload/clash_rule.txt
if [ -f "/jffs/softcenter/merlinclash/rule_custom/${merlinclash_set_yamlsel_start}_custom_rule.yaml" ]; then
	ln -sf /jffs/softcenter/merlinclash/rule_custom/${merlinclash_set_yamlsel_start}_custom_rule.yaml /tmp/upload/clash_rule.txt
fi

http_response $1
