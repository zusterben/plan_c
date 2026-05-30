#!/bin/sh

source /jffs/softcenter/scripts/base.sh
source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt


downyamlfile(){
    echo_date ======================== 删除YAM配置 ======================== >> $LOG_FILE
    echo_date "📌定位文件" >> $LOG_FILE

	yamlpath=/jffs/softcenter/merlinclash/yaml_use
    tmp_path=/tmp/upload
    rm -rf $tmp_path/*.yaml

    yamlsel=$(get merlinclash_set_yamlsel_edit)
    filename=$(echo $yamlsel.yaml)
    echo_date "$filename" >> $LOG_FILE

    cp -rf $yamlpath/$filename $tmp_path/$filename
    if [ -f $tmp_path/$filename ]; then
    echo_date "🟠文件已复制" >> $LOG_FILE
    http_response "$filename"
    else
        echo_date "🔴文件复制失败" >> $LOG_FILE
    fi
    echo_date ======================== 删除YAM配置 ======================== >> $LOG_FILE
}

case $2 in
downyaml)
    downyamlfile
	;;
esac

