#!/bin/sh
eval `dbus export merlinclash`
source /jffs/softcenter/scripts/base.sh


if [ "$merlinclash_enable" == "1" ];then
	echo 先关闭clash插件！
    sleep 1s
	exit 1
fi


find /jffs/softcenter/init.d/ -name "*clash*" | xargs rm -rf
rm -rf /jffs/softcenter/bin/clash
rm -rf /jffs/softcenter/bin/yq
rm -rf /tmp/upload/yamls.txt
rm -rf /tmp/upload/clash_*
rm -rf /tmp/upload/merlinclash*
rm -rf /tmp/upload/dnsfile.log
rm -rf /tmp/upload/proxygroups.txt
rm -rf /tmp/upload/proxytype.txt
rm -rf /tmp/upload/view.txt

rm -rf /jffs/softcenter/res/icon-merlinclash.png
rm -rf /jffs/softcenter/res/clash*
rm -rf /jffs/softcenter/res/merlinclash.css
rm -rf /jffs/softcenter/res/mc-tablednd.js
rm -rf /jffs/softcenter/res/mc-menu.js
rm -rf /jffs/softcenter/res/china*.ipset
rm -rf /jffs/softcenter/res/lan*.ipset
rm -rf /jffs/softcenter/res/ip*.ipset
rm -rf /jffs/softcenter/res/mac*.ipset
#
rm -rf /jffs/softcenter/merlinclash/GeoIP.dat
rm -rf /jffs/softcenter/merlinclash/GeoSite.dat
rm -rf /jffs/softcenter/merlinclash/yaml_bak/*
rm -rf /jffs/softcenter/merlinclash/yaml_use/*
rm -rf /jffs/softcenter/merlinclash/yaml_basic/*
rm -rf /jffs/softcenter/merlinclash/yaml_dns/*
rm -rf /jffs/softcenter/merlinclash/conf/*
rm -rf /jffs/softcenter/merlinclash/rule_configs/*
rm -rf /jffs/softcenter/merlinclash/dashboard/*
rm -rf /jffs/softcenter/scripts/clash*.sh
rm -rf /jffs/softcenter/webs/Module_merlinclash.asp
rm -rf /jffs/softcenter/merlinclash
rm -rf /jffs/softcenter/scripts/merlinclash_install.sh
rm -rf /jffs/softcenter/scripts/uninstall_merlinclash.sh
rm -rf /tmp/etc/dnsmasq.user/clash*
rm -rf /tmp/etc/dnsmasq.user/dns_custom.conf >/dev/null 2>&1
rm -rf /jffs/scripts/dnsmasq.postconf
rm -rf /jffs/scripts/dnsmasq-sdn.postconf

#清除相关skipd数据

datas=`dbus list merlinclash_ | cut -d "=" -f 1`
for data in $datas
do
	dbus remove $data
done
dbus remove softcenter_module_merlinclash_install
dbus remove softcenter_module_merlinclash_version

