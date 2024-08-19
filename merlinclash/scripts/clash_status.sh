#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

pid_clash=$(pidof clash)
pid_d2s=$(pidof mc_dns2socks)
#pid_watchdog=$(ps | grep clash_watchdog.sh | grep -v grep | awk '{print $1}')
#pid_watchdog=$(cru l | grep "clash_watchdog")
pid_watchdog=$(ps | grep clash_dog.sh | grep -v grep)
date=$(echo_date)
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
#yamlpath=/jffs/softcenter/merlinclash/yaml_use/$yamlname.yaml
yamlpath=/tmp/upload/view.txt
starttime=$(get merlinclash_clashstarttime)
lan_ipaddr=$(nvram get lan_ipaddr)
board_port="9990"
if [ ! -f $yamlpath ]; then
    host=''
    port=''
    secret=''
else
    #host=$(yq r $yamlpath external-controller | awk -F":" '{print $1}')
    host_port=$(cat $yamlpath | awk -F": " '/external-controller/{print $2}')
    port=$(cat $yamlpath | awk -F: '/external-controller/{print $3}')
    secret=$(cat $yamlpath | awk '/secret:/{print $2}' | sed 's/"//g')
fi


if [ -n "$pid_clash" ]; then
    text1="<span style='color: #6C0'>$date Clash 进程运行正常！(PID: $pid_clash)</span>"
    #text3="<span style='color: gold'>面板host：$host</span>"
    text4="<span style='color: gold'>面板端口：$port</span>"
    text3="<span style='color: gold'>管理面板：$host_port</span>"
    text15="<span style='color: gold'>面板密码：$secret</span>"
    text18="<span style='color: #6C0'>【Clash本次启动时间】：$starttime</span>"
    
else
    text1="<span style='color: red'>$date Clash 进程未在运行！</span>"
    text18="<span style='color: red'>$date Clash 进程未在运行！</span>"
    
fi

if [ -n "$pid_watchdog" ]; then
    #text2="<span style='color: #6C0'>$date Clash 看门狗运行正常！</span>"
    text2="<span style='color: #6C0'>$date Clash 进程实时守护中！</span>"
else
    # text2="<span style='color: gold'>$date Clash 看门狗未在运行！</span>"
    text2="<span style='color: gold'>$date Clash 进程守护未在运行！</span>"
fi
if [ -n "$pid_d2s" ]; then
    text19="<span style='color: #6C0'>$date Dns2Socks 进程运行正常！(PID: $pid_d2s)</span>"
else
    text19="<span style='color: gold'>$date Dns2Socks 进程未在运行！</span>"
fi
yamlsel_tmp2=$yamlname

#[ ! -L "/tmp/upload/yacd" ] && ln -sf /jffs/softcenter/merlinclash/dashboard/yacd /tmp/upload/
#[ ! -L "/tmp/upload/razord" ] && ln -sf /jffs/softcenter/merlinclash/dashboard/razord /tmp/upload/

#网易云音乐解锁状态
unblockmusic_pid=`ps|grep -w UnblockNeteaseMusic | grep -cv grep`
#unblockmusic_LOCAL_VER=$(/jffs/softcenter/bin/UnblockNeteaseMusic -v 2>/dev/null |awk '/Version/{print $2}')
unblockmusic_LOCAL_VER=$(get merlinclash_UnblockNeteaseMusic_version)
if [ -n "$unblockmusic_LOCAL_VER" ]; then
    text8="<span style='color: gold'>插件版本： $unblockmusic_LOCAL_VER</span>"
else
    text8="<span style='color: red'>获取插件版本失败，请重新上传二进制！</span>"
fi
mubest=$(get merlinclash_unblockmusic_bestquality)
if [ "$unblockmusic_pid" -gt 0 ];then
    if [ "$mubest" == "1" ]; then
	    text9="<span style='color: gold'>运行中 | 已开启高音质</span>"
    else
        text9="<span style='color: gold'>运行中 | 未开启高音质</span>"
    fi
else
	text9="<span style='color: gold'>未启动</span>"
fi

#内置规则文件版本
pgver=$(get merlinclash_proxygroup_version)
if [ "$pgver" != "" ]; then
    text10="<span style='color: gold'>当前版本：v$pgver</span>"
else    
    text10="<span style='color: gold'>当前版本：v0</span>"
fi
#内置游戏规则文件版本
ggver=$(get merlinclash_proxygame_version)
if [ "$ggver" != "" ]; then
    text11="<span style='color: gold'>当前版本：g$ggver</span>"
else    
    text11="<span style='color: gold'>当前版本：g0</span>"
fi
#内置SC规则文件版本
scver=$(get merlinclash_scrule_version)
if [ "$scver" != "" ]; then
    text13="<span style='color: gold'>当前版本：s$scver</span>"
else    
    text13="<span style='color: gold'>当前版本：s0</span>"
fi
#补丁包版本
patchver=$(get merlinclash_patch_version)
if [ "$patchver" != "" ] || [ "$patchver" != "0" ]; then
    text12="<span style='display:table-cell;float: middle; color: gold'>【已装补丁版本】：$patchver</span>"
    text16="<span style='display:table-cell;float: middle; color: gold'>P:$patchver</span>"
else    
    text12="<span style='display:none;'>【已装补丁版本】：</span>"
    text16="<span style='display:none;'></span>"
fi

if [ "$yamlname" != "" ]; then
    text14="<span style='display:table-cell;float: middle; color: gold'>当前配置为：$yamlname</span>"
fi

cirtag=$(ipset list china_ip_route | wc -l)
if [ -n "$cirtag" ]; then
    dbus set merlinclash_cirtag=$cirtag
else
    dbus set merlinclash_cirtag=0
fi

# # 获取本地 IP 地址并去掉换行符
# localip=$(curl -s "https://ip.clang.cn" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
# # 构建查询 URL
# queryhost="https://webapi-pc.meitu.com/common/ip_location?ip=${localip}"
# # 查询地理位置，获取HTTP状态码
# text20=$(curl -s "$queryhost" |jq -r '.data."'$localip'" | "\(.nation)\(.province)\(.city)\(.isp)"')

#获取本地HTTP代理端口
proxyPort=$(dbus get merlinclash_cus_port| grep -Eo '[0-9]{1,5}')

# 创建临时文件，用于存储返回值
tempfile1="/tmp/mc_ip_tempfile1_$$.tmp"
tempfile2="/tmp/mc_ip_tempfile2_$$.tmp"
tempfile3="/tmp/mc_ip_tempfile3_$$.tmp"
tempfile4="/tmp/mc_ip_tempfile4_$$.tmp"

getIPinfo(){
    local url=$1;
    if [ -z "$url" ];then
        echo "出现错误了，找管理解决";
        return 1;
    fi

    # # 获取本地 IP 地址并去掉换行符
    # local localip=$(wget --no-hsts -q -O - --timeout=5 --tries=3 --header="User-Agent: curl/8.1.2" -e use_proxy=yes -e http_proxy=127.0.0.1:$proxyPort $url | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
    # if [ -z "$localip" ]; then
    #     echo "无法获取本地 IP 地址";
    #     return 1;
    # fi
    # 获取信息
    if [ -z "$2" ];then
        # 获取本地 IP 地址并去掉换行符 国内不需要代理
        local localip=$(wget --no-hsts -q -O - --timeout=3 --tries=2 --header="User-Agent: curl/8.1.2" "$url" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
        # 构建查询 URL
        local queryhost="https://api-v3.speedtest.cn/ip?ip=${localip}"
        local result=$(curl --max-time 5 -s "$queryhost")
        local return=$(echo "$result" | jq -r '.data |  "\(.country)\(.province)\(.city)\(.isp)"')
    else
        # 获取本地 IP 地址并去掉换行符
        local localip=$(wget --no-hsts -q -O - --timeout=3 --tries=2 --header="User-Agent: curl/8.1.2" -e use_proxy=yes -e http_proxy=127.0.0.1:$proxyPort "$url" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
        # 构建查询 URL
        local queryhost="http://ip-api.com/json/${localip}?lang=zh-CN"
        local result=$(curl --max-time 5 -s "$queryhost")
        local return=$(echo "$result" | jq -r '.country,.regionName,.city,.isp')
    fi
    echo "$localip $return"
}
# getIPinfo2(){
#     # 获取本地 IP 及IP信息
#     local queryResult;
#     if [ "$1" -eq "2" ];then
#         queryResult=$(wget --no-hsts -q -O - --timeout=3 --tries=3 --header="User-Agent: curl/8.1.2" -e use_proxy=yes -e http_proxy="127.0.0.1:$proxyPort" "http://ip-api.com/json?lang=zh-CN")
#     else
#         queryResult=$(wget --no-hsts -q -O - --timeout=3 --tries=3 --header="User-Agent: curl/8.1.2" "http://ip-api.com/json?lang=zh-CN")
#     fi
#     local finalResult=$(echo "$queryResult" |jq -r  '.country,.regionName,.isp')
#     # 查询地理位置，获取HTTP状态码
#     echo $finalResult
# }
#检查连通性，5秒超时
checkWebSite(){
    local url=$1;
    if [ -z "$url" ];then
        echo "出现错误了，找管理解决";
        return ;
    fi
    # 检查连通性
    if [ -z "$2" ];then #国内，不走代理，提速。
        if wget --no-hsts -q -O - --timeout=3 --tries=2   --spider "$url"; then
            echo "连通正常"
        else
            echo "连通失败"
        fi
    else
        if wget --no-hsts -q -O - --timeout=3 --tries=2  -e use_proxy=yes -e http_proxy="127.0.0.1:$proxyPort" --spider "$url"; then
            echo "连通正常"
        else
            echo "连通失败"
        fi
    fi
    
}

# 后台执行函数并将结果写入临时文件
(checkWebSite "www.google.com.hk" out > "$tempfile4") &
pid4=$!
(checkWebSite "www.baidu.com" > "$tempfile3") &
pid3=$!
(getIPinfo "ip.clang.cn" > "$tempfile1") &
pid1=$!
(getIPinfo "ipv4.ip.sb" out > "$tempfile2") &
pid2=$!
# 等待所有后台任务完成
wait $pid1
wait $pid2
wait $pid3
wait $pid4

# 读取临时文件中的返回值并去掉换行符
text20=$(tr -d '\n' < "$tempfile1")
text21=$(tr -d '\n' < "$tempfile2")
text22=$(tr -d '\n' < "$tempfile3")
text23=$(tr -d '\n' < "$tempfile4")

# 删除临时文件
rm "$tempfile1"
rm "$tempfile2"
rm "$tempfile3"
rm "$tempfile4"

# text20==$(echo $(getIPinfo "ip.clang.cn"))
# text21=$(echo $(getIPinfo "ipv4.ip.sb"))
# # text20=$(echo $(getIPinfo2 1))
# # text21=$(echo $(getIPinfo2 2))
# text22=$(echo $(checkWebSite "www.baidu.com"))
# text23=$(echo $(checkWebSite "github.com/404?tab=achievements&achievement=404"))
# text24=$(echo $(checkWebSite "www.google.com"))


http_response "$text1@$text2@$host@$port@$secret@$text3@$text4@$yamlsel_tmp2@$text8@$text9@$text10@$text11@$text12@$text13@$text14@$text15@$secret@$text16@$text18@$text19@$text20@$text21@$text22@$text23@$text24"
