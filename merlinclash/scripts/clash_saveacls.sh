#!/bin/sh

source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
LOG_FILE=/tmp/upload/merlinclash_log.txt
mkdir -p /jffs/softcenter/merlinclash/rule_custom

yamlname=${merlinclash_set_yamlsel_start}

save_yaml(){
    rm -rf /jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml
    acl_nu=$(get_list merlinclash_acl_type 1 4)
	num=0
	if [ -n "$acl_nu" ]; then
		for acl in $acl_nu; do
			type=$(eval echo \$merlinclash_acl_type_$acl)
			content=$(eval echo \$merlinclash_acl_content_$acl)
			lianjie=$(eval echo \$merlinclash_acl_lianjie_$acl)
            type=$(decode_url_link "$type")
			content=$(decode_url_link "$content")
			lianjie=$(decode_url_link "$lianjie")
			type=$(urldecode "$type")
			content=$(urldecode "$content")
			lianjie=$(urldecode "$lianjie")
            echo $type,$content,$lianjie >> /jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml
	    done
	else
	    echo "none"
	fi
}
push_dbus(){
    if [ -f "/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml" ]; then
        acl_nu=$(get_list merlinclash_acl_type 1 4)
        echo_date "当前配置有自定义规则，注入自定义规则到数据库" >> $LOG_FILE
            if [ -n "$acl_nu" ]; then
                for acl in $acl_nu; do
                    dbus remove merlinclash_acl_type_$acl
                    dbus remove merlinclash_acl_content_$acl
                    dbus remove merlinclash_acl_lianjie_$acl
                done
            fi
            #当配置文件变化，且存在自定义规则文件时，从rule_custom中的文件字典读取各值重新赋值还原
            rulecusfile="/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml"
            lines=$(cat $rulecusfile | wc -l)
            echo_date "存在自定义规则：$lines条" >> $LOG_FILE
            if [ $lines -gt 0 ]; then
                i=1
                while [ "$i" -le "$lines" ]
                do
                    line=$(sed -n ''$i'p' "$rulecusfile")
                    type=$(echo "$line" | awk -F',' '{print $1}')
                    remaining=$(echo "$line" | cut -d',' -f2-)
                    # 使用awk智能提取content和lianjie
                    eval $(echo "$remaining" | awk '
                    {
                        depth = 0
                        for (i = 1; i <= length($0); i++) {
                            c = substr($0, i, 1)
                            if (c == "(") depth++
                            else if (c == ")") depth--
                            else if (c == "," && depth == 0) {
                                content = substr($0, 1, i-1)
                                action = substr($0, i+1)
                                break
                            }
                        }
                        if (content == "") content = $0
                        printf("content='\''%s'\''\n", content)
                        printf("lianjie='\''%s'\''\n", action)
                    }')
                    type=$(urlencode "$type")
                    content=$(urlencode "$content")
                    lianjie=$(urlencode "$lianjie")
                    type=$(encode_url_link "$type")
                    content=$(encode_url_link "$content")
                    lianjie=$(encode_url_link "$lianjie")
                    dbus set merlinclash_acl_type_$i=$type
                    dbus set merlinclash_acl_content_$i=$content
                    dbus set merlinclash_acl_lianjie_$i=$lianjie
                    let i++
                done    
            fi
    else
        echo_date "当配置无自定义规则， 清除数据库的值" >> $LOG_FILE
        acl_nu=$(get_list merlinclash_acl_type 1 4)
        if [ -n "$acl_nu" ]; then
			for acl in $acl_nu; do
                dbus remove merlinclash_acl_type_$acl
                dbus remove merlinclash_acl_content_$acl
                dbus remove merlinclash_acl_lianjie_$acl
            done
        fi
    fi
}
case $2 in
save)
    save_yaml
    http_response $1
    ;;
    
del)
    save_yaml
    http_response $1
    ;;

use)
    if [ ${merlinclash_set_yamlsel_startchange} == "1" ]; then
        push_dbus
    fi
    ;;
push)
    push_dbus
    ;;
esac

