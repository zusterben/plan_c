#! /bin/sh

source /jffs/softcenter/scripts/base.sh
eval $(dbus export merlinclash)
#alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
MODEL=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
mcinstall=$(dbus get softcenter_module_merlinclash_install)
me=$(dbus get merlinclash_enable)

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

platform_test(){
	local firmware_version=`dbus get softcenter_firmware_version`
	if [ ! -d "/jffs/softcenter" ];then
		echo_date "机型：${MODEL} $(nvram get firmver)_$(nvram get buildno)_$(nvram get extendno) 不符合安装要求，无法安装插件！"
		exit_install 1
	fi
	if [ "$(/jffs/softcenter/bin/versioncmp $firmware_version 5.1.2)" == "1" ];then
		echo_date "1.5代api最低固件版本为5.1.2,固件版本过低，无法安装"
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
	local ROG_FLAG=$(grep -o "680516" /www/form_style.css 2>/dev/null|head -n1)
	local TUF_FLAG=$(grep -o "D0982C" /www/form_style.css 2>/dev/null|head -n1)
	local TS_FLAG=$(grep -o "2ED9C3" /www/css/difference.css 2>/dev/null|head -n1)
	if [ -n "${ROG_FLAG}" ];then
		UI_TYPE="ROG"
	fi
	if [ -n "${TUF_FLAG}" ];then
		UI_TYPE="TUF"
	fi
	if [ -n "${TS_FLAG}" ];then
		UI_TYPE="TS"
	fi

	if [ -z "${SC_SKIN}" -o "${SC_SKIN}" != "${UI_TYPE}" ];then
		echo_date "安装${UI_TYPE}皮肤！"
		nvram set sc_skin="${UI_TYPE}"
		nvram commit
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "merlinclash项目地址：https://github.com/zusterben/plan_c"
			echo_date "你的固件平台不能安装！！!"
			echo_date "退出安装！"
			rm -rf /tmp/merlinclash* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/merlinclash* >/dev/null 2>&1
			exit 0
			;;
	esac
}

install_now(){
	mkdir -p /jffs/softcenter/merlinclash
	sleep 2s
	# 先关闭clash
	if [ "$me" == "1" ];then
		echo_date ""
		echo_date "======================  ！！异常退出！！ ==========================="
		echo_date ""
		echo_date "         +++++++++++++++++++++++++++++++++++++++++++++++++"
		echo_date "         +    请先关闭Merlin Clash插件，保证文件更新成功!     +" 
		echo_date "         +++++++++++++++++++++++++++++++++++++++++++++++++"
		echo_date "退出安装！"
		sleep 5
		echo "XU6J03M6"
		#[ -f "/jffs/softcenter/merlinclash/clashconfig.sh" ] && sh /jffs/softcenter/merlinclash/clashconfig.sh stop
		exit_install 0
	fi
  
	echo_date "清理旧文件"
	rm -rf /jffs/softcenter/merlinclash/Country.mmdb
	SPACE_GEO=$(df | grep -w "/jffs$" | awk '{print $4}')
	if [ "$SPACE_GEO" -gt "30000" ];then
		echo_date "当前jffs分区剩余空间足够，保留GeoSite文件！"
	else
		echo_date "当前jffs分区剩余空间紧张，为保证升级顺利"
		echo_date "删除GeoSite文件，有需要的请升级成功后重新下载！"
		rm -rf /jffs/softcenter/merlinclash/GeoSite.dat
	fi
	rm -rf /jffs/softcenter/merlinclash/clashconfig.sh
	rm -rf /jffs/softcenter/merlinclash/version
	#rm -rf /jffs/softcenter/merlinclash/yaml_basic/
	#rm -rf /jffs/softcenter/merlinclash/yaml_dns/
	rm -rf /jffs/softcenter/merlinclash/dashboard/
	rm -rf /jffs/softcenter/bin/clash
	rm -rf /jffs/softcenter/bin/yq
	rm -rf /jffs/softcenter/bin/yq
	rm -rf /jffs/softcenter/bin/mc_dns2socks
	rm -rf /jffs/softcenter/res/icon-merlinclash.png
	rm -rf /jffs/softcenter/res/clash-dingyue.png
	rm -rf /jffs/softcenter/res/clash-kcp.jpg
	rm -rf /jffs/softcenter/res/clash*
	rm -rf /jffs/softcenter/res/merlinclash.css
	rm -rf /jffs/softcenter/res/mc-tablednd.js
	rm -rf /jffs/softcenter/res/mc-menu.js
	rm -rf /jffs/softcenter/res/china_ip_route.ipset
	rm -rf /jffs/softcenter/res/china_ip_route6.ipset
	rm -rf /tmp/upload/dns_redirhost.txt
	rm -rf /tmp/upload/dns_fakeip.txt
	find /jffs/softcenter/init.d/ -name "*merlinclash*" | xargs rm -rf
	#------subconverter--------
	rm -rf /jffs/softcenter/bin/subconverter
	rm -rf /jffs/softcenter/merlinclash/subconverter/subconverter
	rm -rf /jffs/softcenter/merlinclash/subconverter/rules/ACL4SSR/
	#------subconverter--------
	rm -rf /jffs/softcenter/merlinclash/conf
	#------koolproxy--------
	rm -rf /jffs/softcenter/bin/koolproxy
	rm -rf /jffs/softcenter/merlinclash/koolproxy
	#------koolproxy--------
	#rm -rf /tmp/upload/*.yaml
	rm -rf /jffs/softcenter/webs/Module_merlinclash*
	rm -rf /jffs/softcenter/res/icon-merlinclash.png
	rm -rf /jffs/softcenter/res/clash-kcp.jpg
	rm -rf /jffs/softcenter/res/clash*
	rm -rf /jffs/softcenter/res/china_ip_route.ipset
	rm -rf /jffs/softcenter/res/china_ip_route6.ipset
	#
	rm -rf /jffs/softcenter/scripts/clash*

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
			echo_date "         +   请清理JFFS空间重新安装，或者卸载Merlin Clash全新安装   +" 
			echo_date "         +        ！！！否则无法正常启动Merlin Clash！！！         +" 
			echo_date "         ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo_date "退出安装！"
			sleep 5
			echo "XU6J03M6"
			exit_install 0
	    else
	    	echo_date "当前jffs分区剩余${SPACE_AVAL}KB, 插件安装大概需要${SPACE_NEED}KB，空间不足！"
			echo_date "退出安装！"
			exit 1
	    fi
	fi

	# 开始安装
	cd /jffs/softcenter/merlinclash && mkdir -p dashboard && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_basic && cd
	cd /jffs/softcenter/merlinclash/yaml_basic && mkdir -p host && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_dns && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_bak && cd
	cd /jffs/softcenter/merlinclash && mkdir -p yaml_use && cd
	cd /jffs/softcenter/merlinclash && mkdir -p rule_bak && cd
	cd /jffs/softcenter/merlinclash && mkdir -p subconverter && cd
	cd /jffs/softcenter/merlinclash && mkdir -p conf && cd
	cd /jffs/softcenter/merlinclash && mkdir -p koolproxy && cd

	echo_date "开始复制文件..."	
	cd /tmp
	cp -rf /tmp/merlinclash/bin/clash /jffs/softcenter/bin/
	#subconverter
	cp -rf /tmp/merlinclash/bin/subconverter /jffs/softcenter/merlinclash/subconverter/
	cp -rf /tmp/merlinclash/subconverter/* /jffs/softcenter/merlinclash/subconverter/
	[ ! -L "/jffs/softcenter/bin/subconverter" ] && ln -sf /jffs/softcenter/merlinclash/subconverter/subconverter /jffs/softcenter/bin/subconverter	

	#koolproxy
	#cp -rf /tmp/merlinclash/bin/koolproxy /jffs/softcenter/merlinclash/koolproxy/
	#cp -rf /tmp/merlinclash/koolproxy/* /jffs/softcenter/merlinclash/koolproxy/
		
	cp -rf /tmp/merlinclash/conf/* /jffs/softcenter/merlinclash/conf/
	cp -rf /tmp/merlinclash/clash/Country.mmdb /jffs/softcenter/merlinclash/
	cp -rf /tmp/merlinclash/clash/clashconfig.sh /jffs/softcenter/merlinclash/
	cp -rf /tmp/merlinclash/version /jffs/softcenter/merlinclash/

	if [ "${mcinstall}" == "1" ]; then
	  rm -rf /tmp/merlinclash/yaml_basic/host
	  echo_date "----------------------------------------------------------------"
	  echo_date "检测到早期版本的Merlin Clash，开始进行升级安装..."
	  echo_date "若升级后使用异常，请完全卸载插件，重新进行全新安装！！！"
	  echo_date "----------------------------------------------------------------"
  fi
  cp -rf /tmp/merlinclash/yaml_basic/* /jffs/softcenter/merlinclash/yaml_basic/
	
  if [ "${mcinstall}" != "1" ]; then
	  cp -rf /tmp/merlinclash/yaml_dns/* /jffs/softcenter/merlinclash/yaml_dns/
  fi
	cp -rf /tmp/merlinclash/dashboard/* /jffs/softcenter/merlinclash/dashboard/

	echo_date "复制相关脚本文件..."	
	cp -rf /tmp/merlinclash/scripts/* /jffs/softcenter/scripts/
	cp -rf /tmp/merlinclash/install.sh /jffs/softcenter/scripts/merlinclash_install.sh
	cp -rf /tmp/merlinclash/uninstall.sh /jffs/softcenter/scripts/uninstall_merlinclash.sh

	echo_date "复制相关网页文件..."	
	cp -rf /tmp/merlinclash/webs/* /jffs/softcenter/webs/
	cp -rf /tmp/merlinclash/res/* /jffs/softcenter/res/
		
	echo_date "为新文件赋权..."	
	chmod 755 /jffs/softcenter/bin/clash
	chmod 755 /jffs/softcenter/merlinclash/Country.mmdb
	chmod 755 /jffs/softcenter/merlinclash/yaml_basic/*
	chmod 755 /jffs/softcenter/merlinclash/yaml_dns/*
	chmod 755 /jffs/softcenter/merlinclash/subconverter/*
	chmod 755 /jffs/softcenter/merlinclash/conf/*
	#chmod 755 /jffs/softcenter/merlinclash/koolproxy/*
	chmod 755 /jffs/softcenter/merlinclash/*
	chmod 755 /jffs/softcenter/scripts/clash*


	echo_date "创建自启脚本软链接！"
	[ ! -L "/jffs/softcenter/init.d/S150merlinclash.sh" ]  && ln -sf /jffs/softcenter/scripts/clash_config.sh /jffs/softcenter/init.d/S150merlinclash.sh
	[ ! -L "/jffs/softcenter/init.d/N150merlinclash.sh" ]  && ln -sf /jffs/softcenter/scripts/clash_config.sh /jffs/softcenter/init.d/N150merlinclash.sh

	echo_date "创建dns文件软链接！"
	[ ! -L "/tmp/upload/dns_redirhost.txt" ] && ln -sf /jffs/softcenter/merlinclash/yaml_dns/redirhost.yaml /tmp/upload/dns_redirhost.txt
	[ ! -L "/tmp/upload/dns_fakeip.txt" ] && ln -sf /jffs/softcenter/merlinclash/yaml_dns/fakeip.yaml /tmp/upload/dns_fakeip.txt
		
	echo_date "数据初始化"
	dbus set merlinclash_dc_name=" "
	dbus set merlinclash_dc_passwd=" "
	dbus set merlinclash_scrule_version="2024071201"
	dbus set merlinclash_iptablessel="fangan1"
	dbus set merlinclash_flag="HND"
	dbus set merlinclash_linuxver="$LINUX_VER"
	dbus set merlinclash_check_delay_time="40"
	dbus set merlinclash_d2s="0"
	dbus set merlinclash_check_kp=0		#护网大师
	if [ "${mcinstall}" != "1" ]; then
		dbus set merlinclash_dnsedit_tag="redirhost"
		dbus set merlinclash_bypassmode="1"
		dbus set merlinclash_kpacl_default_mode="1"
		dbus set merlinclash_mark_MD51=""
		dbus set merlinclash_check_clashimport=1 #导入CLASH
		dbus set merlinclash_check_sclocal=1	#SUBC/ACL转换
		dbus set merlinclash_check_ssimport=0	#导入科学节点
		dbus set merlinclash_check_upcusrule=0	#上传自定订阅
		dbus set merlinclash_check_xiaobai=1	#小白一键订阅
		dbus set merlinclash_check_yamldown=1 #YAML下载
		dbus set merlinclash_check_kcp=0	#KCP加速
  	
		dbus set merlinclash_check_noipt=0 	#透明代理
		dbus set merlinclash_check_aclrule=0 	#自定规则
		dbus set merlinclash_check_cdns=0 	#DNS编辑区
		dbus set merlinclash_check_cdns=0 	#HOST编辑区
		dbus set merlinclash_check_scriptedit=0 	#script编辑区
		dbus set merlinclash_check_ipsetproxy=0 	#转发clash
		dbus set merlinclash_check_ipsetproxyarround=0 	#绕过clash
		dbus set merlinclash_check_controllist=0 	#黑白郎君
		dbus set merlinclash_check_cusport=0 	#自定义端口
		dbus set merlinclash_check_dlercloud=0 	#DC用户
		dbus set merlinclash_check_tproxy=0 	#TPROXY
		dbus set merlinclash_check_unblock=0 	#云村解锁
		dbus set merlinclash_cirswitch=1 #大陆绕行IP 强制打开
		dbus set merlinclash_check_notice_show=1 #通知广告区		
		dbus set merlinclash_links=" "
		dbus set merlinclash_links2=" "
		dbus set merlinclash_links3=" "
		dbus set merlinclash_dnsclear="1"
		dbus set merlinclash_tproxymode="closed"
		dbus set merlinclash_ipv6switch="0"
		dbus set merlinclash_hostsel="default"
		#提取配置认证码
		secret=$(cat /jffs/softcenter/merlinclash/yaml_basic/head.yaml | awk '/secret:/{print $2}' | sed 's/"//g')
		dbus set merlinclash_dashboard_secret="$secret"
	fi

	CUR_VERSION=$(cat /jffs/softcenter/merlinclash/version)
	#[ ! -L "/jffs/softcenter/bin/koolproxy" ] && ln -sf /jffs/softcenter/merlinclash/koolproxy/koolproxy /jffs/softcenter/bin/koolproxy	
	#kpversion="$(/jffs/softcenter/merlinclash/koolproxy/koolproxy -v)"
	#if [ -n "$kpversion" ]; then
	#	kpv="$kpversion"		
	#else
	#	kpv="null"
	#fi
	dbus set merlinclash_koolproxy_version="3.8.5"
	dbus set merlinclash_version_local="$CUR_VERSION"
	dbus set merlinclash_patch_version="000"
	dbus set softcenter_module_merlinclash_install="1"
	dbus set softcenter_module_merlinclash_version="$CUR_VERSION"
	dbus set softcenter_module_merlinclash_title="Merlin Clash"
	dbus set softcenter_module_merlinclash_description="Merlin Clash:一个基于规则的代理程序，支持多种协议~" 
	local ret=$(env -i PATH=${PATH} /jffs/softcenter/bin/clash -v 2>/dev/null | head -n 1)
	local clashTmpV1=$(echo "$ret" | cut -d " " -f2)
	local clashTmpV2=$(echo "$ret" | cut -d " " -f3)
    if [ "$clashTmpV1" = "Meta" ];then
	    merlinclash_clash_version_tmp="$clashTmpV1 $clashTmpV2"; 
    else
		merlinclash_clash_version_tmp=$clashTmpV1
    fi

    if [ -n "$merlinclash_clash_version_tmp" ]; then
	    mcv="$merlinclash_clash_version_tmp"		
    else
	    mcv="null"
    fi
	dbus set merlinclash_clash_version="$mcv"

	echo_date "一点点清理工作..."
	rm -rf /tmp/clash* >/dev/null 2>&1

	echo_date "Merlin Clash插件安装成功！"
	#yaml不为空则复制文件 然后生成yamls.txt
	dir=/jffs/softcenter/merlinclash/yaml_bak
	a=$(ls $dir | wc -l)
	if [ $a -gt 0 ]; then
			cp -rf /jffs/softcenter/merlinclash/yaml_bak/*.yaml  /jffs/softcenter/merlinclash/yaml_use/
	fi
		
	#生成新的txt文件
	rm -rf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	echo_date "初始化yaml文件列表"
	find /jffs/softcenter/merlinclash/yaml_bak  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_bak/yamls.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_bak/yamls.txt /tmp/upload/yamls.txt
	#
	echo_date "初始化host文件列表"
	find /jffs/softcenter/merlinclash/yaml_basic/host  -name "*.yaml" |sed 's#.*/##' |sed '/^$/d' | awk -F'.' '{print $1}' > /jffs/softcenter/merlinclash/yaml_basic/host/hosts.txt
	#创建软链接
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/host/hosts.txt /tmp/upload/hosts.txt
	ln -sf /jffs/softcenter/merlinclash/yaml_basic/sniffer.yaml /tmp/upload/clash_sniffercontent.txt
	
	echo_date "初始化配置文件处理完成"

	# intall different UI
	set_skin

}
install(){
	get_model
	platform_test
	install_now
}

install

