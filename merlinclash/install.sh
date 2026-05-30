#! /bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash)
#alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
MODEL=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
builddate=$(uname -v | awk '{print $NF}')
mcinstall=$(dbus get softcenter_module_merlinclash_install)
Geosite_PATH="/jffs/softcenter/merlinclash/GeoSite.dat" 
GeoIP_PATH="/jffs/softcenter/merlinclash/GeoIP.dat"
get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

fuck_bug(){
	mc2_install=$(dbus get softcenter_module_merlinclash_title)
	mc2_version=$(dbus get merlinclash_version | sed 's/[A-Za-z]//g' | sed 's/\.[^.]*$//' | tr -d '.')
	mc2_version=${mc2_version:-68}		
	if [ "${mcinstall}" == "1" ] && [ "$mc2_install" != "Magic Catling2" -o "$mc2_version" -lt 100 ]; then
		echo_date "已安装旧版本的Merlin Clash，本插件与之冲突！"
		echo_date "请卸载后，再次安装Magic Catling 2！"
		exit_install 2
	fi
}
platform_test(){
	local firmware_version=`dbus get softcenter_firmware_version`
	if [ ! -d "/jffs/softcenter" ];then
		echo_date "机型：${MODEL} $(nvram get firmver)_$(nvram get buildno)_$(nvram get extendno) 不符合安装要求，无法安装插件！"
		exit_install 1
	fi
	if [ "$(/jffs/softcenter/bin/versioncmp $firmware_version 5.2.8)" == "1" ];then
		echo_date "本插件适用于最低固件版本为5.2.8,固件版本过低，无法安装"
		exit_install 0
	fi
	# 继续判断各个固件的内核和架构
	local PKG_ARCH=$(cat ${DIR}/.arch)
	local ROT_ARCH=$(dbus get softcenter_arch)
	local KEL_VERS=$(uname -r)
	if [ "$ROT_ARCH" == "" ]; then
		/jffs/softcenter/bin/sc_auth arch
		ROT_ARCH=$(dbus get softcenter_arch)
	fi
	if [ "$ROT_ARCH" == "armv7l" ]; then
		ROT_ARCH="arm"
	elif [ "$ROT_ARCH" == "aarch64" ]; then
		ROT_ARCH="arm64"
	fi
	if [ "${PKG_ARCH}" == "${ROT_ARCH}" ];then
		echo_date "内核：${KEL_VERS}，架构：${ROT_ARCH}，安装Merlin Clash！"
	else
		echo_date "内核：${KEL_VERS}，架构：${ROT_ARCH}，Merlin Clash不适用于该内核版本！"
		echo_date "下载地址：https://github.com/zusterben/plan_c/tree/master/bin/${ROT_ARCH}"
		exit_install 1
	fi
}

set_skin(){
	local UI_TYPE=ASUSWRT
	local SC_SKIN=$(nvram get sc_skin)
	local SWRT_SKIN=$(nvram get swrt_skin)
	local TS_FLAG=$(grep -o "2ED9C3" /www/css/difference.css 2>/dev/null|head -n1)
	local ROG_FLAG=$(cat /www/form_style.css|grep -A1 ".tab_NW:hover{"|grep "background"|grep -o "2071044")
	local TUF_FLAG=$(cat /www/form_style.css|grep -A1 ".tab_NW:hover{"|grep "background"|grep -o "D0982C")
	if [ -n "${SWRT_SKIN}" ];then
		if [ "ts" == "${SWRT_SKIN}" ];then
			UI_TYPE="TS"
		elif [ "rog" == "${SWRT_SKIN}" ];then
			UI_TYPE="ROG"
		elif [ "tuf" == "${SWRT_SKIN}" ];then
			UI_TYPE="TUF"
		elif [ "swrt" == "${SWRT_SKIN}" ];then
			UI_TYPE="SWRT"
		fi
	elif [ -n "${TS_FLAG}" ];then
		UI_TYPE="TS"
	elif [ -n "${ROG_FLAG}" ];then
		UI_TYPE="ROG"
	elif [ -n "${TUF_FLAG}" ];then
		UI_TYPE="TUF"
	fi
	if [ -z "${SC_SKIN}" -o "${SC_SKIN}" != "${UI_TYPE}" ];then
		nvram set sc_skin="${UI_TYPE}"
		nvram commit
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "Magic Catling2：https://github.com/zusterben/plan_c"
			echo_date "你的固件平台不能安装！！!"
			echo_date "退出安装！"
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 1
			;;
		2)
			echo_date "Magic Catling2 升级/安装失败！！！"
			echo_date "退出安装！"
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 2
			;;
		0|*)
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 0
			;;
	esac
}
dbus_nset(){
	# set key when value not exist
	local ret=$(dbus get $1)
	if [ -z "${ret}" ];then
		dbus set $1=$2
	fi
}

install_now(){
	mkdir -p /jffs/softcenter/merlinclash
	mkdir -p /tmp/upload
	sleep 2s
	# 先关闭clash
	if [ "${merlinclash_enable}" == "1" ];then
		if [ -f "/jffs/softcenter/scripts/clash_config.sh" ] ;then
			echo_date "正在关闭Magic Catling插件，保证文件更新成功"
			sleep 1
			sh /jffs/softcenter/scripts/clash_config.sh stop stop >/dev/null 2>&1
			sleep 1
		else	
			echo_date ""
			echo_date "======================  ！！异常退出！！ ==========================="
			echo_date ""
			echo_date "         +++++++++++++++++++++++++++++++++++++++++++++++++"
			echo_date "         +    请先关闭Magic Catling插件，保证文件更新成功!     +" 
			echo_date "         +++++++++++++++++++++++++++++++++++++++++++++++++"
			exit_install 2
		fi

    fi

	echo_date "清理旧文件"
	rm -rf /jffs/softcenter/merlinclash/shanghai >/dev/null 2>&1
	rm -rf /jffs/softcenter/merlinclash/version
	rm -rf /jffs/softcenter/merlinclash/dashboard/
	rm -rf /jffs/softcenter/bin/clash
	rm -rf /jffs/softcenter/bin/yq
	rm -rf /jffs/softcenter/res/icon-merlinclash.png
	rm -rf /jffs/softcenter/res/clash*
	rm -rf /jffs/softcenter/res/merlinclash.css
	rm -rf /jffs/softcenter/res/mc-tablednd.js
	rm -rf /jffs/softcenter/res/mc-menu.js
	rm -rf /jffs/softcenter/res/china*.ipset >/dev/null 2>&1
	rm -rf /jffs/softcenter/res/lan*.ipset >/dev/null 2>&1
	rm -rf /jffs/softcenter/res/ip*.ipset >/dev/null 2>&1
	rm -rf /jffs/softcenter/res/mac*.ipset >/dev/null 2>&1
	rm -rf /tmp/upload/clash_* >/dev/null 2>&1
	find /jffs/softcenter/init.d/ -name "*merlinclash*" | xargs rm -rf
	rm -rf /jffs/softcenter/merlinclash/rule_configs
	rm -rf /jffs/softcenter/merlinclash/conf
	rm -rf /jffs/softcenter/webs/Module_merlinclash*
	rm -rf /jffs/softcenter/scripts/clash*

	SPACE_GEO=$(df | grep -w "/jffs$" | awk '{print $4}')
	if [ "$SPACE_GEO" -gt "30000" ];then
		echo_date "当前jffs分区剩余空间足够，保留Geo数据库文件！"
	else
		echo_date "当前jffs分区剩余空间紧张，为保证升级顺利"
		echo_date "删除Geo数据库文件，有需要的请升级成功后重新下载！"
		rm -rf /jffs/softcenter/merlinclash/GeoSite.dat >/dev/null 2>&1
		rm -rf /jffs/softcenter/merlinclash/GeoIP.dat >/dev/null 2>&1
	fi

	# 检测储存空间是否足够
	echo_date "检测jffs分区剩余空间..."
	SPACE_AVAL=$(df | grep -w "/jffs$" | awk '{print $4}')
	SPACE_NEED=$(du -s /tmp/merlinclash | awk '{print $1}')
	if [ "$SPACE_AVAL" -gt "$SPACE_NEED" ];then
		echo_date "当前jffs分区剩余${SPACE_AVAL}KB, 插件安装大概需要${SPACE_NEED}KB，空间满足，继续安装！"
	elif [ "$(nvram get sc_mount)" == "1" ];then
		echo_date "U盘已挂载, 插件安装大概需要${SPACE_NEED}KB，空间满足，继续安装！"
	else
		if [ "${mcinstall}" == "1" ]; then
			echo_date ""
			echo_date "======================  ！！异常退出！！ ==========================="
			echo_date ""
			echo_date "当前jffs分区剩余${SPACE_AVAL}KB, 插件安装大概需要${SPACE_NEED}KB，空间不足！"
			echo_date "         ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo_date "         +           注意：安装脚本已删除插件部分重要文件           +" 
			echo_date "         +   请清理JFFS空间重新安装，或者卸载Magic Catling2全新安装   +" 
			echo_date "         +        ！！！否则无法正常启动Magic Catling2！！！         +" 
			echo_date "         ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			sleep 5
			exit_install 2
		else
			echo_date "当前jffs分区剩余${SPACE_AVAL}KB, 插件安装大概需要${SPACE_NEED}KB，空间不足！"
			exit_install 2
		fi
	fi

	# 开始安装
	cd /jffs/softcenter/merlinclash && mkdir -p dashboard && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_basic && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_dns && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_bak && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_use && cd
	cd /jffs/softcenter/merlinclash && mkdir -p rule_configs && cd
	cd /jffs/softcenter/merlinclash && mkdir -p conf && cd

	echo_date "开始复制文件..."	
	cd /tmp
	cp -rf /tmp/merlinclash/bin/* /jffs/softcenter/bin/
	cp -rf /tmp/merlinclash/conf/* /jffs/softcenter/merlinclash/conf/
	cp -rf /tmp/merlinclash/version /jffs/softcenter/merlinclash/

	if [ "${mcinstall}" == "1" ]; then
		echo_date "----------------------------------------------------------------"
		echo_date "检测到早期版本的Magic Catling，开始进行升级安装..."
		echo_date "若升级后使用异常，请完全卸载插件，重新进行全新安装！！！"
		echo_date "----------------------------------------------------------------"

		rm -rf /tmp/merlinclash/yaml_basic/hosts.yaml
		rm -rf /tmp/merlinclash/yaml_basic/head.yaml

	fi
	cp -rf /tmp/merlinclash/yaml_basic/* /jffs/softcenter/merlinclash/yaml_basic/
	
	if [ "${mcinstall}" != "1" ]; then
		cp -rf /tmp/merlinclash/yaml_dns/* /jffs/softcenter/merlinclash/yaml_dns/
	fi
	cp -rf /tmp/merlinclash/dashboard/* /jffs/softcenter/merlinclash/dashboard/
	  cp -rf /tmp/merlinclash/rule_configs/* /jffs/softcenter/merlinclash/rule_configs/
	#判断是否需要覆盖GeoSite  
	geo_size=$(ls -l "$Geosite_PATH" 2>/dev/null | awk '{print $5}')
	geoip_size=$(ls -l "$GeoIP_PATH" 2>/dev/null | awk '{print $5}')
	if [ -f "$Geosite_PATH" ] && [ "$geo_size" -gt 1000000 ]; then
		echo_date "已经存在GeoSite.dat文件，略过"
	else
		cp -rf /tmp/merlinclash/clash/GeoSite.dat /jffs/softcenter/merlinclash/
	fi
	if [ -f "$GeoIP_PATH" ] && [ "$geoip_size" -gt 1000000 ]; then
		echo_date "已经存在GeoIP.dat文件，略过"
	else
		cp -rf /tmp/merlinclash/clash/GeoIP.dat /jffs/softcenter/merlinclash/
	fi

	echo_date "复制相关脚本文件..."	
	cp -rf /tmp/merlinclash/scripts/* /jffs/softcenter/scripts/
	cp -rf /tmp/merlinclash/install.sh /jffs/softcenter/scripts/merlinclash_install.sh
	cp -rf /tmp/merlinclash/uninstall.sh /jffs/softcenter/scripts/uninstall_merlinclash.sh

	echo_date "复制相关网页文件..."	
	cp -rf /tmp/merlinclash/webs/* /jffs/softcenter/webs/
	cp -rf /tmp/merlinclash/res/* /jffs/softcenter/res/
		
	echo_date "为新文件赋权..."	
	chmod 755 /jffs/softcenter/bin/clash
	chmod 755 /jffs/softcenter/bin/yq
	chmod 755 /jffs/softcenter/merlinclash/yaml_basic/*
	chmod 755 /jffs/softcenter/merlinclash/yaml_dns/*
	chmod 755 /jffs/softcenter/merlinclash/conf/*
	chmod 755 /jffs/softcenter/merlinclash/rule_configs/*
	chmod 755 /jffs/softcenter/merlinclash/*
	chmod 755 /jffs/softcenter/scripts/clash*


	echo_date "创建自启脚本软链接！"
	[ ! -L "/jffs/softcenter/init.d/S150merlinclash.sh" ]  && ln -sf /jffs/softcenter/scripts/clash_config.sh /jffs/softcenter/init.d/S150merlinclash.sh
	[ ! -L "/jffs/softcenter/init.d/N150merlinclash.sh" ]  && ln -sf /jffs/softcenter/scripts/clash_config.sh /jffs/softcenter/init.d/N150merlinclash.sh

	echo_date "数据初始化"
	dbus_nset merlinclash_set_mixport_sw "0"
	dbus_nset merlinclash_ipt_closeproxy_sw "0"
	dbus_nset merlinclash_sub_useragent "bWlob21vLzEuMTkuMjA="
	dbus_nset merlinclash_set_logcheck_val "40"
	dbus_nset merlinclash_dns_sniffer_sw "1"
	dbus_nset merlinclash_sub_links " "
	dbus_nset merlinclash_dns_cleardns_sw "1"
	dbus_nset merlinclash_ipt_tproxy_type "closed"
	dbus_nset merlinclash_ipt_ipv6_sw "0"
	dbus_nset merlinclash_dns_proxydns_sw "1"
	dbus_nset merlinclash_dns_dnshijack_sw "1"
    #判断是否需要开启队列请求
	if [ "${builddate}" -lt "2025" ]; then
		dbus_nset merlinclash_set_queue_sw "1"
	else
		dbus_nset merlinclash_set_queue_sw "0"
	fi
	#判断是否开启大陆绕行IP
#	if [ "${LINUX_VER}" -le "41" ] || [ "${LINUX_VER}" -eq "44" ]; then
		dbus_nset merlinclash_set_chnroute_sw "1"
#	else
#		dbus_nset merlinclash_set_chnroute_sw "0"
#	fi
	#提取默认密码
	secret=$(yq eval ".secret" "/jffs/softcenter/merlinclash/yaml_basic/head.yaml" 2>/dev/null)
	dbus_nset merlinclash_set_dashboard_password "$secret"
	dbus set merlinclash_linuxver="$LINUX_VER"
	#设置版本号
	CUR_VERSION=$(cat /jffs/softcenter/merlinclash/version)
	dbus set merlinclash_version="$CUR_VERSION"
	dbus set softcenter_module_merlinclash_install="1"
	dbus set softcenter_module_merlinclash_version="$CUR_VERSION"
	dbus set softcenter_module_merlinclash_title="Magic Catling2"
	dbus set softcenter_module_merlinclash_description="Magic Catling2:一个基于规则的代理程序，支持多种协议~" 
	#设置内核版本
	local ret=$(env -i PATH=${PATH} /jffs/softcenter/bin/clash -v 2>/dev/null | head -n 1)
	local clashTmpV1=$(echo "$ret" | cut -d " " -f2)
	local clashTmpV2=$(echo "$ret" | cut -d " " -f3)
	if [ "$clashTmpV1" = "Meta" ];then
		merlinclash_binary_ver_tmp="Mihomo $clashTmpV2"; 
	else
		merlinclash_binary_ver_tmp=$clashTmpV1
	fi

	if [ -n "$merlinclash_binary_ver_tmp" ]; then
		mcv="$merlinclash_binary_ver_tmp"		
	else
		mcv="null"
	fi
	dbus set merlinclash_binary_ver="$mcv"

	echo_date "Magic Catling2插件安装成功！"
	#yaml不为空则复制文件 然后生成yamls.txt
	dir=/jffs/softcenter/merlinclash/yaml_bak
	a=$(ls $dir | wc -l)
	if [ $a -gt 0 ]; then
		cp -rf /jffs/softcenter/merlinclash/yaml_bak/*.yaml  /jffs/softcenter/merlinclash/yaml_use/ >/dev/null 2>&1
	fi
		
	#生成新的txt文件
	rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt >/dev/null 2>&1
	echo_date "初始化yaml文件列表"
	find /jffs/softcenter/merlinclash/yaml_bak -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
	
	echo_date "初始化配置文件处理完成"

	# intall different UI
	set_skin

}
install(){
	get_model
	platform_test
	fuck_bug
	install_now
}

install


