#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
if [ -f "/jffs/softcenter/merlinclash/yaml_bak/yamls.txt" ]; then
    ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
else
    rm -rf /tmp/upload/yamls.txt 
fi

if [ -f "/jffs/softcenter/merlinclash/yaml_bak/yamlscus.txt" ]; then
    ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamlscus.txt /tmp/upload/yamlscus.txt
else
    rm -rf /tmp/upload/yamlscus.txt
fi

if [ -f "/jffs/softcenter/merlinclash/yaml_bak/yamlscuslist.txt" ]; then
    ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamlscuslist.txt /tmp/upload/yamlscuslist.txt
else
    rm -rf /tmp/upload/yamlscuslist.txt 
fi
http_response $1

