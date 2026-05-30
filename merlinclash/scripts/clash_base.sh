#!/bin/sh

source /jffs/softcenter/scripts/base.sh
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/merlinclash_log.txt

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}

get_list(){
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	b=$(echo $(dbus list $1 | cut -d "=" -f $2 | cut -d "_" -f $3 | sort -n))
	echo $b
}

### Base64解码函数
b(){
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
		echo_date "【错误】固件缺少base64decode文件，无法正常订阅，直接退出" >> $LOG_FILE
		echo_date "解决办法请查看MerlinClash Wiki" >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}

decode_url_link(){
	local link=$1
	local len=$(echo $link | wc -L)
	local mod4=$(($len%4))
	b64=$(b)	
	if [ "$mod4" -gt "0" ]; then
		local var="===="
		local newlink=${link}${var:$mod4}
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | $b64 2>/dev/null
	fi
}
encode_url_link(){
	if [ -f "/jffs/softcenter/bin/base64_encode" ]; then
		local link=$1
		# 使用 base64_encode 编码，然后转换为 URL 安全格式
		# 将 + 替换为 -, / 替换为 _, 并移除末尾的 = 填充
		echo -n "$link" | /jffs/softcenter/bin/base64_encode 2>/dev/null | sed 's/+/-/g; s/\//_/g; s/=*$//'
	else
		echo_date "【错误】固件缺少base64_encode文件，无法进行编码" >> $LOG_FILE
		echo_date "解决办法请查看MerlinClash Wiki" >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}


urldecode() {
    # 先处理 + 号转为空格
    local encoded="${1//+/ }"
    # 将 %XX 转为 \xXX，然后让printf解释
    printf "$(echo "$encoded" | sed 's/%\([0-9a-fA-F][0-9a-fA-F]\)/\\x\1/g')"
}

urlencode() {
    local string="${1}"
    
    echo -n "$string" | busybox awk '
        BEGIN {
            for (i = 0; i < 256; i++) {
                ord[sprintf("%c", i)] = i
            }
        }
        {
            len = length($0)
            for (i = 1; i <= len; i++) {
                c = substr($0, i, 1)
                if (c ~ /[a-zA-Z0-9\-_\.~]/) {
                    printf "%s", c
                } else if (c == " ") {
                    printf "+"
                } else {
                    # 处理多字节 UTF-8：取出当前字符的所有字节
                    bytes = c
                    for (j = 1; j <= length(bytes); j++) {
                        byte = substr(bytes, j, 1)
                        printf "%%%02X", ord[byte]
                    }
                }
            }
        }
    '
}
download() {
	local ua=$1
    local url=$2
    local save_As=$3

    if [ -z "$url" ] || [ -z "$save_As" ];then
        return 1
    fi

	if [ -n "$ua" ]; then
        curl -sSkL --connect-timeout 30 --max-time 120 --user-agent "$ua" "$url" -o "$save_As"
    else
        curl -sSkL --connect-timeout 30 --max-time 120 "$url" -o "$save_As"
    fi

	if [ $? -ne 0 ]; then
		return 1
	fi

	if [ ! -s "$save_As" ]; then
		return 1
	fi

	return 0
}

### 文件锁
set_lock(){
	mkdir -p /tmp/lock
	lf=$(dbus get merlinclash_lockfile)
	lcfiletmp=/tmp/lock/$lf.txt
	echo_date "Magic Catling 前一进程锁文件:$lcfiletmp"  >> $LOG_FILE

	lc=$$	
	merlinclash_lockfile="$lc"
	dbus set merlinclash_lockfile="$merlinclash_lockfile"
	lcfile1=/tmp/lock/$lc.txt
		echo_date "Magic Catling 创建本新进程锁文件${lcfile1}" >> $LOG_FILE 
		touch $lcfile1	
		i=60
		echo_date "Magic Catling 将本任务pid写入lockfile:$merlinclash_lockfile" >> $LOG_FILE
		echo $$ > ${lcfile1}

		while [ $i -ge 0 ]; do
			if [ -e ${lcfiletmp} ] && kill -0 `cat ${lcfiletmp}`; then 
				echo_date "Magic Catling: $merlinclash_lockfile 锁进程中" >> $LOG_FILE
				echo $$ > ${lcfile1}
				sleep 5s
			else
				let i=0
				echo_date "Magic Catling: 上个重启进程文件锁解除" >> $LOG_FILE
			fi
			let i--
		done
		
		# 确保退出时，锁文件被删除 
		trap "rm -rf ${lcfile1}; exit" INT TERM EXIT 
		
		echo $$ > ${lcfile1} 
		echo_date "Magic Catling: 重新创建进程锁文件${lcfile1}" >> $LOG_FILE

}

unset_lock(){
	rm -rf ${lcfile1} 
}

#MC2所有dbus变量
# merlinclash_acl_content	自定义规则-内容
# merlinclash_acl_edit_content	自定义规则-编辑
# merlinclash_acl_lianjie	自定义规则-连接
# merlinclash_acl_plan	自定义规则模式
# merlinclash_acl_protocol	自定义规则-协议
# merlinclash_acl_type	自定义规则-类型
# merlinclash_binary_type	内核类型
# merlinclash_binary_startime	启动时间
# merlinclash_db_chnroute_num	大陆ip绕行-规则数目
# merlinclash_set_chnroute_sw	大陆ip绕行-开关
# merlinclash_db_chnroute_updatetime	大陆ip更新时间
# merlinclash_db_geo_updatetime	geo更新时间
# merlinclash_set_geoip_type	geoip类型-值
# merlinclash_set_geosite_type	geosite类型-值
# merlinclash_dns_cleardns_sw	清除路由自定义DNS-开关
# merlinclash_dns_dnshijack_sw	DNS劫持-开关
# merlinclash_dns_fakeip_server	fakeip 黒名单dns 
# merlinclash_dns_proxydns_sw	路由自身DNS使用Clash设定-开关
# merlinclash_dns_sniffer_sw	sniffer-开关
# merlinclash_dns_type	dns方案-值
# merlinclash_enable	总开关
# merlinclash_ipt_closeproxy_sw	关闭透明代理
# merlinclash_ipt_ipv6_sw	代理ip6-开关
# merlinclash_ipt_proxyiot_sw	代理路访客/IoT网络-开关
# merlinclash_ipt_proxyrouter_sw	代理路由自身访问-开关
# merlinclash_ipt_routingmark_val	代理路由标记-值
# merlinclash_ipt_tproxy_type	tproxy模式-值
# merlinclash_linuxver	linux内核版本
# merlinclash_nokpacl	访问控制
# merlinclash_nokpacl_default_mode	访问控制-全局模式
# merlinclash_nokpacl_default_port	访问控制-全局端口
# merlinclash_nokpacl_ip	访问控制-ip
# merlinclash_nokpacl_mac	访问控制-mac
# merlinclash_nokpacl_method	访问控制-匹配模式
# merlinclash_nokpacl_mode	访问控制-模式
# merlinclash_nokpacl_name	访问控制-主机名
# merlinclash_nokpacl_port	访问控制-端口
# merlinclash_set_queue_sw	队列请求-开关
# merlinclash_select_clash_restart	定时重启
# merlinclash_select_clash_restart_day	定时重启-日
# merlinclash_select_clash_restart_hour	定时重启-小时
# merlinclash_select_clash_restart_minute	定时重启-分钟
# merlinclash_select_clash_restart_minute_2	定时重启-分钟2
# merlinclash_select_clash_restart_week	定时重启-周
# merlinclash_binary_ver	内核版本
# merlinclash_set_dashboard_password	管理面板密码
# merlinclash_set_interval_sw	自定义测速时间-开关
# merlinclash_set_interval_val	自定义测速时间-值
# merlinclash_set_logcheck_sw	日志检查次数-开关
# merlinclash_set_logcheck_val	日志检查次数-值
# merlinclash_set_mixport_sw	代理端口-开关
# merlinclash_set_recordbycron_sw	使用定时脚本记录代理组状态-开关
# merlinclash_set_startdelay_sw	开机自启推迟时间-开关
# merlinclash_set_startdelay_val	开机自启推迟时间-值
# merlinclash_set_tcpcon_sw	tcp并发-开关
# merlinclash_set_tolerance_sw	自定义容差-开关
# merlinclash_set_tolerance_val	自定义容差-值
# merlinclash_version	插件版本号
# merlinclash_set_watchdog_sw	看门狗-开关
# merlinclash_set_yamlsel_edit	删除规则选择-值
# merlinclash_set_yamlsel_start	配置文件选择
# merlinclash_sub_exclude	订阅-排除节点-值
# merlinclash_sub_include	订阅-包含节点-值
# merlinclash_sub_links	订阅链接-值
# merlinclash_sub_rename	订阅-名称-值
# merlinclash_sub_scv	订阅-跳过证书-开关
# merlinclash_sub_tfo	订阅-tfo-开关
# merlinclash_sub_type	订阅-规则类型
# merlinclash_sub_udp	订阅-udp-开关
# merlinclash_sub_updatecycle	订阅-更新周期
# merlinclash_sub_useragent	订阅-UA-值
# merlinclash_sub_upload_filename	上传文件名-值
# merlinclash_bak_set 备份-基础设置
# merlinclash_bak_yaml 备份-订阅文件
# merlinclash_bak_rule 备份-自定义规则
# merlinclash_bak_dns 备份-DNS设置
# merlinclash_bak_db  备份-数据库
# merlinclash_bak_acl 备份-访问控制
