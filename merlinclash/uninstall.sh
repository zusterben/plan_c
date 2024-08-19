#!/bin/sh
eval `dbus export merlinclash`
source /jffs/softcenter/scripts/base.sh


if [ "$merlinclash_enable" == "1" ];then
	echo 先关闭clash插件！
	#sh /jffs/softcenter/merlinclash/clashconfig.sh stop
    sleep 1s
	exit 
fi


find /jffs/softcenter/init.d/ -name "*clash*" | xargs rm -rf
rm -rf /jffs/softcenter/bin/clash
rm -rf /jffs/softcenter/bin/yq
#------网易云内容-----------
rm -rf /jffs/softcenter/bin/UnblockNeteaseMusic
rm -rf /jffs/softcenter/bin/UnblockMusic
#------网易云内容-----------
#------koolproxy-----------
rm -rf /jffs/softcenter/bin/koolproxy
#------koolproxy-----------
rm -rf /tmp/upload/yamls.txt
rm -rf /tmp/upload/*_status.txt
rm -rf /tmp/upload/merlinclash*
rm -rf /tmp/upload/dlercloud.log
rm -rf /tmp/upload/host_yaml.txt
rm -rf /tmp/upload/dns_redirhost.txt
rm -rf /tmp/upload/dns_redirhostp.txt
rm -rf /tmp/upload/dns_fakeip.txt
rm -rf /tmp/upload/razord
rm -rf /tmp/upload/yacd

rm -rf /jffs/softcenter/bin/subconverter
rm -rf /jffs/softcenter/bin/mc_dns2socks
rm -rf /jffs/softcenter/res/icon-merlinclash.png
rm -rf /jffs/softcenter/res/clash-dingyue.png
rm -rf /jffs/softcenter/res/clash-kcp.jpg
rm -rf /jffs/softcenter/res/clash*
rm -rf /jffs/softcenter/res/merlinclash.css
rm -rf /jffs/softcenter/res/mc-tablednd.js
rm -rf /jffs/softcenter/res/mc-menu.js
rm -rf /jffs/softcenter/res/china_ip_route.ipset
rm -rf /jffs/softcenter/res/china_ip_route6.ipset
#
rm -rf /jffs/softcenter/res/DisneyPlus_Domains.list
rm -rf /jffs/softcenter/res/Netflix_Domains.list
rm -rf /jffs/softcenter/res/Netflix_Domains_Custom.list
#
rm -rf /jffs/softcenter/merlinclash/Country.mmdb
rm -rf /jffs/softcenter/merlinclash/GeoIP.dat
rm -rf /jffs/softcenter/merlinclash/clashconfig.sh
rm -rf /jffs/softcenter/merlinclash/clashconfig_0101.sh
rm -rf /jffs/softcenter/merlinclash/yaml_bak/*
rm -rf /jffs/softcenter/merlinclash/yaml_use/*
rm -rf /jffs/softcenter/merlinclash/yaml_basic/*
rm -rf /jffs/softcenter/merlinclash/yaml_dns/*
rm -rf /jffs/softcenter/merlinclash/subconverter/*
rm -rf /jffs/softcenter/merlinclash/conf/*
rm -rf /jffs/softcenter/merlinclash/koolproxy/*
rm -rf /jffs/softcenter/merlinclash/dashboard/*
rm -rf /jffs/softcenter/scripts/clash*.sh
rm -rf /jffs/softcenter/webs/Module_merlinclash.asp
rm -rf /jffs/softcenter/merlinclash
rm -rf /jffs/softcenter/scripts/merlinclash_install.sh
rm -rf /jffs/softcenter/scripts/uninstall_merlinclash.sh
rm -rf /tmp/dc*
rm -rf /tmp/etc/dnsmasq.user/clash*
rm -rf /tmp/etc/dnsmasq.user/koolproxy*
rm -rf /tmp/etc/dnsmasq.user/dns_custom.conf >/dev/null 2>&1

ipset flush music
ipset destroy music
#清除相关skipd数据

datas=`dbus list merlinclash_ | cut -d "=" -f 1`
for data in $datas
do
	dbus remove $data
done
dbus remove softcenter_module_merlinclash_install
dbus remove softcenter_module_merlinclash_version
