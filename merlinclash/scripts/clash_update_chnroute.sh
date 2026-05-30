#!/bin/sh

source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/var/lock/chnroute_update.lock

# 通用下载与校验函数
# 参数: $1:版本(4/6), $2:远程地址, $3:本地目标路径, $4:临时路径, $5:旧路由缓存路径
core_update_chnroute(){
    local VER="$1"
    local URL="$2"
    local DEST="$3"
    local TEMP="$4"
    local IPSET_CACHE="$5"
    local NAME="【ipv${VER}】"

    echo_date "$NAME 开始下载更新..."
    
    # 1. 下载文件 (使用你之前的 download 函数，自带 CDN/原站重试逻辑)
    # 这里的 $UA 变量通常在 clash_base.sh 中定义
    download "$UA" "$URL" "$TEMP"

    if [ "$?" -ne 0 ] || [ ! -s "$TEMP" ]; then
        echo_date "$NAME 下载失败。请检查网络或尝试开启【代理路由自身访问】！"
        rm -rf "$TEMP"
        return 1
    fi

    # 2. 检查合法性 (检查 payload 关键字)
    if [ -z "$(grep "payload" "$TEMP")" ]; then
        echo_date "$NAME 文件内容错误（缺少 payload），请稍后重试。"
        rm -rf "$TEMP"
        return 1
    fi

    # 3. 检查是否有更新 (cmp 比较)
    if [ -f "$DEST" ] && cmp -s "$TEMP" "$DEST"; then
        echo_date "$NAME 已经是最新版本，无需替换。"
        rm -rf "$TEMP"
    else
        echo_date "$NAME 检测到更新，正在替换旧版本..."
        mv -f "$TEMP" "$DEST"
        [ -f "$IPSET_CACHE" ] && rm -rf "$IPSET_CACHE"
        echo_date "$NAME 更新成功！下次重启 Clash 生效。"
    fi
    return 0
}

set_lock(){
    exec 233>"$LOCK_FILE"
    if ! flock -n 233; then
        echo_date "大陆白名单规则更新已经在运行，请稍候再试！" >> $LOG_FILE
        unset_lock
    fi
}

unset_lock(){
    flock -u 233
    rm -rf "$LOCK_FILE"
}

case $2 in
25)
    set_lock
    echo "" > $LOG_FILE
    http_response "$1"
    
    echo_date "开始下载大陆IP白名单..." >> $LOG_FILE

    # 更新 IPv4
    core_update_chnroute "4" \
        "https://testingcf.jsdelivr.net/gh/fernvenue/chn-cidr-list@master/ipv4.yaml" \
        "/jffs/softcenter/merlinclash/yaml_basic/ChinaIP.yaml" \
        "/tmp/ChinaIP.list" \
        "/jffs/softcenter/res/china_ip_route.ipset" >> $LOG_FILE

    # 更新 IPv6
    core_update_chnroute "6" \
        "https://testingcf.jsdelivr.net/gh/fernvenue/chn-cidr-list@master/ipv6.yaml" \
        "/jffs/softcenter/merlinclash/yaml_basic/ChinaIPv6.yaml" \
        "/tmp/ChinaIPv6.list" \
        "/jffs/softcenter/res/china_ip_route6.ipset" >> $LOG_FILE

    echo BBABBBBC >> $LOG_FILE
    unset_lock
    ;;
esac
