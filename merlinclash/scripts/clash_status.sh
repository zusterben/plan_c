#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

#==============================
# 工具函数
#==============================
yamlpath="/tmp/upload/view.txt"

porttmp=$(yq eval ".mixed-port" "$yamlpath" 2>/dev/null)
if [ -z "$porttmp" ] || [ "$porttmp" == "null" ]; then
    porttmp=$(yq eval ".port" "$yamlpath" 2>/dev/null)
fi


get_dbus() {
    dbus get "$1"
}

# 检查进程是否运行
is_running() {
    pidof "$1" >/dev/null 2>&1
}

# 获取 Clash 进程状态
get_clash_status() {
    local pid_clash=$(pidof clash)
    local start_time=$(get_dbus merlinclash_binary_startime)

    if [ -n "$pid_clash" ]; then
        clash_status="<span style='color: #6C0'>$(echo_date) Mihomo 进程运行正常！(PID: $pid_clash)</span>"
        clash_start="<span style='color: #6C0'>【本次启动时间】：$start_time</span>"
    else
        clash_status="<span style='color: red'>$(echo_date) Mihomo 进程未在运行！</span>"
        clash_start="<span style='color: red'>$(echo_date) Mihomo 进程未在运行！</span>"
    fi
}

# 获取 Watchdog 状态
get_watchdog_status() {
    local pid_watchdog=$(ps | grep clash_dog.sh | grep -v grep)
    if [ -n "$pid_watchdog" ]; then
        watchdog_status="<span style='color: #6C0'>$(echo_date) Mihomo 进程实时守护中！</span>"
    else
        watchdog_status="<span style='color: gold'>$(echo_date) Mihomo 进程守护未在运行！</span>"
    fi
}

# 获取 YAML 面板信息
get_yaml_info() {
    local yaml_name=$(get_dbus merlinclash_set_yamlsel_start)

    if [ -f "$yamlpath" ]; then
        panel_host_port=$(awk -F": " '/external-controller/{print $2}' "$yamlpath")
        panel_port=$(awk -F: '/external-controller/{print $3}' "$yamlpath")
        panel_secret=$(awk '/secret:/{print $2}' "$yamlpath" | sed 's/"//g')
    else
        panel_host_port=""
        panel_port=""
        panel_secret=""
    fi

    yaml_info="<span style='display:table-cell;float: middle; color: gold'>当前配置为：$yaml_name</span>"
    panel_port_info="<span style='color: gold'>面板端口：$panel_port</span>"
    panel_secret_info="<span style='color: gold'>面板密码：$panel_secret</span>"
}

# 获取规则版本信息
get_rule_version() {
    rule_version="<span style='color: gold'>当前版本：s0</span>"
    local cirtag=$(ipset list china_ip_route | wc -l)
	if [ -n "$cirtag" ]; then
    	dbus set merlinclash_db_chnroute_num=$cirtag
	else
    	dbus set merlinclash_db_chnroute_num=0
	fi
}

# 检查域名是否被污染
check_domain_blocked() {
    local domain=$(echo "$1" | sed -E 's/^https?:\/\/([^\/:]+).*$/\1/')
    local ip=$(ping -4 -c 1 -W 1 "$domain" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    if [ "$ip" = "127.0.0.1" ] || [ "$ip" = "0.0.0.0" ] || [ -z "$ip" ]; then
        return 1
    else
        return 0
    fi
}

# HTTP 请求
request_url() {
    local url=$1
    local use_proxy=$2
    local proxy_port=$3
    local ua="User-Agent: curl/merlin clash 5.20"
    local result

    check_domain_blocked "$url"
    if [ $? -eq 0 ]; then
        if [ "$use_proxy" != "true" ]; then
            result=$(curl --max-time 2 -s -H "$ua" "$url" 2>/dev/null)
            [ -z "$result" ] && result=$(wget --no-hsts -q -O - --timeout=2 --tries=1 --header="$ua" "$url" 2>/dev/null)
        else
            result=$(curl --max-time 2 -s -H "$ua" --proxy 127.0.0.1:"$proxy_port" "$url" 2>/dev/null)
            [ -z "$result" ] && result=$(wget --no-hsts -q -O - --timeout=2 --tries=1 --header="$ua" -e use_proxy=yes -e http_proxy=127.0.0.1:"$proxy_port" "$url" 2>/dev/null)
        fi
        echo "$result"
    fi
}

# 检查连通性
check_connectivity() {
    local url=$1
    local use_proxy=$2
    local proxy_port=$porttmp

    check_domain_blocked "$url"
    if [ $? -eq 0 ]; then
        if [ $use_proxy != "true" ]; then
            wget --no-hsts -q --timeout=2 --tries=1 --spider "$url" && echo "连通正常" || echo "连通失败"
        else
            wget --no-hsts -q --timeout=2 --tries=1 -e use_proxy=yes -e http_proxy="127.0.0.1:$proxy_port" --spider "$url" && echo "连通正常" || echo "连通失败"
        fi
    fi
}

# 获取 IP 信息
get_ip_info() {
    local url=$1
    local use_proxy=$2
    local proxy_port=$porttmp
    local local_ip
    local result
    local info

    if [ $use_proxy != "true" ]; then
        local_ip=$(request_url "$url" $use_proxy | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
        result=$(request_url "https://api-v3.speedtest.cn/ip?ip=${local_ip}" $use_proxy)
        info=$(echo "$result" | jq -r '.data |  "\(.country)\(.province)\(.city)\(.isp)"' 2>/dev/null)
    else
        local_ip=$(request_url "$url" $use_proxy "$proxy_port" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
        result=$(request_url "http://ip-api.com/json/${local_ip}?lang=zh-CN" $use_proxy "$proxy_port")
        info=$(echo "$result" | jq -r '.country,.regionName,.city,.isp' 2>/dev/null)
    fi
    echo "$local_ip $info"
}

#==============================
# 主逻辑
#==============================
case "$2" in
    init)
        get_clash_status
        get_watchdog_status
        get_yaml_info
        get_rule_version

        if [ "$merlinclash_set_mixport_sw" = "1" ] && [ -n "$porttmp" ] && [ "$porttmp" != "null" ]; then
            # 创建临时文件，用于存储返回值
            tempfile1="/tmp/mc_ip_tempfile1_$$.tmp"
            tempfile2="/tmp/mc_ip_tempfile2_$$.tmp"
            tempfile3="/tmp/mc_ip_tempfile3_$$.tmp"
            tempfile4="/tmp/mc_ip_tempfile4_$$.tmp"
            
            # 后台执行函数并将结果写入临时文件
            (check_connectivity "www.google.com.hk" "true" > "$tempfile4") &
            pid4=$!
            (check_connectivity "www.baidu.com" "false" > "$tempfile3") &
            pid3=$!
            (get_ip_info "ipv4.ip.sb" "true" > "$tempfile2") &
            pid2=$!
            (get_ip_info "ip.clang.cn" "false" > "$tempfile1") &
            pid1=$!
            #等待所有后台任务完成
            wait $pid1
            wait $pid2
            wait $pid3
            wait $pid4
            
            # 读取临时文件中的返回值并去掉换行符
            ip_info_cn=$(tr -d '\r\n' < "$tempfile1")
            ip_info_foreign=$(tr -d '\r\n' < "$tempfile2")
            conn_baidu=$(tr -d '\r\n' < "$tempfile3")
            conn_google=$(tr -d '\r\n' < "$tempfile4")
            
            # 删除临时文件
            rm "$tempfile1"
            rm "$tempfile2"
            rm "$tempfile3"
            rm "$tempfile4"
        else
            ip_info_cn="http代理端口未开启，不检测"
            ip_info_foreign="http代理端口未开启，不检测"
            conn_baidu="http代理端口未开启，不检测"
            conn_google="http代理端口未开启，不检测"
        fi

        http_response "$clash_status@$watchdog_status@$panel_host_port@$panel_port@$panel_secret@$yaml_info@$panel_port_info@$rule_version@$panel_secret_info@$clash_start@$ip_info_cn@$ip_info_foreign@$conn_baidu@$conn_google"
        ;;
    *)
        get_clash_status
        get_watchdog_status
        http_response "$clash_status@$watchdog_status@$clash_start"
        ;;
esac
