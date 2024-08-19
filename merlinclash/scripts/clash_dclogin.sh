#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
b(){
	if [ -f "/jffs/softcenter/bin/base64_decode" ]; then #HND有这个
		base=/jffs/softcenter/bin/base64_decode
		echo $base
	elif [ -f "/bin/base64" ]; then #HND是这个
		base=/bin/base64
		echo $base
	elif [ -f "/sbin/base64" ]; then
		base=/sbin/base64
		echo $base
	else
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
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | $b64 -d 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | $b64 -d 2>/dev/null
	fi
}


urldecode(){
  printf $(echo -n "$1" | sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"\n"
}

name1=$(get merlinclash_dc_name)
name=$(decode_url_link $name1)
name=$(urldecode $name)
passwd1=$(get merlinclash_dc_passwd)
passwd=$(decode_url_link $passwd1)
passwd=$(urldecode $passwd)
echo_date "测试日志" > /tmp/upload/dlercloud.log
token_flag=0
#rm -rf /tmp/dc.txt
#rm -rf /tmp/dc_clash.txt
echo_date "1=$1" >> /tmp/upload/dlercloud.log
echo_date "2=$2" >> /tmp/upload/dlercloud.log

log_in () {
    #获取登陆文件
    #curl -s -d "email=$name&passwd=$passwd" https://dler.cloud/api/v1/login > /tmp/dc.txt
    curl -s -d "email=$name" --data-urlencode "passwd=$passwd" https://dler.cloud/api/v1/login > /tmp/dc.txt
    if [ -s /tmp/dc.txt ]; then
        echo_date "已获取文件，且文件不为空" >> /tmp/upload/dlercloud.log
        #line=$(sed -n ''$1'p' "/tmp/dc.txt")
        #ret=$(echo $line |grep -o "ret.*"|awk -F"[:,]" '{print $2}')
        ret=$(jq -r .ret /tmp/dc.txt)
        if [ "$ret" != "" ]; then
            echo_date "$ret" >> /tmp/upload/dlercloud.log
            if [ "$ret" == "200" ]; then
                #token=$(echo $line |grep -o "token.*"|awk -F"[:,]" '{print $2}'|awk -F\" '{print $2}')
                token=$(jq -r .data.token /tmp/dc.txt)
                plan=$(jq -r .data.plan /tmp/dc.txt)
                plan_time=$(jq -r .data.plan_time /tmp/dc.txt)
                money=$(jq -r .data.money /tmp/dc.txt)
                aff_money=$(jq -r .data.aff_money /tmp/dc.txt)
                usedTraffic=$(jq -r .data.used /tmp/dc.txt)
                unusedTraffic=$(jq -r .data.unused /tmp/dc.txt)
                integral=$(jq -r .data.Integral /tmp/dc.txt)

                dbus set merlinclash_dc_token=$token
                dbus set merlinclash_dc_plan=$plan
                dbus set merlinclash_dc_plan_time=$plan_time
                dbus set merlinclash_dc_money=$money
                dbus set merlinclash_dc_aff_money=$aff_money
                dbus set merlinclash_dc_integral=$integral
                dbus set merlinclash_dc_usedTraffic=$usedTraffic
                dbus set merlinclash_dc_unusedTraffic=$unusedTraffic
                echo_date "登陆成功" >> /tmp/upload/dlercloud.log
                http_response "$ret"
            else
                echo_date "ret:$ret" >> /tmp/upload/dlercloud.log
                http_response "$ret"
            fi
        else
            http_response "获取返回值失败"
        fi
    else
        token=""
        dbus set merlinclash_dc_token=$token
        echo_date "文件为空，获取资料失败" >> /tmp/upload/dlercloud.log
        http_response "获取资料失败"
    fi
}
log_out () {
    token=""
    plan=""
    plan_time=""
    money=""
    usedTraffic=""
    unusedTraffic=""
    aff_money=""
    integral=""
    ss=""
    v2=""
    trojan=""


    dbus set merlinclash_dc_token=$token
    dbus set merlinclash_dc_plan=$plan
    dbus set merlinclash_dc_plan_time=$plan_time
    dbus set merlinclash_dc_money=$money
    dbus set merlinclash_dc_aff_money=$aff_money
    dbus set merlinclash_dc_integral=$integral
    dbus set merlinclash_dc_usedTraffic=$usedTraffic
    dbus set merlinclash_dc_unusedTraffic=$unusedTraffic
    dbus set merlinclash_dc_ss=$ss
    dbus set merlinclash_dc_v2=$v2
    dbus set merlinclash_dc_trojan=$trojan

    http_response "logout"
}

get_info () {
        name1=$(get merlinclash_dc_name)
        name=$(decode $name1)
        name=$(urldecode $name)
        plan=$(get merlinclash_dc_plan)
        plan_time=$(get merlinclash_dc_plan_time)
        money=$(get merlinclash_dc_money)
        aff_money=$(get merlinclash_dc_aff_money)
        integral=$(get merlinclash_dc_integral)
        usedTraffic=$(get merlinclash_dc_usedTraffic)
        unusedTraffic=$(get merlinclash_dc_unusedTraffic)
        token=$(get merlinclash_dc_token)
        echo_date "【2】token:$token" >> /tmp/upload/dlercloud.log
        #获取订阅连接信息
        curl -s -d "access_token=$token" https://dler.cloud/api/v1/managed/clash >/tmp/dc_clash.txt

        if [ -s /tmp/dc_clash.txt ]; then
            echo_date "已获取文件，且文件不为空" >> /tmp/upload/dlercloud.log
            #line=$(sed -n ''$1'p' "/tmp/dc_clash.txt")
            ret=$(jq -r .ret /tmp/dc_clash.txt)
                if [ "$ret" == "200" ]; then
                    echo_date "200:取得信息" >> /tmp/upload/dlercloud.log
                    ss=$(jq -r .ss /tmp/dc_clash.txt)
                    v2=$(jq -r .vmess /tmp/dc_clash.txt)
                    trojan=$(jq -r .trojan /tmp/dc_clash.txt)
                    
                    dbus set merlinclash_dc_ss=$ss
                    dbus set merlinclash_dc_v2=$v2
                    dbus set merlinclash_dc_trojan=$trojan
                    #echo $ss
                    #echo $v2
                    #echo $trojan
                    text1="<span style='color: gold'>$name</span>"
                    text2="<span style='color: gold'>$plan</span>"
                    text3="<span style='color: gold'>$plan_time</span>"
                    text4="<span style='color: gold'>$money</span>"
                    text5="<span style='color: gold'>$usedTraffic</span>"
                    text6="<span style='color: gold'>$unusedTraffic</span>"
                    text7="<span id='dc_ss_1' style='color: gold'>$ss</span>"
                    text8="<span id='dc_v2_1'style='color: gold'>$v2</span>"
                    text9="<span id='dc_trojan_1'style='color: gold'>$trojan</span>"
                    text10="<span style='color: gold'>$token</span>"
                    text11="<span style='color: gold'>$aff_money</span>"
                    text12="<span style='color: gold'>$integral</span>"
                    echo_date "回传信息:$ret@@$text1@@$text2@@$text3@@$text4@@$text5@@$text6@@$text7@@$text8@@$text9@@$text10@@$text11@@$text12" >> /tmp/upload/dlercloud.log
                    http_response "$ret@@$text1@@$text2@@$text3@@$text4@@$text5@@$text6@@$text7@@$text8@@$text9@@$text10@@$text11@@$text12"
                else
                    http_response "$ret"
                    echo_date "403:获取资料失败" >> /tmp/upload/dlercloud.log

                fi
        else
            echo_date "文件为空，获取资料失败" >> /tmp/upload/dlercloud.log
            http_response "获取资料失败"
        fi
}
check_login(){
    curl -s -d "email=$name" --data-urlencode "passwd=$passwd" https://dler.cloud/api/v1/information > /tmp/dc.txt
    if [ -s /tmp/dc.txt ]; then
        echo_date "已获取文件，且文件不为空" >> /tmp/upload/dlercloud.log
        #line=$(sed -n ''$1'p' "/tmp/dc.txt")
        ret=$(jq -r .ret /tmp/dc.txt)
        if [ "$ret" == "200" ]; then
            #token仍然有效
            echo_date "获取info成功" >> /tmp/upload/dlercloud.log
            #token=$(jq -r .data.token /tmp/dc.txt)
            plan=$(jq -r .data.plan /tmp/dc.txt)
            plan_time=$(jq -r .data.plan_time /tmp/dc.txt)
            money=$(jq -r .data.money /tmp/dc.txt)
            aff_money=$(jq -r .data.aff_money /tmp/dc.txt)
            integral=$(jq -r .data.integral /tmp/dc.txt)
            usedTraffic=$(jq -r .data.used /tmp/dc.txt)
            unusedTraffic=$(jq -r .data.unused /tmp/dc.txt)
            
            dbus set merlinclash_dc_plan=$plan
            dbus set merlinclash_dc_plan_time=$plan_time
            dbus set merlinclash_dc_money=$money
            dbus set merlinclash_dc_aff_money=$aff_money
            dbus set merlinclash_dc_integral=$integral
            dbus set merlinclash_dc_usedTraffic=$usedTraffic
            dbus set merlinclash_dc_unusedTraffic=$unusedTraffic

            text1="<span style='color: gold'>$name</span>"
            text2="<span style='color: gold'>$plan</span>"
            text3="<span style='color: gold'>$plan_time</span>"
            text4="<span style='color: gold'>$money</span>"
            text5="<span style='color: gold'>$usedTraffic</span>"
            text6="<span style='color: gold'>$unusedTraffic</span>"
            text7="<span id='dc_ss_1' style='color: gold'>$(get merlinclash_dc_ss)</span>"
            text8="<span id='dc_v2_1' style='color: gold'>$(get merlinclash_dc_v2)</span>"
            text9="<span id='dc_trojan_1' style='color: gold'>$(get merlinclash_dc_trojan)</span>"
            text10="<span id='dc_token_1' style='color: gold'>$(get merlinclash_dc_token)</span>"
            text11="<span style='color: gold'>$aff_money</span>"
            text12="<span style='color: gold'>$integral</span>"
            echo_date "回传信息:$ret@@$text1@@$text2@@$text3@@$text4@@$text5@@$text6@@$text7@@$text8@@$text9@@$text10@@$text11@@$text12" >> /tmp/upload/dlercloud.log
            http_response "$ret@@$text1@@$text2@@$text3@@$text4@@$text5@@$text6@@$text7@@$text8@@$text9@@$text10@@$text11@@$text12"
                
        else
            #登陆失效 
            echo_date "登陆失效" >> /tmp/upload/dlercloud.log
            log_out
        fi
    fi
}

case $2 in
login)
    echo_date "登陆校验" >> /tmp/upload/dlercloud.log
	log_in
	;;
token)
    echo_date "检测登陆有效性" >> /tmp/upload/dlercloud.log
	check_login
	;;
info)
    echo_date "读取信息" >> /tmp/upload/dlercloud.log
    get_info
    ;;
logout)
    echo_date "退出登录" >> /tmp/upload/dlercloud.log
    log_out
    ;;
esac


