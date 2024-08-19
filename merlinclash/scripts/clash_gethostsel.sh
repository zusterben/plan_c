#!/bin/sh

export KSROOT=/koolshare
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#

ln -sf /jffs/softcenter/merlinclash/yaml_basic/host/hosts.txt /tmp/upload/hosts.txt

http_response $1

