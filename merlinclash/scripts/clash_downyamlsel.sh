#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

echo_date "开始下载" >> $LOG_FILE
echo_date "定位文件" >> $LOG_FILE
yamlpath=/jffs/softcenter/merlinclash/yaml_use
tmp_path=/tmp/upload
inipath=/jffs/softcenter/merlinclash/subconverter/customconfig
listpath=/jffs/softcenter/merlinclash/subconverter/rules/custom
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlsel=$(get merlinclash_delyamlsel)
downyamlfile(){
    filename=$(echo $yamlsel.yaml)
    echo_date "$filename" >> $LOG_FILE

    cp -rf $yamlpath/$filename $tmp_path/$filename
    if [ -f $tmp_path/$filename ]; then
    echo_date "文件已复制" >> $LOG_FILE
    http_response "$filename"
    else
        echo_date "文件复制失败" >> $LOG_FILE
    fi
}
downinifile(){
    delini=$(get merlinclash_delinisel)
    filename=$(echo $delini.ini)
    echo_date "$filename" >> $LOG_FILE

    cp -rf $inipath/$filename $tmp_path/$filename
    if [ -f $tmp_path/$filename ]; then
    echo_date "文件已复制" >> $LOG_FILE
    http_response "$filename"
    else
        echo_date "文件复制失败" >> $LOG_FILE
    fi
}
downlistfile(){
    dellist=$(get merlinclash_dellistsel)
    filename=$(echo $dellist.list)
    echo_date "$filename" >> $LOG_FILE

    cp -rf $listpath/$filename $tmp_path/$filename
    if [ -f $tmp_path/$filename ]; then
    echo_date "文件已复制" >> $LOG_FILE
    http_response "$filename"
    else
        echo_date "文件复制失败" >> $LOG_FILE
    fi
}
case $2 in
downyaml)
    downyamlfile
	;;
downini)
    downinifile
	;;
downlist)
    downlistfile
	;;
esac
