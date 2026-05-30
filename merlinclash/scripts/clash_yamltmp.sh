#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

yamlname=${merlinclash_set_yamlsel_start}

yamlsel_tmp2=$yamlname

http_response "$yamlsel_tmp2"

