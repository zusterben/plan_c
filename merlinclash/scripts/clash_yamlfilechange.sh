#!/bin/sh

### 基础环境 ###
source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)

alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'

# 路径
DNS_PATH="$KSROOT/merlinclash/yaml_dns"
BASIC_PATH="$KSROOT/merlinclash/yaml_basic"
TMP_FILE="/tmp/edityaml.txt"
LOG_FILE="/tmp/upload/dnsfile.log"

# 清空日志
rm -rf "$LOG_FILE"

### 工具函数 ###
# URL 解码（不追加多余换行）
urldecode() {
    sed 's/+/ /g; s/%\(..\)/\\x\1/g;' | xargs -0 printf "%b"
}

# 统一去掉 Windows 回车并删除所有“仅空白”的行
strip_blank_lines() {
    # sub(/\r$/,"") 去掉每行末尾的 \r；NF 为 0 则是空白行（含空格/Tab）
    awk '{ sub(/\r$/,""); if (NF) print }'
}

get_dbus_value() {
    dbus get "$1"
}

get_base64_bin() {
	if [ -f "/jffs/softcenter/bin/base64_decode" ]; then
		base=base64_decode
		echo $base
	elif [ -f "/bin/base64" ]; then
		base=base64
		echo "$base -d"
	elif [ -f "/sbin/base64" ]; then
		base=base64
		echo "$base -d"
	else
		echo_date "【错误】未找到 base64 解码工具，无法继续执行" >> "$LOG_FILE"
		echo_date "请参考 MerlinClash Wiki 解决办法" >> "$LOG_FILE"
		exit 1
	fi
}

clear_dbus_content() {
    dbus list merlinclash_yamledit_content_ | cut -d "=" -f 1 | while read -r key; do
        dbus remove "$key"
    done
}

write_yaml_file() {
    local tag="$1" outfile

    case "$tag" in
        redirhost) outfile="$DNS_PATH/redirhost.yaml" ;;
        fakeip)    outfile="$DNS_PATH/fakeip.yaml" ;;
        sniffer)   outfile="$BASIC_PATH/sniffer.yaml" ;;
        hosts)     outfile="$BASIC_PATH/hosts.yaml" ;;
        head)      outfile="$BASIC_PATH/head.yaml" ;;
        acl)       outfile="/jffs/softcenter/merlinclash/rule_custom/${merlinclash_set_yamlsel_start}_custom_rule.yaml" ;;
        iptblack)  outfile="$BASIC_PATH/ipsetproxyarround.yaml" ;;
        iptwhite)  outfile="$BASIC_PATH/ipsetproxy.yaml" ;;
        *) echo_date "【警告】未知的 tag: $tag" >> "$LOG_FILE"; return ;;
    esac

    # urldecode -> 去 CRLF + 删空行 -> 写入文件
    # 注意：错误追加到日志，不混入 YAML 文件
    if ! urldecode < "$TMP_FILE" | strip_blank_lines > "$outfile" 2>>"$LOG_FILE"; then
        echo_date "【错误】写入 $outfile 失败" >> "$LOG_FILE"
        return 1
    fi
}

### 主逻辑 ###
main() {
    local count tag content="" b64_bin

    count_0="$(get_dbus_value merlinclash_yamledit_content_0)"
    count="$(get_dbus_value merlinclash_yamledit_content_count)"
    tag="$(get_dbus_value merlinclash_yamledit_tag)"

    # 无数据则直接响应并退出
    if [ -z "$count" ] || [ "$count" -eq 0 ] >/dev/null 2>&1; then
        http_response "$1"
        exit 0
    fi
    # ipt绕行为空，删除文件yaml
    if [ "$count_0" == " " ] ; then
        if [ "$tag" == "iptwhite" ]; then
            rm -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxy.yaml
        elif [ "$tag" == "iptblack" ]; then
            rm -rf /jffs/softcenter/merlinclash/yaml_basic/ipsetproxyarround.yaml
        elif [ "$tag" == "acl" ]; then
            rm -rf /jffs/softcenter/merlinclash/rule_custom/${merlinclash_set_yamlsel_start}_custom_rule.yaml
        fi
    fi
    # 聚合分片内容
    i=0
    while [ "$i" -lt "$count" ]; do
        txt="$(get_dbus_value merlinclash_yamledit_content_$i)"
        content="${content}${txt}"
        i=$((i+1))
    done

    # base64 解码到临时文件（避免 echo 追加换行）
    b64_bin="$(get_base64_bin)"
    if ! printf "%s" "$content" | "$b64_bin" > "$TMP_FILE" 2>>"$LOG_FILE"; then
        echo_date "【错误】Base64 解码失败" >> "$LOG_FILE"
        http_response "$1"
        exit 1
    fi

    if [ -s "$TMP_FILE" ]; then
        echo_date "中间文件已创建" >> "$LOG_FILE"
        echo_date "生成新文件: $tag" >> "$LOG_FILE"
        write_yaml_file "$tag" || true
        rm -f "$TMP_FILE"
    fi
    if [ "$tag" == "acl" ]; then
        /bin/sh /jffs/softcenter/scripts/clash_saveacls.sh push push
    fi
    # 清理 dbus 临时键
    clear_dbus_content

    http_response "$1"
}

main "$@"
