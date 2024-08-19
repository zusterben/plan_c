#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#
LOG_FILE=/tmp/upload/merlinclash_log.txt
mkdir -p /jffs/softcenter/merlinclash/rule_custom

b(){
	if [ -f "/jffs/softcenter/bin/base64_decode" ]; then #HND有这个
		base=base64_decode
		echo $base
	elif [ -f "/bin/base64" ]; then #HND是这个
		base=base64
		echo "$base -d"
	elif [ -f "/sbin/base64" ]; then
		base=base64
		echo "$base -d"
	else
		echo_date "固件缺少base64decode，无法正常订阅，直接退出" >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}

decode_url_link(){
	local link=$1
	local len=$(echo $link | wc -L)
	local mod4=$(($len%4))
	b64=$(b)
	echo_date "b64=$b64" >> LOG_FILE
	if [ "$mod4" -gt "0" ]; then
		local var="===="
		local newlink=${link}${var:$mod4}
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	fi
}

urldecode(){
  printf $(echo -n "$1" | sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"\n"
}


get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}

get_list(){
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	echo $b
}

yamlname=$(get merlinclash_yamlsel)

yamlselchange=$(get merlinclash_yamlselchange)
savefile(){
    rm -rf /jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml
    acl_nu=$(get_list merlinclash_acl_type 1 4)
	num=0
	if [ -n "$acl_nu" ]; then
		for acl in $acl_nu; do
			type=$(eval echo \$merlinclash_acl_type_$acl)
			content=$(eval echo \$merlinclash_acl_content_$acl)
			lianjie=$(eval echo \$merlinclash_acl_lianjie_$acl)
			#protocol=$(eval echo \$merlinclash_acl_protocol_$acl)
			
            echo $type,$content,$lianjie >> /jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml
	    done
	else
	    echo "none"
	fi
}
usefile(){
    if [ -f "/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml" ]; then
        acl_nu=$(get_list merlinclash_acl_type 1 4)
        echo_date "当配置文件变化且有自定义规则时，先清除自定义规则的值" >> $LOG_FILE
        if [ $yamlselchange == "1" ]; then
            if [ -n "$acl_nu" ]; then
                for acl in $acl_nu; do
                    dbus remove merlinclash_acl_type_$acl
                    dbus remove merlinclash_acl_content_$acl
                    dbus remove merlinclash_acl_lianjie_$acl
                    #dbus remove merlinclash_acl_protocol_$acl
                done
            fi
            #当配置文件变化，且存在自定义规则文件时，从rule_custom中的文件字典读取各值重新赋值还原
            rulecusfile="/jffs/softcenter/merlinclash/rule_custom/${yamlname}_custom_rule.yaml"
            lines=$(cat $rulecusfile | wc -l)
            echo_date "存在自定义规则：$lines条" >> $LOGFILE
            if [ $lines -gt 0 ]; then
                i=1
                while [ "$i" -le "$lines" ]
                do
                    echo_date "开始取值赋值处理" >> $LOG_FILE
                    line=$(sed -n ''$i'p' "$rulecusfile")
                    type=$(echo $line | awk -F "," '{print $1}')
                    content=$(echo $line | awk -F "," '{print $2}')
                    lianjie=$(echo $line | awk -F "," '{print $3}')
                    #protocol=$(echo $line | awk -F "," '{print $4}')
                    dbus set merlinclash_acl_type_$i=$type
                    dbus set merlinclash_acl_content_$i=$content
                    dbus set merlinclash_acl_lianjie_$i=$lianjie
                    #dbus set merlinclash_acl_protocol_$i=$protocol
                    let i++
                done    
            fi
        fi
    else
        echo_date "当配置文件变化且无自定义规则文件时，先清除自定义规则的值" >> $LOG_FILE
        acl_nu=$(get_list merlinclash_acl_type 1 4)
        if [ -n "$acl_nu" ]; then
			for acl in $acl_nu; do
                dbus remove merlinclash_acl_type_$acl
                dbus remove merlinclash_acl_content_$acl
                dbus remove merlinclash_acl_lianjie_$acl
                #dbus remove merlinclash_acl_protocol_$acl
            done
        fi
    fi
}
case $2 in
save)
    savefile
    http_response $1
    ;;
    
del)
    savefile
    http_response $1
    ;;

use)
    usefile
    ;;
esac



