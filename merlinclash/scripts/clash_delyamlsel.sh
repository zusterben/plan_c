#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/tmp/yaml_online_del.lock
dictionary=/jffs/softcenter/merlinclash/yaml_bak/subscription.txt
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
start_online_del(){
    rm -rf $LOG_FILE
    echo_date "定位yaml文件" >> $LOG_FILE

    #delpath1=/jffs/softcenter/merlinclash
    delpath1=/jffs/softcenter/merlinclash/yaml_use
    delpath2=/jffs/softcenter/merlinclash/yaml_bak
    rulepath=/jffs/softcenter/merlinclash/rule_bak
    markpath=/jffs/softcenter/merlinclash/mark
    marktmp=/tmp/clash/mark
    yamlname=$(get merlinclash_delyamlsel)

    rm -rf $delpath1/$yamlname.yaml
    rm -rf $delpath2/$yamlname.yaml
    rm -rf $rulepath/${yamlname}_rules.yaml
    rm -rf $rulepath/${yamlname}_custom_rule.yaml
    rm -rf $markpath/${yamlname}.txt
    rm -rf $marktmp/${yamlname}_old.txt
    rm -rf $marktmp/${yamlname}_new.txt
    rm -rf $marktmp/${yamlname}_ok_*
    
    echo_date "删除yaml文件" >> $LOG_FILE
    #20200804 删除字典对应内容
    name_tmp=$(cat $dictionary | grep -w -n "$yamlname.yaml" | awk -F ":" '{print $1}')
    if [ -n "$name_tmp" ]; then
		  sed -i "$name_tmp d" $dictionary
    fi
    echo_date "重建yaml文件列表" >> $LOG_FILE
    #find $fp  -name "*.yaml" |sed 's#.*/##' >> $fp/yamls.txt
    rm -rf $delpath2/yamls.txt
    rm /tmp/upload/yamls.txt
    find $delpath2  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $delpath2/yamls.txt
    #创建软链接
    ln -sf $delpath2/yamls.txt /tmp/upload/yamls.txt
    #
    dbus remove merlinclash_${yamlname}
    
    echo_date "配置文件删除完毕" >>"$LOG_FILE"
}
start_ini_del(){
    rm -rf $LOG_FILE
    echo_date "定位ini文件" >> $LOG_FILE

    inipath=/jffs/softcenter/merlinclash/subconverter/customconfig
    delpath2=/jffs/softcenter/merlinclash/yaml_bak
    ininame=$(get merlinclash_delinisel)

    rm -rf $inipath/$ininame.ini
    
    echo_date "删除文件:$inipath/$ininame.ini" >> $LOG_FILE
    echo_date "重建ini文件列表" >> $LOG_FILE
    #find $fp  -name "*.yaml" |sed 's#.*/##' >> $fp/yamls.txt
    rm -rf $delpath2/yamlscus.txt
    rm /tmp/upload/yamlscus.txt
    find $inipath  -name "*.ini" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $delpath2/yamlscus.txt
    #创建软链接
    ln -sf $delpath2/yamlscus.txt /tmp/upload/yamlscus.txt
    #
    echo_date "ini配置文件删除完毕" >>"$LOG_FILE"
}
start_list_del(){
    rm -rf $LOG_FILE
    echo_date "定位List文件" >> $LOG_FILE

    listpath=/jffs/softcenter/merlinclash/subconverter/rules/custom
    delpath2=/jffs/softcenter/merlinclash/yaml_bak
    listname=$(get merlinclash_dellistsel)

    rm -rf $listpath/$listname.list
    echo_date "删除文件:$listpath/$listname.list" >> $LOG_FILE
    echo_date "重建List文件列表" >> $LOG_FILE
    #find $fp  -name "*.yaml" |sed 's#.*/##' >> $fp/yamls.txt
    rm -rf $delpath2/yamlscuslist.txt
    rm /tmp/upload/yamlscuslist.txt
    find $listpath  -name "*.list" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $delpath2/yamlscuslist.txt
    #创建软链接
    ln -sf $delpath2/yamlscus.txt /tmp/upload/yamlscus.txt
    #
    echo_date "List文件删除完毕" >>"$LOG_FILE"
}
case $2 in
0)
    set_lock
	echo "" > $LOG_FILE
	http_response "$1"
	echo_date "删除配置文件" >> $LOG_FILE
	start_online_del >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
	unset_lock
	;;
30)
    echo "" > $LOG_FILE
	http_response "$1"
	echo_date "删除ini配置文件" >> $LOG_FILE
	start_ini_del >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
    ;;
31)
    echo "" > $LOG_FILE
	http_response "$1"
	echo_date "删除list文件" >> $LOG_FILE
	start_list_del >> $LOG_FILE
	echo BBABBBBC >> $LOG_FILE
    ;;
esac
