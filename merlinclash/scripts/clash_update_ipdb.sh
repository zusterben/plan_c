#!/bin/sh

source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
LOCK_FILE=/tmp/ipdb_update.lock

# 通用下载与安装函数
# 参数: $1:描述名, $2:CDN地址, $3:原地址, $4:目标路径, $5:dbus恢复类型名
core_download(){
    local NAME="$1"
    local CDN_URL="$2"
    local ORIG_URL="$3"
    local DEST_PATH="$4"
    local DBUS_KEY="$5"
    local TEMP_FILE="/tmp/upload/temp_$(basename "$DEST_PATH")"

    echo_date "---------------------------------------------------------"
    echo_date "开始更新 $NAME ..."

    # 1. 尝试从 CDN 下载
    echo_date "尝试从 CDN 下载..."
    download "$UA" "$CDN_URL" "$TEMP_FILE"
    
    # 如果 CDN 失败 ($? != 0)，尝试原地址
    if [ "$?" -ne 0 ]; then
        echo_date "CDN 下载失败，尝试从原始地址下载..."
        rm -rf "$TEMP_FILE"
        download "$UA" "$ORIG_URL" "$TEMP_FILE"
        if [ "$?" -ne 0 ]; then
            echo_date "错误：$NAME 所有下载地址均失效！"
            dbus set "$DBUS_KEY"="lite"
            rm -rf "$TEMP_FILE"
            return 1
        fi
    fi

    # 2. 空间检查
    local SPACE_AVAL=$(df | grep jffs | awk '{print $4}' | head -n 1)
    local SPACE_NEED=$(du -s "$TEMP_FILE" | awk '{print $1}')

    if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ]; then
        echo_date "JFFS 空间检查通过 ($SPACE_AVAL KB > $SPACE_NEED KB)"
        echo_date "正在替换数据库文件..."
        mv -f "$TEMP_FILE" "$DEST_PATH"
        echo_date "$NAME 更新成功！"
        return 0
    else
        echo_date "错误：JFFS 空间不足！剩余 $SPACE_AVAL KB，需要 $SPACE_NEED KB"
        dbus set "$DBUS_KEY"="lite"
        rm -rf "$TEMP_FILE"
        return 1
    fi
}

update_geoip(){
    case "${merlinclash_set_geoip_type}" in
        lite)
            core_download "GeoIP-Lite" "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip-lite.dat" "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat" "/jffs/softcenter/merlinclash/GeoIP.dat" "merlinclash_set_geoip_type"
            ;;
        full)
            core_download "GeoIP-Full" "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat" "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" "/jffs/softcenter/merlinclash/GeoIP.dat" "merlinclash_set_geoip_type"
            ;;
        head)
            echo_date "GeoIP 已设为跟随基础配置，跳过手动更新。"
            ;;
        *)
            # 默认更新 Lite
            core_download "GeoIP-Lite(默认)" "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip-lite.dat" "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat" "/jffs/softcenter/merlinclash/GeoIP.dat" "merlinclash_set_geoip_type"
            ;;
    esac
}

update_geosite(){
    case "${merlinclash_set_geosite_type}" in
        lite)
            core_download "GeoSite-Lite" "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite-lite.dat" "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite-lite.dat" "/jffs/softcenter/merlinclash/GeoSite.dat" "merlinclash_set_geosite_type"
            ;;
        full)
            core_download "GeoSite-Full" "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat" "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" "/jffs/softcenter/merlinclash/GeoSite.dat" "merlinclash_set_geosite_type"
            ;;
        head)
            echo_date "GeoSite 已设为跟随基础配置，内核启动时将自动下载，退出。"
            echo BBABBBBC
            exit 0
            ;;
        *)
            # 默认使用原脚本中的 default 地址
            core_download "GeoSite-Default" "https://testingcf.jsdelivr.net/gh/flyhigherpi/merlinclash_clash_related@refs/heads/master/geosite/geosite.dat" "https://github.com/flyhigherpi/merlinclash_clash_related/raw/refs/heads/master/geosite/geosite.dat" "/jffs/softcenter/merlinclash/GeoSite.dat" "merlinclash_set_geosite_type"
            ;;
    esac
}

# 锁管理
set_lock(){
    exec 233>"$LOCK_FILE"
    if ! flock -n 233; then
        echo_date "错误：数据库升级已经在运行，请稍候再试！" >> $LOG_FILE
        unset_lock
    fi
}

unset_lock(){
    flock -u 233
    rm -rf "$LOCK_FILE"
}

# 脚本主逻辑
case $2 in
5)
    set_lock
    echo "" > $LOG_FILE
    http_response "$1"
    
    echo_date "======================== 开始更新 GEO 数据库 =======================" >> $LOG_FILE
    
    # 执行 GeoIP 更新
    update_geoip >> $LOG_FILE
    
    # 执行 GeoSite 更新
    update_geosite >> $LOG_FILE
    
    echo_date "注意：新版数据库将在下一次启动 Clash 时生效！" >> $LOG_FILE
    echo_date "====================================================================" >> $LOG_FILE
    echo BBABBBBC >> $LOG_FILE
    unset_lock
    ;;
esac
