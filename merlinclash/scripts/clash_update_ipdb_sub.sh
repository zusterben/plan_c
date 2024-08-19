#!/bin/sh

export KSROOT=/koolshare
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
uploadpath=/tmp/upload
tmpStoragePath=
fileIsValid="0"

curl=$(which curl)
wget=$(which wget)

ipdb_url="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=oeEqpP5QI21N&suffix=tar.gz"
ipip_url="https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/Country.mmdb"
hip_url="https://testingcf.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/Country.mmdb"
ls_url="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb"
ls_cdn="https://testingcf.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country.mmdb"
ls300_url="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country-only-cn-private.mmdb"
ls300_cdn="https://testingcf.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country-only-cn-private.mmdb"
mlcn_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite-lite.dat"
mlcn_cdn="https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite-lite.dat"
mlall_url="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"
mlall_cdn="https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
mlfull_url="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat"
mlfull_cdn="https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"

get(){
	echo $(dbus get $1)
}

mcgt=$(get merlinclash_geoip_type)
mcud=$(get merlinclash_updata_date)

check_size(){
    SPACE_FILE=$(du -s "$1" | awk '{print $1}')
    if [ ! -f "$1" ] || [ "$SPACE_FILE" -eq "0" ]; then
        echo "0"
    else
        echo "1"
    fi
}

downloadFile(){
    local url=$1
    local filePath=$2
    if [ ! "$url" ] || [  ! "$filePath" ];then
        echo_date "下载地址或存储文件名不存在，停止下载！！" >> $LOG_FILE
        exit 1
    fi
    
    if [ "x$wget" != "x" ] && [ -x $wget ]; then
        $wget --no-check-certificate --tries=3 $url -O $filePath
    elif [ "x$curl" != "x" ] && [ test -x $curl ]; then
        $curl -k --compressed $url -o $filePath
    else
        echo_date "没有找到 wget 或 curl，无法更新 IP 数据库！" >> $LOG_FILE
        exit 1
    fi
    fileIsValid=$(check_size $2)
}

update_ipdb(){
    #下载maxmind
    if [ "$mcgt" == "maxmind" ]; then
        echo_date "下载数据库来源为：$mcgt" >> $LOG_FILE
        tmpStoragePath="$uploadpath/ipdb.tar.gz"
        echo_date "开始下载最新 IP 数据库..." >> $LOG_FILE
        downloadFile $ipdb_url $tmpStoragePath
    
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始解压" >> $LOG_FILE
            mkdir -p $uploadpath/ipdb
            tar zxvf $uploadpath/ipdb.tar.gz -C $uploadpath/ipdb
            
            chmod 644 $uploadpath/ipdb/GeoLite2-Country_*/*
            version=$(ls $uploadpath/ipdb | grep 'GeoLite2-Country' | sed "s|GeoLite2-Country_||g")
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $uploadpath/ipdb/GeoLite2-Country_*/GeoLite2-Country.mmdb | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $uploadpath/ipdb/GeoLite2-Country_*/GeoLite2-Country.mmdb /jffs/softcenter/merlinclash/Country.mmdb
                
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $uploadpath/ipdb.tar.gz
                rm -rf $uploadpath/ipdb
                
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "下载 IP 数据库失败！退出更新" >> $LOG_FILE
            exit 1
        fi
    fi
    #下载ipip
    if [ "$mcgt" == "ipip" ] ; then
        echo_date "下载数据库来源为：$mcgt" >> $LOG_FILE
        tmpStoragePath="$uploadpath/Country.mmdb"
        echo_date "开始下载最新 IP 数据库..." >> $LOG_FILE
        downloadFile $ipip_url $tmpStoragePath
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            mcud=$(get merlinclash_updata_date)
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/Country.mmdb
                
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "下载 IP 数据库失败！退出更新" >> $LOG_FILE
            echo BBABBBBC >> $LOG_FILE
            exit 1
        fi
    fi
    #下载Hackl0us
    if [ "$mcgt" == "Hackl0us" ] ; then
        echo_date "下载数据库来源为：$mcgt" >> $LOG_FILE
        tmpStoragePath="$uploadpath/Country.mmdb"
        echo_date "开始下载最新 IP 数据库..." >> $LOG_FILE
        downloadFile $hip_url $tmpStoragePath
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/Country.mmdb
                
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "下载 IP 数据库失败！退出更新" >> $LOG_FILE
            exit 1
        fi
    fi
    #下载Loyalsoldier
    if [ "$mcgt" == "Loyalsoldier" ] ; then
        echo_date "下载数据库来源为：$mcgt" 
        tmpStoragePath="$uploadpath/Country.mmdb"
        echo_date "开始下载最新 IP 数据库..." 
        downloadFile $ls_url $tmpStoragePath
        
        if [ "$fileIsValid" == "1" ]; then  
            echo_date "数据库下载成功，但是否完整还需通过日志人为判断"
        else
            echo_date "数据库下载失败，从CDN地址下载"
            downloadFile $ls_cdn $tmpStoragePath
        fi
        
        if [ "$fileIsValid" == "1" ]; then 
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/Country.mmdb
                
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                
                
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "数据库下载失败，退出更新"
            exit 1       
        fi
    fi
    #下载Loyalsoldier300
    if [ "$mcgt" == "Loyalsoldier300" ] ; then
        echo_date "下载数据库来源为：Loyalsoldier/Country-only-cn-private(含IPV6)"
        tmpStoragePath="$uploadpath/Country.mmdb"
        echo_date "开始下载最新 IP 数据库..." 
        downloadFile $ls300_url $tmpStoragePath
        
        if [ "$fileIsValid" == "1" ]; then  
            echo_date "数据库下载成功，但是否完整还需通过日志人为判断"
        else
            echo_date "数据库下载失败，从CDN地址下载"
            downloadFile $ls300_cdn $tmpStoragePath
        fi
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/Country.mmdb
                
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "数据库下载失败，退出更新"
            exit 1       
        fi
    fi
    #下载Meta/geositeCN
    if [ "$mcgt" == "Mcore_LCN" ] ; then
        echo_date "下载数据库来源为：MetaCubeX/meta-rules-dat" 
        tmpStoragePath="$uploadpath/geosite.dat"
        echo_date "开始下载最新 IP 数据库..." 
        downloadFile $mlcn_url $tmpStoragePath
        if [ "$fileIsValid" == "1" ]; then  
            echo_date "数据库下载成功，但是否完整还需通过日志人为判断"
        else
            echo_date "数据库下载失败，从CDN地址下载"
            sleep 1
            downloadFile $mlcn_cdn $tmpStoragePath
        fi
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/GeoSite.dat
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "数据库下载失败，退出更新"
            exit 1 
        fi
        
    fi
    #下载Meta/geosite
    if [ "$mcgt" == "Mcore_ALL" ] ; then
        echo_date "下载数据库来源为：MetaCubeX/meta-rules-dat" 
        tmpStoragePath="$uploadpath/geosite.dat"
        echo_date "开始下载最新 IP 数据库..." 
        downloadFile $mlall_url $tmpStoragePath
        if [ "$fileIsValid" == "1" ]; then  
            echo_date "数据库下载成功，但是否完整还需通过日志人为判断"
        else
            echo_date "数据库下载失败，从CDN地址下载"
            sleep 1
            downloadFile $mlall_cdn $tmpStoragePath
        fi
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/GeoSite.dat
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "数据库下载失败，退出更新"
            exit 1 
        fi
        
    fi
    #下载Loyalsoldier/geosite
    if [ "$mcgt" = "Mcore_FULL" ];then
        echo_date "下载数据库来源为：Loyalsoldier/geosite"
        tmpStoragePath="$uploadpath/geosite.dat"
        echo_date "开始下载最新 IP 数据库..." 
        downloadFile $mlfull_url $tmpStoragePath
        if [ "$fileIsValid" == "1" ]; then  
            echo_date "数据库下载成功，但是否完整还需通过日志人为判断"
        else
            echo_date "数据库下载失败，从CDN地址下载"
            sleep 1
            downloadFile $mlfull_cdn $tmpStoragePath
        fi
        
        if [ "$fileIsValid" == "1" ]; then
            echo_date "下载完成，开始替换" >> $LOG_FILE
            version=$mcud
            echo_date 检测jffs分区剩余空间... >> $LOG_FILE
            SPACE_AVAL=$(df|grep jffs|head -n 1  | awk '{print $4}')
            SPACE_NEED=$(du -s $tmpStoragePath | awk '{print $1}')
            if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间满足，继续安装！>> $LOG_FILE
                echo_date "更新版本" >> $LOG_FILE
                cp -rf $tmpStoragePath /jffs/softcenter/merlinclash/GeoSite.dat
                echo_date "更新 IP 数据库至 $version 版本" >> $LOG_FILE
                dbus set merlinclash_ipdb_version=$version
                echo_date "清理临时文件..." >> $LOG_FILE
                rm -rf $tmpStoragePath
                echo_date "IP 数据库更新完成！" >> $LOG_FILE
                echo_date "注意！新版 IP 数据库将在下次启动 Clash 时生效！" >> $LOG_FILE
                sleep 1
            else
                echo_date 当前jffs分区剩余"$SPACE_AVAL" KB, 数据库需要"$SPACE_NEED" KB，空间不足！>> $LOG_FILE
                echo_date 退出安装！>> $LOG_FILE
                exit 1
            fi
        else
            echo_date "数据库下载失败，退出更新"
            exit 1 
        fi
        
    fi
}

case $1 in
down)
	update_ipdb >> $LOG_FILE 2>&1
	echo BBABBBBC >> $LOG_FILE
	;;
esac
