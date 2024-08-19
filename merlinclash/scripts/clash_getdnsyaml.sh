#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
[ ! -L "/tmp/upload/dns_redirhost.txt" ] && ln -s /jffs/softcenter/merlinclash/yaml_dns/redirhost.yaml /tmp/upload/dns_redirhost.txt
[ ! -L "/tmp/upload/dns_fakeip.txt" ] && ln -s /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml /tmp/upload/dns_fakeip.txt
[ ! -L "/tmp/upload/dns_rhbypass.txt" ] && ln -s /jffs/softcenter/merlinclash/yaml_dns/rhbypass.yaml /tmp/upload/dns_rhbypass.txt

http_response $1

