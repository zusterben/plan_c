#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

# 通用函数定义
detect_domain() {
    domain1=$(echo $1 | grep -E "^https://|^http://")
    domain2=$(echo $1 | grep -E "\.")
    if [ -n "$domain1" ] || [ -z "$domain2" ]; then
        return 1
    else
        return 0
    fi
}

detect_ip() {
    IPADDR=$1
    
    # IPv4地址 + 可选掩码 /0-32
    regex_v4="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\/([0-9]|[1-2][0-9]|3[0-2]))?$"
    
    # 实用的IPv6正则表达式（支持常见格式）
    # 支持：
    # 1. 完整格式: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
    # 2. 压缩格式: 2001:db8::1, ::1, 2001:db8::, ::ffff:192.0.2.1
    # 3. IPv4映射: ::ffff:192.0.2.1
    # 4. 可选掩码: /0 - /128
    
    # 分解构建正则表达式
    hex4="[0-9a-fA-F]{1,4}"
    ipv4seg="(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])"
    ipv4="(${ipv4seg}\\.){3}${ipv4seg}"
    
    # 主要IPv6模式
    regex_v6="^("
    # 1. 完整8组
    regex_v6="${regex_v6}(${hex4}:){7}${hex4}|"
    # 2. 压缩格式（各种位置）
    regex_v6="${regex_v6}(${hex4}:){1,7}:|"
    regex_v6="${regex_v6}:(${hex4}:){1,7}|"
    regex_v6="${regex_v6}(${hex4}:){1,6}:${hex4}|"
    regex_v6="${regex_v6}:(${hex4}:){1,6}:${hex4}|"
    # 3. 双冒号格式
    regex_v6="${regex_v6}(::(${hex4}:){0,6}${hex4})|"
    regex_v6="${regex_v6}(${hex4}:){1,}:|"
    regex_v6="${regex_v6}:|"
    # 4. IPv4映射地址
    regex_v6="${regex_v6}::(ffff(:0{1,4}){0,1}:){0,1}${ipv4}|"
    regex_v6="${regex_v6}(${hex4}:){1,4}:${ipv4}"
    regex_v6="${regex_v6})(\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8]))?$"

    if echo "$IPADDR" | grep -Eq "$regex_v4"; then
        return 4
    elif echo "$IPADDR" | grep -Eq "$regex_v6"; then
        return 6
    else
        return 1
    fi
}

# 通用处理函数
process_ipset_list() {
    local config_type=$1  # ipsetproxy 或 ipsetproxyarround
    local ipset_group=$2
    local config_file="/jffs/softcenter/merlinclash/yaml_basic/${config_type}.yaml"
    local conf_file="/jffs/softcenter/merlinclash/conf/${config_type}.conf"
    local dnsmasq_conf="/tmp/etc/dnsmasq.user/${config_type}.conf"
    local ipset_name_v4="ipset_${ipset_group}"
    local ipset_name_v6="ipset_${ipset_group}6"

    
    # 清空对应的ipset
    ipset -F "$ipset_name_v4" >/dev/null 2>&1
    ipset -F "$ipset_name_v6" >/dev/null 2>&1
    
    if [ -s "$config_file" ]; then

        # 清理临时文件和配置文件
        rm -rf "/tmp/${config_type}.list" \
               "/tmp/clash_${config_type}_tmp.txt" \
               "/tmp/clash_${config_type}_tmp2.txt" \
               "$conf_file" \
               "$dnsmasq_conf" 2>/dev/null
        
        # 复制配置文件到临时位置
        cp -rf "$config_file" "/tmp/${config_type}.list" 2>/dev/null
        
        # 处理每一行
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | xargs)  # 去除首尾空格
            [ -z "$line" ] && continue    # 跳过空行
            
            # 检测是否为IP格式
            detect_ip "$line"
            ip_type=$?
            
            if [ "$ip_type" = "4" ]; then
                echo_date "◆${line}为合法IPv4格式，添加到$ipset_name_v4" >> $LOG_FILE
                ipset -! add "$ipset_name_v4" "$line" >/dev/null 2>&1
            elif [ "$ip_type" = "6" ]; then
                echo_date "◆${line}为合法IPv6格式，添加到$ipset_name_v6" >> $LOG_FILE
                ipset -! add "$ipset_name_v6" "$line" >/dev/null 2>&1
            else
                detect_domain "$line"
                if [ "$?" = "0" ]; then
                    echo_date "◆${line}为合法域名格式，写入${config_type}配置" >> $LOG_FILE
                    # dnsmasq会在DNS查询时自动将域名解析的IP添加到对应的ipset中
                    echo "ipset=/.${line}/${ipset_name_v4},${ipset_name_v6}" >> "$conf_file"
                else
                    echo_date "◆格式有误，略过: ${line}" >> $LOG_FILE
                fi
            fi
        done < "/tmp/${config_type}.list"
        
        # 创建dnsmasq软链接
        if [ -f "$conf_file" ]; then
            ln -sf "$conf_file" "$dnsmasq_conf" >/dev/null 2>&1
            echo_date "◆链接${config_type}到dnsmasq配置！" >> $LOG_FILE
        fi
        
    else
        # 配置文件为空，清理相关文件
        rm -rf "$conf_file" "$dnsmasq_conf" 2>/dev/null
        echo_date "◇${config_type}配置文件为空，已清理相关配置" >> $LOG_FILE
    fi
}

case $2 in
ipsetproxy)
    process_ipset_list "ipsetproxy" "proxy"
    ;;
ipsetproxyarround)
    process_ipset_list "ipsetproxyarround" "proxyarround"
    ;;
esac
