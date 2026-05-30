#!/bin/sh

source /jffs/softcenter/scripts/clash_base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt
uploadpath=/tmp/upload/yaml
uploadfilename=${merlinclash_sub_upload_filename}
fp=/jffs/softcenter/merlinclash/yaml_bak

UA=$(decode_url_link ${merlinclash_sub_useragent})
include=$(decode_url_link ${merlinclash_sub_include})
exclude=$(decode_url_link ${merlinclash_sub_exclude})
mkdir -p /jffs/softcenter/merlinclash/yaml_bak/

get_yaml_name(){
	case "${merlinclash_sub_type}" in
		MCrule)
			_name="MC_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mc.yaml"
		;;
	    MCrule_No)
			_name="MCN_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mc_noping.yaml"
		;;
        MCrule_Media)
			_name="MM_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mcmedia.yaml"
		;;
        MCrule_Media_No)
			_name="MMN_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mcmedia_noping.yaml"
		;;
        MCrule_Media_AreaU)
			_name="MMU_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mcmedia_area_urltest.yaml"
		;;
        MCrule_Media_AreaF)
			_name="MMF_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mcmedia_area_fallback.yaml"
		;;
        MCrule_Custom)
			_name="MCU_"
            rule_file="/jffs/softcenter/merlinclash/rule_configs/rule_mc_custom.yaml"
		;;
		APrule)
			_name="AP_"
		;;	
	esac
        
    if [ -z "${merlinclash_sub_rename}" ]; then
        local time=$(date "+%Y%m%d-%H%M%S")
        merlinclash_sub_rename=$(echo $time | awk -F'-' '{print $2}')
    fi
    subscribe_name="${_name}${merlinclash_sub_rename}"
    echo_date "订阅名称为$subscribe_name" >> $LOG_FILE
    
}

# 本地上传
yaml_upload(){
	#查找upload文件夹是否有刚刚上传的yaml文件，正常只有一份
    echo_date ------------------------ 📌上传配置 ------------------------ >> $LOG_FILE
	echo_date "上传的文件名是$uploadfilename" >> $LOG_FILE
	if [ -f "/tmp/upload/$uploadfilename" ]; then
		echo_date "开始yaml配置文件预处理"
		mkdir -p /tmp/upload/yaml
		rm -rf /tmp/upload/yaml/*
        cp -rf /tmp/upload/$uploadfilename /tmp/upload/yaml/$uploadfilename
	else
		echo_date "❌订阅失败，没找到yaml配置文件"
		rm -rf /tmp/upload/*.yaml
        unset_lock
		echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
        exit 1
	fi
}

# 下载配置
yaml_download(){
    echo_date "------------------------ 📌下载配置 ------------------------" >> $LOG_FILE
    echo_date "订阅UA是：$UA" >> $LOG_FILE

    mkdir -p /tmp/upload/yaml
    rm -rf /tmp/upload/yaml/*

    echo_date "订阅地址是：$merlinc_link" >> $LOG_FILE

    # 生成文件名
    local upname=${subscribe_name}

    echo_date "下载文件重命名为：$upname" >> $LOG_FILE
    echo_date "开始下载配置文件..." >> $LOG_FILE

    # 下载文件
    if download "$UA" "$merlinc_link" "/tmp/upload/yaml/$upname.yaml"; then
        echo_date "✅已成功获取YAML配置文件" >> $LOG_FILE
    else
        echo_date "❌下载YAML配置文件出错" >> $LOG_FILE
        unset_lock
        echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
        exit 1
    fi
}

# 修改patch
yaml_editpath(){
    echo_date ------------------------ 📌编辑配置 ------------------------ >> $LOG_FILE
    name=$(find $uploadpath  -name "*.yaml" |sed 's#.*/##')
    name2=$(echo $name | awk -F "." '{print $1}')
    yaml_tmp=/tmp/upload/yaml/$name
    yaml_tmp2=/tmp/upload/yaml/${name2}_tmp.yaml
    # 截取需要的字段
    yq eval 'explode(.) | pick(["proxies", "proxy-providers", "proxy-groups", "rule-providers", "rules", "sub-rules"])' $yaml_tmp > $yaml_tmp2
    mv -f "$yaml_tmp2" "$yaml_tmp"

    if yq eval '.proxy-providers | length > 0' "$yaml_tmp" 2>/dev/null | grep -q "true"; then
        echo_date "开始修改proxy-providers存放路径"
    
        # 获取所有 provider 的名称
        providers=$(yq eval '.proxy-providers | keys | .[]' "$yaml_tmp")
        
        # 处理每个 provider
        for provider in $providers; do
        
            # 检查这个 provider 是否有 url 字段
            proxyurl=$(yq eval ".proxy-providers.\"$provider\".url" "$yaml_tmp" 2>/dev/null)

            if [ -n "$proxyurl" ] && [ "$proxyurl" != "null" ]; then
                # 计算 url 的 MD5 值
                urlmd5=$(echo -n "$proxyurl" | md5sum | awk '{print $1}')
            
                # 设置新的 path
                new_path="./yaml_bak/${name2}/${urlmd5}"
            
                # 更新这个 provider 的 path
                yq eval ".proxy-providers.\"$provider\".path = \"$new_path\"" "$yaml_tmp" > "${yaml_tmp}.tmp"
                mv -f "${yaml_tmp}.tmp" "$yaml_tmp"
                echo_date "处理 $provider 成功" 
            else
                echo_date "$provider 没有 url 字段，跳过"
            fi
        done    
    fi

    if yq eval '.rule-providers | length > 0' "$yaml_tmp" 2>/dev/null | grep -q "true"; then
        echo_date "开始修改rule-providers存放路径"
    
        # 获取所有 provider 的名称
        rules=$(yq eval '.rule-providers | keys | .[]' "$yaml_tmp")
        
        # 处理每个 provider
        for rule in $rules; do
        
            # 检查这个 provider 是否有 url 字段
            ruleurl=$(yq eval ".rule-providers.\"$rule\".url" "$yaml_tmp" 2>/dev/null)

            if [ -n "$ruleurl" ] && [ "$ruleurl" != "null" ]; then
                # 计算 url 的 MD5 值
                rurlmd5=$(echo -n "$ruleurl" | md5sum | awk '{print $1}')
            
                # 设置新的 path
                new_rpath="./yaml_bak/${name2}/${rurlmd5}"
            
                # 更新这个 provider 的 path
                yq eval ".rule-providers.\"$rule\".path = \"$new_rpath\"" "$yaml_tmp" > "${yaml_tmp}.tmp"
                mv -f "${yaml_tmp}.tmp" "$yaml_tmp"
                echo_date "处理 $rule 成功" 
            else
                echo_date "$rule 没有 url 字段，跳过"
            fi
        done    
    fi
}

# 配置预处理
yaml_prepare(){
    echo_date ----------------------- 📌预处理配置 ----------------------- >> $LOG_FILE
    
    name=$(find $uploadpath  -name "*.yaml" |sed 's#.*/##')
    name2=$(echo $name | awk -F "." '{print $1}')
    yaml_tmp=/tmp/upload/yaml/$name
    if [ -f "$yaml_tmp" ]; then
        echo_date "开始yaml预处理" >> $LOG_FILE
        local has_proxies=0
        local has_providers=0
        local has_rules=0
    
         #检查yaml文件中是否包含proxies或proxy-providers，以及rules
        if yq eval '.proxies' "$yaml_tmp" 2>/dev/null | grep -q -v "null"; then
            has_proxies=1
        fi
        if yq eval '.proxy-providers' "$yaml_tmp" 2>/dev/null | grep -q -v "null"; then
            has_providers=1
        fi

        if yq eval '.rules' "$yaml_tmp" 2>/dev/null | grep -q -v "null"; then
            has_rules=1
        fi
    
        if { [ "$has_proxies" -eq 1 ] || [ "$has_providers" -eq 1 ]; } && [ "$has_rules" -eq 1 ]; then   
            echo_date "移动配置文件至yaml_bak文件夹" >> $LOG_FILE
            cp -rf $yaml_tmp /jffs/softcenter/merlinclash/yaml_bak/$name
            cp -rf /jffs/softcenter/merlinclash/yaml_bak/$name /jffs/softcenter/merlinclash/yaml_use/$name

            #生成新的txt文件
            rm -rf $fp/yamls.txt
            echo_date "创建yaml文件列表" >> $LOG_FILE
            find $fp -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' >> $fp/yamls.txt
            #创建软链接
            ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
            #原始规则生成字典文件
            if [ "${_name}" = "AP_" ]; then
                echo "${merlinclash_sub_updatecycle},${name2},${merlinc_link}" > "/jffs/softcenter/merlinclash/yaml_bak/${name2}.dlinks"
                echo_date "生成订阅字典文件" >> $LOG_FILE
            fi
            
            echo_date "✅恭喜！！订阅成功" >> $LOG_FILE
            echo_date "若在[配置文件选择]中看不到文件，请Ctrl+F5刷新页面" >> $LOG_FILE
        else
            echo_date "❌订阅失败，配置文件格式错误或缺少必要参数！！！" >> $LOG_FILE
            #删除/upload可能残留的yaml格式文件
            [ -n "${name2}" ] && [ -d "/jffs/softcenter/merlinclash/yaml_bak/${name2}" ] && rm -rf "/jffs/softcenter/merlinclash/yaml_bak/${name2}"
        fi

    else
        echo_date "❌订阅失败，找不Yaml配置文件" >> $LOG_FILE
        [ -n "${name2}" ] && [ -d "/jffs/softcenter/merlinclash/yaml_bak/${name2}" ] && rm -rf "/jffs/softcenter/merlinclash/yaml_bak/${name2}"
    fi
    #删除/upload可能残留的yaml格式文件
    rm -rf /tmp/upload/yaml/*.yaml
    rm -rf /tmp/upload/*.yaml
}

# URL解析和处理函数
parse_and_process_urls() {
    local input_text="$1"
    local config_file="${2:-/jffs/softcenter/merlinclash/yaml_bak/${subscribe_name}/Custom.yaml}"
    local ap_dir="${3:-/jffs/softcenter/merlinclash/yaml_bak/${subscribe_name}}"
    local file_name="${4:-""}"
    # 清理现有配置文件
    rm -rf "$ap_dir" >/dev/null 2>&1
    # 计数器
    local count=1
    local url name ua_tmp
    
    # 临时保存IFS
    local OLDIFS="$IFS"
    IFS='|'
    
    # 处理每个链接
    for item in $input_text; do
        # 清理和提取
        item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local file_name="AP${count}"
        # 初始化 ua_tmp
        ua_tmp=""
        # 提取 <xxx> 中的内容到 ua_tmp
        if echo "$item" | grep -q '<'; then
            ua_tmp=$(echo "$item" | sed 's/.*<\([^>]*\)>.*/\1/')
        fi
        if echo "$item" | grep -q '('; then
            url=$(echo "$item" | sed 's/<[^>]*>//g;s/(.*)$//;s/[[:space:]]*$//')
            name=$(echo "$item" | sed 's/.*(\([^)]*\)).*/\1/;s/^[[:space:]]*//')
        else
            url=$(echo "$item" | sed 's/<[^>]*>//g')
            name="AP${count}"
        fi
        
        # 根据协议处理
        case "$url" in
            http://*|https://*)
                # HTTP/HTTPS处理
                echo_date "🟠识别到链接${count}为订阅链接，处理中~" >> $LOG_FILE
                process_http_link "$url" "$name" "$ap_dir" "$file_name" "$ua_tmp"
                ;;
            [a-zA-Z0-9]*://*)
                # 其他协议处理
                echo_date "🟠识别到链接${count}为节点链接，处理中~" >> $LOG_FILE
                mkdir -p "$ap_dir"
                process_other_link "$url" "$name" "$config_file"
                ;;
            *)
                echo_date "🔴订阅链接${count}，无法识别，略过~" >> $LOG_FILE
                ;;
        esac
        
        count=$((count + 1))
    done
    
    IFS="$OLDIFS"
    
    local total=$((count - 1))
    echo_date "🟢处理完成，共处理$total 个订阅" >> $LOG_FILE
    return $total
}

# HTTP链接处理函数
process_http_link() {
    local url="$1"
    local name="$2"
    local ap_dir="$3"
    local file_name="$4"
    local ua_tmp="$5"
    local yamltmp_file="/tmp/upload/yaml/${subscribe_name}_tmp.yaml"
    local path="./yaml_bak/${subscribe_name}/${file_name}.yaml"

    if [ ! -f "$yamltmp_file" ]; then
        echo "" > "$yamltmp_file"
    fi

    # 使用 yq 写入配置
    yq eval ".proxy-providers.\"$name\".type = \"http\"" -i "$yamltmp_file"
    yq eval ".proxy-providers.\"$name\".url = \"$url\"" -i "$yamltmp_file"
    yq eval ".proxy-providers.\"$name\".path = \"$path\"" -i "$yamltmp_file"
    yq eval ".proxy-providers.\"$name\".interval = \"${merlinclash_sub_updatecycle}\"" -i "$yamltmp_file"
    yq eval ".proxy-providers.\"$name\".proxy = \"DIRECT\"" -i "$yamltmp_file"
    if [ -n "$ua_tmp" ]; then
        yq eval ".proxy-providers.\"$name\".header.User-Agent = [\"$ua_tmp\"]" -i "$yamltmp_file"
    elif [ -n "$UA" ]; then
        yq eval ".proxy-providers.\"$name\".header.User-Agent = [\"$UA\"]" -i "$yamltmp_file"
    fi
    # yq eval ".proxy-providers.\"$name\".health-check.enable = false" -i "$yamltmp_file"
    yq eval ".proxy-providers.\"$name\".override.additional-suffix = \" [$name]\"" -i "$yamltmp_file"

    # 复写部分
    if [ "${merlinclash_sub_scv}" == "1" ]; then
        yq eval ".proxy-providers.\"$name\".override.skip-cert-verify = true" -i "$yamltmp_file"
    fi
    if [ "${merlinclash_sub_udp}" == "1" ]; then
        yq eval ".proxy-providers.\"$name\".override.udp = true" -i "$yamltmp_file"
    fi
    if [ "${merlinclash_sub_tfo}" == "1" ]; then
        yq eval ".proxy-providers.\"$name\".override.tfo = true" -i "$yamltmp_file"
    fi
    # 过滤部分
    if [ -n "$include" ]; then
        yq eval ".proxy-providers.\"$name\".filter = \"$include\"" -i "$yamltmp_file"
    fi
    if [ -n "$exclude" ]; then
        yq eval ".proxy-providers.\"$name\".exclude-filter = \"$exclude\"" -i "$yamltmp_file"
    fi
    echo_date "订阅名称：$name" >> $LOG_FILE
    echo_date "订阅链接： $url" >> $LOG_FILE
    echo_date "🟢写入完成" >> $LOG_FILE
}

# 其他协议链接处理函数
process_other_link() {
    local url="$1"
    local name="$2"
    local config_file="$3"
    echo_date "节点名称：$name" >> $LOG_FILE
    echo_date "节点链接： $url" >> $LOG_FILE
    echo_date "🟢节点写入完成" >> $LOG_FILE
    
    # 写入链接
    echo "$url" >> "$config_file"
}

# 机场规则链接处理
aprule_links() {
    merlinc_link=""
    local input="$1"
    local count=1
    local links=""
    
    # 清理输入
    input=$(echo "$input" | tr -d '\r\n')

    if echo "$input" | grep -q '|'; then
        echo_date "🔺当使用机场规则时，合并订阅不可用，准备取第一个可用订阅链接" >> "$LOG_FILE"
    fi
    
    # 使用IFS分割字符串，避免子shell问题
    OLDIFS="$IFS"
    IFS='|'
    
    for item in $input; do
        # 提取URL（移除 <xxx> 和 (xxx) 部分）
        url=$(echo "$item" | sed 's/<[^>]*>//g;s/(.*//;s/[[:space:]]*$//')
        
        # 输出结果
        if [ -n "$url" ]; then
            # 检查是否为第一个HTTP/HTTPS链接
            if [ -z "$links" ] && echo "$url" | grep -q '^https\?://'; then
                links="$url"
            fi
            
            count=$((count + 1))
        fi
    done
    
    IFS="$OLDIFS"
    
    # 输出links和总数
    if [ -n "$links" ]; then
        merlinc_link="$links"
    else
        echo_date "❌未能解析到可用订阅链接" >> "$LOG_FILE"
        echo_date "使用机场规则只支持http(s)://开头的订阅地址，不支持vmess://等开头的节点订阅" >> "$LOG_FILE"
        echo_date "❌请确认您的订阅地址正确，退出！！" >> "$LOG_FILE"
        unset_lock
        echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	    exit 1
    fi
    
    local total=$((count - 1))
}

# 合并配置文件
yaml_merge(){
    echo_date ------------------------ 📌合并配置 ------------------------ >> $LOG_FILE
    local yamltmp_file="/tmp/upload/yaml/${subscribe_name}_tmp.yaml"
    local yaml_file="/tmp/upload/yaml/${subscribe_name}.yaml"
    local custom_file="/jffs/softcenter/merlinclash/yaml_bak/${subscribe_name}/Custom.yaml"
    local custom_path="./yaml_bak/${subscribe_name}/Custom.yaml"

    if [ ! -f "$yamltmp_file" ]; then
        echo "" > "$yamltmp_file"
    fi

    #写入自定节点provider
    if [ -f "$custom_file" ]; then
        echo_date "🟠检测到节点链接文件，写入Custom Provider信息" >> $LOG_FILE
        yq eval ".proxy-providers.Custom.type = \"file\"" -i "$yamltmp_file"
        yq eval ".proxy-providers.Custom.path = \"$custom_path\"" -i "$yamltmp_file"
        # yq eval ".proxy-providers.Custom.health-check.enable = false" -i "$yamltmp_file"
        yq eval ".proxy-providers.Custom.override.additional-suffix = \" [Custom]\"" -i "$yamltmp_file"
            # 复写部分
        if [ "${merlinclash_sub_scv}" == "1" ]; then
            yq eval ".proxy-providers.Custom.override.skip-cert-verify = true" -i "$yamltmp_file"
        fi
        if [ "${merlinclash_sub_udp}" == "1" ]; then
            yq eval ".proxy-providers.Custom.override.udp = true" -i "$yamltmp_file"
        fi
        if [ "${merlinclash_sub_tfo}" == "1" ]; then
            yq eval ".proxy-providers.Custom.override.tfo = true" -i "$yamltmp_file"
        fi
    fi
    if [ "${merlinclash_sub_emoji}" == "1" ]; then
        yq eval ".proxy-providers.[].override.<< alias = \"emoji_rename\"" -i "$yamltmp_file"
        cat /jffs/softcenter/merlinclash/rule_configs/emoji.yaml $yamltmp_file >> ${yamltmp_file}.tmp && mv ${yamltmp_file}.tmp $yamltmp_file      
    fi
    # 合并文件 
    sed -i '$a' $yamltmp_file
    cat $rule_file >> $yamltmp_file
    mv -f "$yamltmp_file" "$yaml_file"
    # yq -n 'load("$yamltmp_file") * load("$rule_file")' > "$yaml_file"
    rm -rf "$yamltmp_file"
    echo_date "配置文件合并完成" >> $LOG_FILE
}

#主流程
run_upload(){
    yaml_upload
    yaml_editpath
    yaml_prepare
}

run_subscribe(){
    subscribe_links=$(decode_url_link ${merlinclash_sub_links})
    get_yaml_name
    if [ "${_name}" = "AP_" ]; then
        aprule_links "${subscribe_links}"
        yaml_download
        yaml_editpath
        
    else
    	mkdir -p /tmp/upload/yaml
		rm -rf /tmp/upload/yaml/*
        parse_and_process_urls "${subscribe_links}"
        yaml_merge
    fi
    yaml_prepare
}

run_update(){
    subscribe_name=${merlinclash_set_yamlsel_edit}
    yaml_dlinks_file=/jffs/softcenter/merlinclash/yaml_bak/${merlinclash_set_yamlsel_edit}.dlinks
    merlinc_link=$(awk -F',' '{print $3; exit}' "${yaml_dlinks_file}")
    if [ -n "$subscribe_name" ] && [ -n "$merlinc_link" ] && [ -f "${yaml_dlinks_file}" ];then
        yaml_download
        yaml_editpath
        yaml_prepare
        if [ "${merlinclash_set_yamlsel_edit}" == "${merlinclash_set_yamlsel_start}" ] && [ "${merlinclash_enable}" == "1" ];then
            echo_date "" >> $LOG_FILE
            echo_date "🟢重启插件，应用新的配置文件..." >> $LOG_FILE
            echo_date "" >> $LOG_FILE
            sh /jffs/softcenter/scripts/clash_config.sh restart restart
        fi
    else
        echo_date "❌订阅字典文件丢失，退出订阅更新" >> $LOG_FILE
    fi
}

run_update_cron(){
    subscribe_name=${merlinclash_set_yamlsel_start}
    yaml_dlinks_file=/jffs/softcenter/merlinclash/yaml_bak/${merlinclash_set_yamlsel_start}.dlinks
    merlinc_link=$(awk -F',' '{print $3; exit}' "${yaml_dlinks_file}")
    if [ -n "$subscribe_name" ] && [ -n "$merlinc_link" ] && [ -f "${yaml_dlinks_file}" ];then
        logger "[软件中心-计划任务]: Magic Catling开始定时订阅"
        yaml_download
        yaml_editpath
        yaml_prepare
        if [ "${merlinclash_enable}" == "1" ];then
            echo_date "" >> $LOG_FILE
            echo_date "🟢重启插件，应用新的配置文件..." >> $LOG_FILE
            echo_date "" >> $LOG_FILE
            sh /jffs/softcenter/scripts/clash_config.sh restart restart
        fi
    else
        echo_date "❌订阅字典文件丢失，退出定时订阅" >> $LOG_FILE
        logger "[软件中心-计划任务]: Magic Catling定时订阅失败"
    fi
}

case $2 in

upload)
	echo "" > $LOG_FILE
    http_response "$1"
    echo_date ====================== 本地上传YAML配置 ====================== >> $LOG_FILE
    set_lock
	run_upload >> $LOG_FILE
    unset_lock
	http_response 'success'
    echo_date ====================== 本地上传YAML配置 ====================== >> $LOG_FILE
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
subscribe)
    echo "" > $LOG_FILE
    http_response "$1"
    echo_date ====================== 在线订阅YAML配置 ====================== >> $LOG_FILE
    set_lock
    run_subscribe >> $LOG_FILE
    unset_lock
    http_response 'success'
    echo_date ====================== 在线订阅YAML配置 ====================== >> $LOG_FILE
    echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
    ;;
update)
    echo "" > $LOG_FILE
    http_response "$1"
    echo_date ====================== 在线更新YAML配置 ====================== >> $LOG_FILE
    set_lock
    run_update >> $LOG_FILE
    unset_lock
    http_response 'success'
    echo_date ====================== 在线订阅YAML配置 ====================== >> $LOG_FILE
    echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
    ;;
cron)
    echo_date ====================== 定时更新YAML配置 ====================== >> $LOG_FILE
    set_lock
    run_update_cron >> $LOG_FILE
    unset_lock
    http_response 'success'
    echo_date ====================== 定时订阅YAML配置 ====================== >> $LOG_FILE
    echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
    ;;
esac
