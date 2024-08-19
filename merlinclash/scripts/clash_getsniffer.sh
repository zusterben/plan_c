#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#

rm -rf /tmp/upload/clash_sniffercontent.txt

ln -sf /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml /tmp/upload/clash_sniffercontent.txt

http_response $1

