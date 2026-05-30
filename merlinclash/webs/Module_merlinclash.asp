	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">
	<html xmlns:v>
	<head>
		<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
		<meta HTTP-EQUIV="Expires" CONTENT="-1">
		<link rel="shortcut icon" href="images/favicon.png">
		<link rel="icon" href="images/favicon.png">
		<title>【Magic Catling 2】</title>
		<link rel="stylesheet" type="text/css" href="index_style.css">
		<link rel="stylesheet" type="text/css" href="form_style.css">
		<link rel="stylesheet" type="text/css" href="usp_style.css">
		<link rel="stylesheet" type="text/css" href="css/element.css">
		<link rel="stylesheet" type="text/css" href="/device-map/device-map.css">
		<link rel="stylesheet" type="text/css" href="/js/table/table.css">
		<link rel="stylesheet" type="text/css" href="/res/layer/theme/default/layer.css">
		<link rel="stylesheet" type="text/css" href="/res/softcenter.css">
		<link rel="stylesheet" type="text/css" href="/res/merlinclash.css">
		<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
		<script language="JavaScript" type="text/javascript" src="/res/layer/layer.js"></script>
		<script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
		<script language="JavaScript" type="text/javascript" src="/state.js"></script>
		<script language="JavaScript" type="text/javascript" src="/general.js"></script>
		<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
		<script language="JavaScript" type="text/javascript" src="/help.js"></script>
		<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
		<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
		<script language="JavaScript" type="text/javascript" src="/js/table/table.js"></script>
		<script language="JavaScript" type="text/javascript" src="/res/mc-menu.js"></script>
		<script language="JavaScript" type="text/javascript" src="/res/softcenter.js"></script>
		<script>
			// 全局变量声明
			var db_merlinclash = {};
			var db_merlinclash_tmp = {};
			var _responseLen;
			var x = 5;
			var noChange = 0;
			var node_max = 0;
			var acl_node_max = 0;
			var nokpacl_node_max = 0;
			var log_count = 0;
			var select_count = 0;
			var yamlview_count = 0;
			var init_count = 0;
			var init_hostcount = 0;
			var init_nokpaclcount = 0;
			var init_aclcount = 0;
			var init_advancedcount = 0;
			var init_unblockcount = 0;
			var init_circount = 0;
			var init_cusrulecount = 0;
			var requestList = [];
			var queue_switch = true; // 默认进队列

			// 初始化函数
			function init() {
				show_menu(menu_hook);
				set_skin();
				// 初始化获取Dbus值
				get_dbus_data();
				// 处理请求
				doRequest();
			}

			//队列处理请求，防止并发请求过多
		async function doRequest() {
			var i = 0;
			var isRequest = false;
			
			for (i = 0; i < requestList.length; i++) {
				var ajaxConfig = requestList[i];

				// 判断是否需要显示加载遮罩
				var shouldShowMask = (!ajaxConfig.data || 
					typeof ajaxConfig.data !== 'string' || 
					!ajaxConfig.data.includes('clash_status')) && 
				!ajaxConfig.url.includes('log');
				
				if (shouldShowMask) {
					$("#loadingMask").show();
				}

				try {
					await $.ajax(ajaxConfig);
				} catch (e) {
					console.log('捕获到异常啦', e);
				}
				
				// 移出队列
				requestList.splice(i, 1);
				isRequest = true;
			}

			if (isRequest) {
				console.log('请求队列处理完了~');
				$("#loadingMask").hide();
			}

			setTimeout('doRequest();', 50); // 写入定时器
		}

		//请求加入队列
		 function intoQueue(ajaxConfig) {
			// 只有请求路由器的才进队列
			if (ajaxConfig.url.startsWith('/')) {
				if (queue_switch) {
					requestList.push(ajaxConfig);
				} else {
					$.ajax(ajaxConfig);
				}
			} else {
				$.ajax(ajaxConfig);
			}
		}



	// 初始化表单数据
	function initializeFormData() {
		// 复选框字段列表
		const checkboxFields = [
		"merlinclash_enable", "merlinclash_set_watchdog_sw", "merlinclash_set_chnroute_sw", 
		"merlinclash_set_recordbycron_sw", "merlinclash_ipt_proxyrouter_sw","merlinclash_ipt_proxyiot_sw","merlinclash_dns_proxydns_sw",
		"merlinclash_dns_cleardns_sw", "merlinclash_set_mixport_sw", "merlinclash_dns_sniffer_sw","merlinclash_dns_dnshijack_sw",
		"merlinclash_set_tcpcon_sw", "merlinclash_ipt_closeproxy_sw", 
		"merlinclash_set_logcheck_sw", "merlinclash_set_startdelay_sw",
		"merlinclash_set_tolerance_sw", "merlinclash_set_interval_sw",
		"merlinclash_bak_set", "merlinclash_bak_yaml", "merlinclash_bak_rule", "merlinclash_bak_dns",  "merlinclash_bak_db","merlinclash_bak_acl"
		];

		// 批量设置复选框
		checkboxFields.forEach(field => {
			const element = E(field);
			if (element) {
				element.checked = db_merlinclash[field] == "1";
			}
		});

		// 特殊处理IPv6开关
		E("merlinclash_ipt_ipv6_sw").checked = db_merlinclash["merlinclash_ipt_ipv6_sw"] == "1";

		// 特殊处理队列开关
		if (db_merlinclash["merlinclash_set_queue_sw"] === undefined) {
			E("merlinclash_set_queue_sw").checked = true;
		} else {
			queue_switch = db_merlinclash["merlinclash_set_queue_sw"] == "1";
			E("merlinclash_set_queue_sw").checked = queue_switch;
		}

		// 初始化输入字段
		const inputFields = [
		{ field: "merlinclash_dns_fakeip_server", decode: false },
		{ field: "merlinclash_set_tolerance_val", decode: false },
		{ field: "merlinclash_set_interval_val", decode: false },
		{ field: "merlinclash_nokpacl_method", decode: false },
		{ field: "merlinclash_sub_links", decode: true },
		{ field: "merlinclash_set_dashboard_password", decode: false },
		{ field: "merlinclash_sub_useragent", decode: true },
		{ field: "merlinclash_sub_include", decode: true },
		{ field: "merlinclash_sub_exclude", decode: true },
		{ field: "merlinclash_set_logcheck_val", decode: false },
		// { field: "merlinclash_ipt_routingmark_val", decode: false },
		{ field: "merlinclash_set_startdelay_val", decode: false },
		];

		inputFields.forEach(({ field, decode }) => {
			if (db_merlinclash[field]) {
				let value = db_merlinclash[field];
				if (decode) {
					value = Base64.decode(value);
				}
				E(field).value = value;
			}
		});

		// 特殊处理的字段（需要Base64解码和URI解码）
		// const specialFields = [
		// { field: "merlinclash_uploadiniurl", decode: true, uriDecode: true }
		// ];

		// specialFields.forEach(({ field, decode, uriDecode }) => {
		// 	if (db_merlinclash[field]) {
		// 		let value = db_merlinclash[field];
		// 		if (decode) {
		// 			value = Base64.decode(value);
		// 		}
		// 		if (uriDecode) {
		// 			value = decodeURIComponent(value);
		// 		}
		// 		E(field).value = value;
		// 	}
		// });
	}

	// 初始化单选按钮
	function initializeRadioButtons() {
		const radioGroups = [
		{ name: "dnsplan", field: "merlinclash_dns_type" },
			// { name: "dnshijack", field: "merlinclash_dns_dnshijack_sw" },
			{ name: "cusruleplan", field: "merlinclash_acl_plan" }
			];

			radioGroups.forEach(group => {
				if (db_merlinclash[group.field]) {
					$(`input:radio[name='${group.name}'][value='${db_merlinclash[group.field]}']`).attr('checked', 'true');
				}
			});

		// 特殊处理tproxy模式
		if (db_merlinclash["merlinclash_ipt_tproxy_type"]) {
			$(`input:radio[name='tproxymode'][value='${db_merlinclash["merlinclash_ipt_tproxy_type"]}']`).attr('checked', 'true');
		}
	}

	// 初始化下拉选择框
	function initializeSelectOptions() {
		const selectFields = [
		"merlinclash_select_clash_restart", "merlinclash_select_clash_restart_day",
		"merlinclash_select_clash_restart_week", "merlinclash_select_clash_restart_hour",
		"merlinclash_select_clash_restart_minute", "merlinclash_select_clash_restart_minute_2",
		"merlinclash_set_geoip_type", "merlinclash_set_geosite_type"
		];

		selectFields.forEach(field => {
			if (db_merlinclash[field]) {
				$(`#${field}`).find(`option[value='${db_merlinclash[field]}']`).attr("selected", "selected");
			}
		});
	}

	// 处理版本特定功能
	function handleVersionSpecificFeatures() {
		const tproxyElements = ["tproxy"];
		
		tproxyElements.forEach(elementId => {
			const element = document.getElementById(elementId);
			if (element) {
				element.style.display = "";
			}
		});
	}

	// 处理条件显示
	function handleConditionalDisplay() {
		// 条件显示规则
		const displayRules = [
		{ condition: "merlinclash_enable", element: "merlinclash_restart" },
		{ condition: "merlinclash_set_mixport_sw", element: "ip_state" },
		// { condition: "merlinclash_ipt_proxyrouter_sw", element: "mark_value" },
		// 添加reverse标志,表示逻辑取反
		{ condition: "merlinclash_ipt_closeproxy_sw", element: "tproxy_seting", reverse: true }, 
		];

			displayRules.forEach(rule => {
				const element = document.getElementById(rule.element);
				if (element) {
				// 如果有reverse标志，则逻辑取反
				if (rule.reverse) {
					element.style.display = db_merlinclash[rule.condition] == "1" ? "none" : "";
				} else {
					element.style.display = db_merlinclash[rule.condition] == "1" ? "" : "none";
				}
			}
		});
		// 始终显示的元素
		const alwaysShowElements = [
		"showmsg6", "showmsg7", "showmsg8", "showmsg9", "showmsg10"
		];
		
		alwaysShowElements.forEach(elementId => {
			const element = document.getElementById(elementId);
			if (element) {
				element.style.display = "";
			}
		});

		// DNS FakeIP黑名单特殊处理
		const dnsFakeipElement = document.getElementById("dns_fakeipblack");
		if (dnsFakeipElement) {
			dnsFakeipElement.style.display = db_merlinclash["merlinclash_dns_type"] == "fi" ? "" : "none";
		}
		
		const ipv6Element = document.getElementById("clash_ipv6");
		if (ipv6Element) {
   			const proxyMode = db_merlinclash["merlinclash_ipt_tproxy_type"];
    	if (proxyMode === "closed" || proxyMode === "udp") {
        	ipv6Element.style.display = "none";
    	} else if (proxyMode === "tcp" || proxyMode === "tcpudp") {
        	ipv6Element.style.display = "";
    	}
		}

	}

	function get_dbus_data() {
		$.ajax({
			type: "GET",
			url: "/_api/merlinclash",
			dataType: "json",
			async: false,
			cache: false,
			success: function(data) {
				// 初始化DBUS数据
				db_merlinclash = data.result[0];

				// 定时作业下拉数据
				load_cron_params();

				// 开始处理数据
				initializeFormData();
				initializeRadioButtons();
				initializeSelectOptions();
				handleVersionSpecificFeatures();
				handleConditionalDisplay();

				// 复制数据到临时变量
				$.each(db_merlinclash, (k, v) => {
					db_merlinclash_tmp[k] = v;
				});

				if (E("merlinclash_enable").checked) {
					merlinclash.checkIP();
				}

				// 定时作业下拉切换显示
				show_job();
				// 版本检查
				version_show();
				// 栏目点击切换
				toggle_func();
				// 下拉框获取配置文件名
				yaml_select();
				// 获取相关状态
				get_clash_status_front();
				notice_show();
			}
		});
	}

	var yamlsel_tmp2;
	function selectlist_rebuild() {
		db_merlinclash["merlinclash_action"] = 34;
		push_data("clash_rebuild.sh", "rebuild",  db_merlinclash);
	}
	function hot_off_mc(){
		db_merlinclash["merlinclash_action"] = 42;
		push_data("clash_rebuild.sh", "hot_off_mc",  db_merlinclash);
	}
	function cool_off_mc(){
		layer.confirm('<li>路由器即将重启，你确定要冷关闭吗？</li>', {
			shade: 0.8,
		}, function(index) {
			$("#log_content3").attr("rows", "20");
			db_merlinclash["merlinclash_action"] = 43;
			push_data("clash_rebuild.sh", "cool_off_mc", db_merlinclash);
			layer.close(index);
			return true;

		}, function(index) {
			layer.close(index);
			return false;
		});
	}
	//启动按钮
	function apply() {

		if(!$.trim($('#merlinclash_dns_fakeip_server').val())){
			alert("黑名单设备DNS服务器不能为空！");
			E("merlinclash_enable").checked = false;
			return false;
		}
		if(!$.trim($('#merlinclash_set_yamlsel_start').val())){
			alert("必须选择一个配置文件！");
			E("merlinclash_enable").checked = false;
			return false;
		}
		var radio = document.getElementsByName("dnsplan").innerHTML = getradioval(1);
		var cusrulesel = document.getElementsByName("cusruleplan").innerHTML = getradioval(8);

		var tproxymodesel = document.getElementsByName("tproxymode").innerHTML = getradioval(4);
		// var dnshijacksel = document.getElementsByName("dnshijack").innerHTML = getradioval(7);
		db_merlinclash["merlinclash_enable"] = E("merlinclash_enable").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_watchdog_sw"] = E("merlinclash_set_watchdog_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_ipt_ipv6_sw"] = E("merlinclash_ipt_ipv6_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_chnroute_sw"] = E("merlinclash_set_chnroute_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_recordbycron_sw"] = E("merlinclash_set_recordbycron_sw").checked ? '1' : '0'; 
		db_merlinclash["merlinclash_dns_proxydns_sw"] = E("merlinclash_dns_proxydns_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_ipt_proxyrouter_sw"] = E("merlinclash_ipt_proxyrouter_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_ipt_proxyiot_sw"] = E("merlinclash_ipt_proxyiot_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_dns_cleardns_sw"] = E("merlinclash_dns_cleardns_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_dns_dnshijack_sw"] = E("merlinclash_dns_dnshijack_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_dns_sniffer_sw"] = E("merlinclash_dns_sniffer_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_tcpcon_sw"] = E("merlinclash_set_tcpcon_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_dns_fakeip_server"] = E("merlinclash_dns_fakeip_server").value;
		db_merlinclash["merlinclash_set_dashboard_password"] = E("merlinclash_set_dashboard_password").value;
		db_merlinclash["merlinclash_dns_type"] = radio;
		db_merlinclash["merlinclash_acl_plan"] = cusrulesel;
		db_merlinclash["merlinclash_ipt_tproxy_type"] = tproxymodesel;
		// db_merlinclash["merlinclash_dns_dnshijack_sw"] = dnshijacksel;
		db_merlinclash["merlinclash_sub_links"] = Base64.encode(E("merlinclash_sub_links").value);
		// //URL编码后再传入后端
		db_merlinclash["merlinclash_set_queue_sw"] = E("merlinclash_set_queue_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_logcheck_sw"] = E("merlinclash_set_logcheck_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_startdelay_sw"] = E("merlinclash_set_startdelay_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_tolerance_sw"] = E("merlinclash_set_tolerance_sw").checked ? '1' : '0';
		db_merlinclash["merlinclash_set_interval_sw"] = E("merlinclash_set_interval_sw").checked ? '1' : '0';
		if(E("merlinclash_set_logcheck_sw").checked){
			if(!$.trim($('#merlinclash_set_logcheck_val').val())){
				alert("检查日志重试次数功能开启，重试次数不能为空！");
				return false;
			}
		}
		if(E("merlinclash_set_startdelay_sw").checked){
			if(!$.trim($('#merlinclash_set_startdelay_val').val())){
				alert("开机自启推迟功能开启，秒数不能为空！");
				return false;
			}
		}
		// if(E("merlinclash_ipt_proxyrouter_sw").checked){
		// 	if(!$.trim($('#merlinclash_ipt_routingmark_val').val())){
		// 		alert("路由流量标记不能为空！");
		// 		return false;
		// 	}
		// }
		// db_merlinclash["merlinclash_ipt_routingmark_val"] = E("merlinclash_ipt_routingmark_val").value;
		db_merlinclash["merlinclash_set_logcheck_val"] = E("merlinclash_set_logcheck_val").value;
		db_merlinclash["merlinclash_set_startdelay_val"] = E("merlinclash_set_startdelay_val").value;
		db_merlinclash["merlinclash_set_yamlsel_start"] = E("merlinclash_set_yamlsel_start").value;
		db_merlinclash["merlinclash_set_geoip_type"] = E("merlinclash_set_geoip_type").value;
		db_merlinclash["merlinclash_set_geosite_type"] = E("merlinclash_set_geosite_type").value;
		yamlsel_tmp1 = E("merlinclash_set_yamlsel_start").value;
		db_merlinclash["merlinclash_set_yamlsel_edit"] = E("merlinclash_set_yamlsel_edit").value;
		db_merlinclash["merlinclash_sub_type"] = E("merlinclash_sub_type").value;
		db_merlinclash["merlinclash_sub_updatecycle"] = E("merlinclash_sub_updatecycle").value;
		db_merlinclash["merlinclash_set_tolerance_val"] = E("merlinclash_set_tolerance_val").value;
		db_merlinclash["merlinclash_set_interval_val"] = E("merlinclash_set_interval_val").value;
		if(init_nokpaclcount == 1){
			db_merlinclash["merlinclash_nokpacl_default_mode"] = E("merlinclash_nokpacl_default_mode").value;
			db_merlinclash["merlinclash_nokpacl_default_port"] = E("merlinclash_nokpacl_default_port").value;
		}
		db_merlinclash["merlinclash_nokpacl_method"] = E("merlinclash_nokpacl_method").value;
		//访问控制修改信息更新
		if(E("noKPACL_table")){
			var tr = E("noKPACL_table").getElementsByTagName("tr");
			for (var i = 1; i < tr.length-1 ; i++) {
				var rowid2 = tr[i].getAttribute("id").split("_")[2];
				//console.log(rowid2);
				if (E("merlinclash_nokpacl_name_" + rowid2)){
					db_merlinclash["merlinclash_nokpacl_name_" + rowid2] = E("merlinclash_nokpacl_name_" + rowid2).value;
					db_merlinclash["merlinclash_nokpacl_mac_" + rowid2] = E("merlinclash_nokpacl_mac_" + rowid2).value;
					db_merlinclash["merlinclash_nokpacl_mode_" + rowid2] = E("merlinclash_nokpacl_mode_" + rowid2).value;
					db_merlinclash["merlinclash_nokpacl_port_" + rowid2] = E("merlinclash_nokpacl_port_" + rowid2).value;
				}else{

				}
			}
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_yamltmp.sh", "params":[], "fields": ""};
		intoQueue({
			type: "POST",
			url: "/_api/",
			async: true,
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				yamlsel_tmp2 = response.result;
				//更换配置文件，清空节点指定内容
				if(yamlsel_tmp2==null){
					yamlsel_tmp2=yamlsel_tmp1
				}
				if(yamlsel_tmp2!=yamlsel_tmp1){
					db_merlinclash["merlinclash_action"] = "1";
					db_merlinclash["merlinclash_set_yamlsel_startchange"] = "1";
				}
				if(yamlsel_tmp2 == yamlsel_tmp1){
					db_merlinclash["merlinclash_action"] = "1";
					db_merlinclash["merlinclash_set_yamlsel_startchange"] = "0";
				}
				push_data("clash_config.sh", "start",  getPushData());
			},
			error: function(){
				console.log("ERROR");
			}
		});
	}
	//过滤不需要提交的数据
	function getPushData(){
		var pushData = {};
		$.each(db_merlinclash, (k,v)=>{
			if(v != db_merlinclash_tmp[k]){
				pushData[k] = v;
			}
		})
		return pushData;
	}
	//push_data方法。调用实时日志显示
	function push_data(script, arg, obj, flag){
		if (!flag) showMCLoadingBar();
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": script, "params":[arg], "fields": obj};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response){
				if(response.result == id){
					if(flag && flag == "1"){
						refreshpage();
					}else if(flag && flag == "2"){
						//continue;
						//do nothing
					}else{
						get_realtime_log();	
					}
				}
			}
		});
	}
	function tabSelect(w) {
		trig=".show-btn" + w;
		for (var i = 0; i <= 10; i++) {
			$('.show-btn' + i).removeClass('active');
			$('#tablet_' + i).hide();
		}
		$('.show-btn' + w).addClass('active');
		$('#tablet_' + w).show();

		var id = parseInt(Math.random() * 100000000);
		var dbus_post={};
		dbus_post["merlinclash_trigger"] = db_merlinclash["merlinclash_trigger"] = trig;
		var postData = {"id": id, "method": "dummy_script.sh", "params":[], "fields": dbus_post};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {

			}
		});

	}
	function show_cirtag(){
		if(init_circount == 0){
			if(db_merlinclash["merlinclash_set_chnroute_sw"] == "1"){
				E("cirtag").innerHTML = "&nbsp;&nbsp;<em style='color: gold;'>规则总数：" + db_merlinclash["merlinclash_db_chnroute_num"] +"</em>";
			}else{
				E("cirtag").innerHTML = "";
			}
			init_circount = 1;
		}
	}
	function toggle_func() {
		//DNS编辑
		$(".show-btn0").click(
			function() {
				tabSelect(0);
				// $('#delallowneracls_button').hide();
			});
		//配置文件栏
		$(".show-btn1").click(
			function() {
				tabSelect(1);
				// $('#delallowneracls_button').hide();

			});
		//自定规则栏
		$(".show-btn2").click(
			function() {
				show_cirtag();
				if(init_aclcount == 0){
					refresh_acl_table();
					proxygroup_select();
					var cusrulesel = document.getElementsByName("cusruleplan").innerHTML = getradioval(8);
					CUSRULE_MODE(cusrulesel);
				}
				init_aclcount = 1;
				tabSelect(2);
				// $('#delallowneracls_button').show();
			});
		//访问控制栏
		$(".show-btn9").click(
			function() {
				if(init_nokpaclcount == 0){
					refresh_nokpacl_table();
				}
				init_nokpaclcount = 1;
				tabSelect(9);
				// $('#delallowneracls_button').hide();
			});
		//高级模式栏
		$(".show-btn3").click(
			function() {
				init_advancedcount = 1;
				tabSelect(3);
				// $('#delallowneracls_button').hide();

			});
		//附加功能栏
		$(".show-btn4").click(
			function() {
				if(db_merlinclash["merlinclash_db_geo_updatetime"]){
					E("geoip_updata_date").innerHTML = "<span style='color: gold'>上次更新时间："+db_merlinclash["merlinclash_db_geo_updatetime"]+"</span>";
				}
				if(db_merlinclash["merlinclash_db_chnroute_updatetime"]){
					E("chnroute_updata_date").innerHTML = "<span style='color: gold'>上次更新时间："+db_merlinclash["merlinclash_db_chnroute_updatetime"]+"</span>";
				}
				tabSelect(4);
				// $('#delallowneracls_button').hide();
			});
		//当前配置栏
		$(".show-btn6").click(
			function() {
				if(yamlview_count == 0){
					yaml_view();
				}
				yamlview_count = 1;
				tabSelect(6);
				// $('#delallowneracls_button').hide();


			});
		//日志记录栏
		$(".show-btn7").click(
			function() {
				if(log_count == 0){
					node_remark_view();
					get_log();
				}
				log_count = 1;
				tabSelect(7);
				// $('#delallowneracls_button').hide();

			});
		//显示默认页
		if(db_merlinclash["merlinclash_trigger"]){
			var trig= db_merlinclash["merlinclash_trigger"];
		}else{
			var trig = ".show-btn0"
		}

		$(trig).trigger("click");

	}
	function getyaml_basic() {
		var id = parseInt(Math.random() * 100000000);
		var dbus_post={};
		var postData = {"id": id, "method": "clash_getbasicyaml.sh", "params":[], "fields": dbus_post};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
			}
		});
	}
function get_clash_status_front2(id) {
	$.ajax({
		type: "POST",
		async: true,
		cache:false,
		url: "/_result/"+id,
		dataType: "json",
		success: function(response) {
			if (typeof response.result == "number"){
				setTimeout("get_clash_status_front2("+response.result+");", 1000);
			}
			else {
			if (init_count==0){
				var arr = response.result.split("@");
				if (arr[0] == "" || arr[1] == "") {
					E("clash_state1").innerHTML = "内核启动时间 - " + "Waiting for first refresh...";
					E("clash_state2").innerHTML = "内核进程 - " + "Waiting for first refresh...";
					E("clash_state3").innerHTML = "实时守护进程 - " + "Waiting for first refresh...";
				} else {
					E("clash_state1").innerHTML = arr[9];
					E("clash_state2").innerHTML = arr[0];
					E("clash_state3").innerHTML = arr[1];
					yamlsel_tmp2 = arr[7];
					//获取后台返回的IP
					E("ip-ipipnet").innerHTML = arr[10];
					E("ip-ipapi").innerHTML = arr[11];
					E("http-baidu").innerHTML = arr[12] == "连通正常" ? '<span style="color:#6C0">连接正常</span>' :'<span style="color:#ff0000">连接失败</span>';
					E("http-google").innerHTML = arr[13] == "连通正常" ? '<span style="color:#6C0">连接正常</span>' :'<span style="color:#ff0000">连接失败</span>';
					//获取结束
					var port = arr[3];
					var protocol = location.protocol;
					var zashHref;
					var hostname = document.domain;
					if (hostname.indexOf('.kooldns.cn') != -1 || hostname.indexOf('.gd.ddnsto.com') != -1 || hostname.indexOf('.x.ddnsto.com') != -1 || hostname.indexOf('.ddnsto.com') != -1 || hostname.indexOf('.tocmcc.cn') != -1) {
						var protocol = location.protocol;
						if(hostname.indexOf('.kooldns.cn') != -1){
							hostname = hostname.replace('.kooldns.cn','-clash.kooldns.cn');
						}else if(hostname.indexOf('.gd.ddnsto.com') != -1){
							hostname = hostname.replace('.gd.ddnsto.com','-clash.gd.ddnsto.com');
						}else if(hostname.indexOf('.x.ddnsto.com') != -1){
							hostname = hostname.replace('.x.ddnsto.com','-clash.x.ddnsto.com');
						}else if(hostname.indexOf('.ddnsto.com') != -1){
							hostname = hostname.replace('.ddnsto.com','-clash.ddnsto.com');
						}else{
							hostname = hostname.replace('.tocmcc.cn','-clash.tocmcc.cn');
						}

						if(protocol == "https:")
						{
							port = 443;
						}else{
							port = 5000;
						}
						zashHref   =  protocol + '//' + hostname + "/ui/zashboard/#/setup?hostname=" + hostname + "&port=" + port + "&secret=" + arr[4] + "&disableTunMode=1";
					}else{
						zashHref   = "http://"+ location.hostname + ":" +arr[3]+ "/ui/zashboard/#/setup?hostname=" + location.hostname + "&port=" + arr[3] + "&secret=" + arr[4] + "&disableTunMode=1";
					}

					$("#zash").html("<a type='button' style='vertical-align: middle; cursor:pointer;' class='ks_btn' href='" + zashHref + "' target='_blank' >访问 ZashBoard 面板</a>");
					E("clash_yamlsel").innerHTML = arr[5];
				}
				init_count = 1;
			} else {
				var arr = response.result.split("@");
				if (arr[0] == "" || arr[1] == "") {
					E("clash_state1").innerHTML = "内核启动时间 - " + "Waiting for first refresh...";
					E("clash_state2").innerHTML = "内核进程 - " + "Waiting for first refresh...";
					E("clash_state3").innerHTML = "实时守护进程 - " + "Waiting for first refresh...";
				} else {
					E("clash_state1").innerHTML = arr[2];
					E("clash_state2").innerHTML = arr[0];
					E("clash_state3").innerHTML = arr[1];
				}
			}
			setTimeout("get_clash_status_front();", 5000);
			}
		}
	});
}
	function get_clash_status_front() {
		if (db_merlinclash['merlinclash_enable'] != "1") {
			E("clash_state1").innerHTML = "内核启动时间 - " + "Waiting...";
			E("clash_state2").innerHTML = "内核进程 - " + "Waiting...";
			E("clash_state3").innerHTML = "实时守护进程 - " + "Waiting...";
			return false;
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_status.sh", "params":[], "fields": ""};
		//初始化完成获取简要数据，不获取全量数据
		if(init_count == 0){
			postData.params = [
			"init"
			];
		}else{
			postData.params = [
			"running"
			];
		}
		intoQueue({
			type: "POST",
			url: "/_api/",
			async: true,
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				if (typeof response.result == "number"){
					setTimeout("get_clash_status_front2("+response.result+");", 1000);
				}
				else {
				if (init_count == 0){
					var arr = response.result.split("@");
					if (arr[0] == "" || arr[1] == "") {
						E("clash_state1").innerHTML = "内核启动时间 - " + "Waiting for first refresh...";
						E("clash_state2").innerHTML = "内核进程 - " + "Waiting for first refresh...";
						E("clash_state3").innerHTML = "实时守护进程 - " + "Waiting for first refresh...";
					} else {
						E("clash_state1").innerHTML = arr[9];
						E("clash_state2").innerHTML = arr[0];
						E("clash_state3").innerHTML = arr[1];
						yamlsel_tmp2 = arr[7];
						//获取后台返回的IP
						E("ip-ipipnet").innerHTML = arr[10];
						E("ip-ipapi").innerHTML = arr[11];
						E("http-baidu").innerHTML = arr[12] == "连通正常" ? '<span style="color:#6C0">连接正常</span>' :'<span style="color:#ff0000">连接失败</span>';
						E("http-google").innerHTML = arr[13] == "连通正常" ? '<span style="color:#6C0">连接正常</span>' :'<span style="color:#ff0000">连接失败</span>';
						//获取结束
						var port = arr[3];
						var protocol = location.protocol;
						var zashHref;
						var hostname = document.domain;
						if (hostname.indexOf('.kooldns.cn') != -1 || hostname.indexOf('.gd.ddnsto.com') != -1 || hostname.indexOf('.x.ddnsto.com') != -1 || hostname.indexOf('.ddnsto.com') != -1 || hostname.indexOf('.tocmcc.cn') != -1) {
							var protocol = location.protocol;
							if(hostname.indexOf('.kooldns.cn') != -1){
								hostname = hostname.replace('.kooldns.cn','-clash.kooldns.cn');
							}else if(hostname.indexOf('.gd.ddnsto.com') != -1){
								hostname = hostname.replace('.gd.ddnsto.com','-clash.gd.ddnsto.com');
							}else if(hostname.indexOf('.x.ddnsto.com') != -1){
								hostname = hostname.replace('.x.ddnsto.com','-clash.x.ddnsto.com');
							}else if(hostname.indexOf('.ddnsto.com') != -1){
								hostname = hostname.replace('.ddnsto.com','-clash.ddnsto.com');
							}else{
								hostname = hostname.replace('.tocmcc.cn','-clash.tocmcc.cn');
							}

							if(protocol == "https:")
							{
								port = 443;
							}else{
								port = 5000;
							}
							zashHref   =  protocol + '//' + hostname + "/ui/zashboard/#/setup?hostname=" + hostname + "&port=" + port + "&secret=" + arr[4] + "&disableTunMode=1";
						}else{
							zashHref   = "http://"+ location.hostname + ":" +arr[3]+ "/ui/zashboard/#/setup?hostname=" + location.hostname + "&port=" + arr[3] + "&secret=" + arr[4] + "&disableTunMode=1";
						}

						$("#zash").html("<a type='button' style='vertical-align: middle; cursor:pointer;' class='ks_btn' href='" + zashHref + "' target='_blank' >访问 ZashBoard 面板</a>");
						E("clash_yamlsel").innerHTML = arr[5];
					}
					init_count = 1;
				} else {
					var arr = response.result.split("@");
					if (arr[0] == "" || arr[1] == "") {
						E("clash_state1").innerHTML = "内核启动时间 - " + "Waiting for first refresh...";
						E("clash_state2").innerHTML = "内核进程 - " + "Waiting for first refresh...";
						E("clash_state3").innerHTML = "实时守护进程 - " + "Waiting for first refresh...";
					} else {
						E("clash_state1").innerHTML = arr[2];
						E("clash_state2").innerHTML = arr[0];
						E("clash_state3").innerHTML = arr[1];
					}
				}
				setTimeout("get_clash_status_front();", 5000);
				}
			}
		});
	}
	//----------------详细状态-----------------------------
	function close_proc_status() {
		$("#detail_status").fadeOut(200);
	}
	function get_proc_status() {
		$("#detail_status").fadeIn(500);
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_proc_status.sh", "params":[], "fields": ""};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				if(response.result == id){
					write_proc_status();
				}
			}
		});
	}
	function write_proc_status() {
		intoQueue({
			url: '/_temp/clash_proc_status.txt',
			type: 'GET',
			cache:false,
			dataType: 'text',
			success: function(res) {
				$('#proc_status').val(res);
			}
		});
	}
	//----------------订阅转换-----------------------------
	function get_online_yaml3(action) {
		var dbus_post = {};
		if(!$.trim($('#merlinclash_sub_rename').val())){
			alert("重命名框不能为空！");
			return false;
		}
		if(!$.trim($('#merlinclash_sub_links').val())){
			alert("订阅链接不能为空！");
			return false;
		}
		if(!$.trim($('#merlinclash_sub_include').val())){
			var include = "";
		}else{
			var include = Base64.encode(E("merlinclash_sub_include").value);
		}
		if(!$.trim($('#merlinclash_sub_exclude').val())){
			var exclude = "";
		}else{
			var exclude = Base64.encode(E("merlinclash_sub_exclude").value);
		}
		if(!$.trim($('#merlinclash_sub_useragent').val())){
			var useragent = "";
		}else{
			var useragent = Base64.encode(E("merlinclash_sub_useragent").value);
		}
		var links3_base64 = "";
		links3_base64 = Base64.encode(E("merlinclash_sub_links").value);
		dbus_post["merlinclash_sub_links"] = db_merlinclash["merlinclash_sub_links"] = links3_base64;

		// var links3 = Base64.encode(encodeURIComponent(E("merlinclash_sub_links").value));
		// dbus_post["merlinclash_sub_links"] = db_merlinclash["merlinclash_sub_links"] = links3;
		dbus_post["merlinclash_sub_rename"] = db_merlinclash["merlinclash_sub_rename"] = (E("merlinclash_sub_rename").value);
		dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = 2;
		dbus_post["merlinclash_sub_type"] = db_merlinclash["merlinclash_sub_type"] = E("merlinclash_sub_type").value;
		dbus_post["merlinclash_sub_updatecycle"] = db_merlinclash["merlinclash_sub_updatecycle"] = E("merlinclash_sub_updatecycle").value;
		dbus_post["merlinclash_sub_include"] = db_merlinclash["merlinclash_sub_include"] = include;
		dbus_post["merlinclash_sub_exclude"] = db_merlinclash["merlinclash_sub_exclude"] = exclude;
		dbus_post["merlinclash_sub_useragent"] = db_merlinclash["merlinclash_sub_useragent"] = useragent;
		dbus_post["merlinclash_sub_udp"] = db_merlinclash["merlinclash_sub_udp"] = E("merlinclash_sub_udp").checked ? '1' : '0';
		dbus_post["merlinclash_sub_tfo"] = db_merlinclash["merlinclash_sub_tfo"] = E("merlinclash_sub_tfo").checked ? '1' : '0';
		dbus_post["merlinclash_sub_scv"] = db_merlinclash["merlinclash_sub_scv"] = E("merlinclash_sub_scv").checked ? '1' : '0';
		dbus_post["merlinclash_sub_emoji"] = db_merlinclash["merlinclash_sub_emoji"] = E("merlinclash_sub_emoji").checked ? '1' : '0';
		push_data("clash_subscribe.sh", action,  dbus_post);
	}

	//------------------------------------导出全局数据 BEGIN--------------------------------------------
	function down_clashdata(arg) {
		var id = parseInt(Math.random() * 100000000)
		var dbus_post = {};
		dbus_post["merlinclash_bak_set"] = db_merlinclash["merlinclash_bak_set"] = E("merlinclash_bak_set").checked ? '1' : '0';
		dbus_post["merlinclash_bak_acl"] = db_merlinclash["merlinclash_bak_acl"] = E("merlinclash_bak_acl").checked ? '1' : '0';
		dbus_post["merlinclash_bak_yaml"] = db_merlinclash["merlinclash_bak_yaml"] = E("merlinclash_bak_yaml").checked ? '1' : '0';
		dbus_post["merlinclash_bak_rule"] = db_merlinclash["merlinclash_bak_rule"] = E("merlinclash_bak_rule").checked ? '1' : '0';
		dbus_post["merlinclash_bak_dns"] = db_merlinclash["merlinclash_bak_dns"] = E("merlinclash_bak_dns").checked ? '1' : '0';
		dbus_post["merlinclash_bak_db"] = db_merlinclash["merlinclash_bak_db"] = E("merlinclash_bak_db").checked ? '1' : '0';
		var postData = {"id": id, "method": "clash_backup.sh", "params":[arg], "fields": dbus_post };
		intoQueue({
			type: "POST",
			url: "/_api/",
			async: true,
			cache:false,
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response){
				if(response.result == id){
					if(arg == "backup"){
						var downloadA = document.createElement('a');
						var josnData = {};
						var a = "http://"+window.location.hostname+"/_temp/"+"mc_backup.tar.gz"
						var blob = new Blob([JSON.stringify(josnData)],{type : 'application/json'});
						downloadA.href = a;
						downloadA.download = "mc_backup.tar.gz";
						downloadA.click();
						window.URL.revokeObjectURL(downloadA.href);
					}
				}
			}
		});
	}
	function upload_clashdata() {
		if(!$.trim($('#clashdata').val())){
			alert("请先选择文件");
			return false;
		}
		layer.confirm('<li>请确保备份文件合法！仍要上传备份吗？</li>', {
			shade: 0.8,
		}, function(index) {
			var filename = $("#clashdata").val();
			filename = filename.split('\\');
			filename = filename[filename.length - 1];
			var lastindex = filename.lastIndexOf('.')
			filelast = filename.substring(lastindex)
			if (filelast != ".gz" ) {
				console.log(filename);
				console.log(filelast);
				alert('上传文件格式不正确！');

				return false;
			}
			E('clashdata_info').style.display = "none";
			var formData = new FormData();
			formData.append("mc_backup.tar.gz", $('#clashdata')[0].files[0]);
			intoQueue({
				url: '/_upload',
				type: 'POST',
				cache: false,
				data: formData,
				processData: false,
				contentType: false,
				complete: function(res) {
					if (res.status == 200) {
						E('clashdata_info').style.display = "block";
						restore_clash_data("restore");
					}
				}
			});
			layer.close(index);
			return true;
		}, function(index) {
			layer.close(index);
			return false;
		});
	}
	function restore_clash_data(action) {
		showMCLoadingBar();
		var dbus_post = {};
		var id = parseInt(Math.random() * 100000000);
		dbus_post["merlinclash_bak_set"] = db_merlinclash["merlinclash_bak_set"] = E("merlinclash_bak_set").checked ? '1' : '0';
		dbus_post["merlinclash_bak_acl"] = db_merlinclash["merlinclash_bak_acl"] = E("merlinclash_bak_acl").checked ? '1' : '0';
		dbus_post["merlinclash_bak_yaml"] = db_merlinclash["merlinclash_bak_yaml"] = E("merlinclash_bak_yaml").checked ? '1' : '0';
		dbus_post["merlinclash_bak_rule"] = db_merlinclash["merlinclash_bak_rule"] = E("merlinclash_bak_rule").checked ? '1' : '0';
		dbus_post["merlinclash_bak_dns"] = db_merlinclash["merlinclash_bak_dns"] = E("merlinclash_bak_dns").checked ? '1' : '0';
		dbus_post["merlinclash_bak_db"] = db_merlinclash["merlinclash_bak_db"] = E("merlinclash_bak_db").checked ? '1' : '0';
		dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = 27;
		push_data("clash_backup.sh", action,  dbus_post);
	}
	//------------------------------------------删除配置 BEGIN--------------------------------------
	function del_yaml_sel(action) {
		var dbus_post = {};
		if(!$.trim($('#merlinclash_set_yamlsel_edit').val())){
			alert("配置文件不能为空！");
			return false;
		}
		if(E("merlinclash_set_yamlsel_edit").value == db_merlinclash["merlinclash_set_yamlsel_start"] && E("clash_state2").innerHTML != "内核进程 - " + "Waiting..."){
			alert("选择的配置文件为当前使用文件，不予删除！");
			return false;
		}
		dbus_post["merlinclash_set_yamlsel_edit"] = db_merlinclash["merlinclash_set_yamlsel_edit"] = (E("merlinclash_set_yamlsel_edit").value);
		dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = "4"
		push_data("clash_delyamlsel.sh", action, dbus_post);
	}
	//------------------------------------------更新配置--------------------------------------
	function update_yaml_sel(action) {
		var dbus_post = {};
		if(!$.trim($('#merlinclash_set_yamlsel_edit').val())){
			alert("配置文件不能为空！");
			return false;
		}
		dbus_post["merlinclash_set_yamlsel_edit"] = db_merlinclash["merlinclash_set_yamlsel_edit"] = (E("merlinclash_set_yamlsel_edit").value);
		dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = "2"
		push_data("clash_subscribe.sh", "update",  dbus_post);
	}
	//----------------------------下载配置-----------------------------
	function download_yaml_sel(action) {
		//下载前清空/tmp/upload文件夹下的yaml格式文件
		if(!$.trim($('#merlinclash_set_yamlsel_edit').val())){
			alert("配置文件不能为空！");
			return false;
		}
		var dbus_post = {};
		// clear_yaml();
		dbus_post["merlinclash_set_yamlsel_edit"] = db_merlinclash["merlinclash_set_yamlsel_edit"] = (E("merlinclash_set_yamlsel_edit").value);
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_downyamlsel.sh", "params":[action], "fields": dbus_post};
		var yamlname=""
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				yamlname = response.result;
				download(yamlname);
			}
		});
	}
	function download(yamlname) {
		var downloadA = document.createElement('a');
		var josnData = {};
		var a = "http://"+window.location.hostname+"/_temp/"+yamlname
		var blob = new Blob([JSON.stringify(josnData)],{type : 'application/json'});
		downloadA.href = a;
		downloadA.download = yamlname;
		downloadA.click();
		window.URL.revokeObjectURL(downloadA.href);
	}
	function yaml_view() {
		intoQueue({
			url: '/_temp/view.txt',
			type: 'GET',
			dataType: 'html',
			async: true,
			cache:false,
			success: function(response) {
				var retArea = E("yaml_content1");
				// Unicode 转 Emoji
				response = response.replace(/\\U([0-9A-Fa-f]{8})/g, function(match, hex) {
					try {
						// 将16进制转换为代码点
						const codePoint = parseInt(hex, 16);
						// 使用 String.fromCodePoint 转换
						return String.fromCodePoint(codePoint);
					} catch (e) {
						// 如果转换失败，返回原字符串
						return match;
					}
				});

				if (response.search("BBABBBBC") != -1) {
					retArea.value = response.replace("BBABBBBC", " ");
					var pageH = parseInt(E("FormTitle").style.height.split("px")[0]);
					if(pageH){
						autoTextarea(E("yaml_content1"), 0, (pageH - 308));
					}else{
						autoTextarea(E("yaml_content1"), 0, 980);
					}
					return true;
				}
				//加行号
				var contents = response.split('\n')
				var finalContent= '';
				for(var i = 0; i <contents.length; i++) {
					finalContent += i + "  " + contents[i] + '\n';
				}
				

				retArea.value = finalContent;
				_responseLen = response.length;
			},
			error: function(xhr) {
				E("yaml_content1").value = "获取配置文件信息失败！";
			}
		});
	}
	//在线获取广告区
	function notice_show() {
		intoQueue({
			url: 'https://gist.githubusercontent.com/zusterben/0bb8c4245ee0145cbf24de6170957f19/raw/clash_message.json.js?_=' + new Date().getTime(),
			type: 'GET',
			dataType: 'json',
			success: function(res) {
				if(res.content1){
					$("#showmsg1").html("<i>"+res.content1+"</i>");
				}
				if(res.content2){
					$("#showmsg2").html("<i>"+res.content2+"</i>");
				}
				if(res.content3){
					$("#showmsg3").html("<i>"+res.content3+"</i>");
				}
				if(res.content4){
					$("#showmsg4").html("<i>"+res.content4+"</i>");
				}
				if(res.content5){
					$("#showmsg5").html("<i>"+res.content5+"</i>");
				}
				if(res.content6){
					$("#showmsg6").html("<i>"+res.content6+"</i>");
				}
				if(res.content7){
					$("#showmsg7").html("<i>"+res.content7+"</i>");
				}
				if(res.content8){
					$("#showmsg8").html("<i>"+res.content8+"</i>");
				}
				if(res.content9){
					$("#showmsg9").html("<i>"+res.content9+"</i>");
				}
				if(res.content10){
					$("#showmsg10").html("<i>"+res.content10+"</i>");
				}
			}
		});
	}
	//日志获取
	function node_remark_view() {
		var txt = E("merlinclash_set_yamlsel_start").value;
		intoQueue({
			url: '/_temp/merlinclash_node_mark.log',
			type: 'GET',
			dataType: 'html',
			async: true,
			cache:false,
			success: function(response) {
				var retArea = E("nodes_content1");
				if (response.search("BBABBBBC") != -1) {
					retArea.value = response.replace("BBABBBBC", " ");
					var pageH = parseInt(E("FormTitle").style.height.split("px")[0]);
					if(pageH){
						autoTextarea(E("nodes_content1"), 0, (pageH - 308));
					}else{
						autoTextarea(E("nodes_content1"), 0, 980);
					}
					return true;
				}
				retArea.value = response;
				_responseLen = response.length;
			},
			error: function(xhr) {
				E("nodes_content1").value = "获取节点还原信息失败！";
			}
		});
	}
	function get_log() {
		intoQueue({
			url: '/_temp/merlinclash_log.txt',
			type: 'GET',
			dataType: 'html',
			async: true,
			cache:false,
			success: function(response) {
				var retArea = E("log_content1");
				if (response.search("BBABBBBC") != -1) {
					retArea.value = response.replace("BBABBBBC", " ");
					var pageH = parseInt(E("FormTitle").style.height.split("px")[0]);
					// if(pageH){
					// 	autoTextarea(E("log_content1"), 0, (pageH - 308));
					// }else{
					// 	autoTextarea(E("log_content1"), 0, 980);
					// }
					return true;
				}
				if (_responseLen == response.length) {
					noChange++;
				} else {
					noChange = 0;
				}
				if (noChange > 5) {
					return false;
				} else {
					setTimeout("get_log();", 300);
				}
				retArea.value = response;
				_responseLen = response.length;
			},
			error: function(xhr) {
				E("log_content1").value = "获取日志失败！";
			}
		});
	}
	function count_down_close1() {
		if (x == "0") {
			hideMCLoadingBar();
		}
		if (x < 0) {
			E("ok_button1").value = "手动关闭"
			return false;
		}
		E("ok_button1").value = "自动关闭（" + x + "）"
		--x;
		setTimeout("count_down_close1();", 1000);
	}
	function get_realtime_log() {
		intoQueue({
			url: '/_temp/merlinclash_log.txt',
			type: 'GET',
			async: true,
			cache: false,
			dataType: 'text',
			success: function(response) {
				var retArea = E("log_content3");
				if (response.search("BBABBBBC") != -1) {
					retArea.value = response.replace("BBABBBBC", " ");
					E("ok_button").style.display = "";
					retArea.scrollTop = retArea.scrollHeight;
					count_down_close1();
					return true;
				}
				if (_responseLen == response.length) {
					noChange++;
				} else {
					noChange = 0;
				}
				if (noChange > 1000) {
					return false;
				} else {
					setTimeout("get_realtime_log();", 500);
				}
				retArea.value = response.replace("BBABBBBC", " ");
				retArea.scrollTop = retArea.scrollHeight;
				_responseLen = response.length;
			},
			error: function() {
				setTimeout("get_realtime_log();", 500);
			}
		});
	}
	function getradioval(sel_tmp) {
		const nameMap = {
			"1": "dnsplan",
			"2": "yamlsel",
			"4": "tproxymode",
			"8": "cusruleplan"
		};
		
		if (nameMap[sel_tmp]) {
			var radio = document.getElementsByName(nameMap[sel_tmp]);
			for(i = 0; i< radio.length; i++){
				if(radio[i].checked){
					return radio[i].value
				}
			}
		}
	}
	function reload_Soft_Center() {
		location.href = "/Main_Soft_center.asp";
	}
	function load_cron_params() {
		function addOptions(selectors, options) {
			selectors.forEach(selector => {
				options.forEach(option => {
					$(selector).append("<option value='"+option.value+"' >"+option.text+"</option>");
				});
			});
		}

		// 小时选项
		var hourOptions = [];
		for (var i = 0; i < 24; i++) {
			hourOptions.push({value: i, text: i + "时"});
		}
		addOptions(["#merlinclash_select_hour", "#merlinclash_select_clash_restart_hour"], hourOptions);

		// 分钟选项
		var minuteOptions = [];
		for (var i = 0; i < 61; i++) {
			minuteOptions.push({value: i, text: i + "分"});
		}
		addOptions(["#merlinclash_select_minute", "#merlinclash_select_clash_restart_minute"], minuteOptions);

		// 星期选项
		var weekOptions = [["1", "一"], ["2", "二"], ["3", "三"], ["4", "四"], ["5", "五"], ["6", "六"], ["7", "日"]].map(item => ({value: item[0], text: item[1]}));
		addOptions(["#merlinclash_select_week", "#merlinclash_select_clash_restart_week"], weekOptions);

		// 重启间隔选项
		var intervalOptions = [["2", "2分钟"], ["5", "5分钟"], ["10", "10分钟"], ["15", "15分钟"], ["20", "20分钟"], ["25", "25分钟"], ["30", "30分钟"], ["1", "1小时"], ["3", "3小时"], ["6", "6小时"], ["12", "12小时"]].map(item => ({value: item[0], text: item[1]}));
		addOptions(["#merlinclash_select_clash_restart_minute_2"], intervalOptions);

		// 日期选项
		var dayOptions = [];
		for (var i = 1; i < 32; i++) {
			dayOptions.push({value: i, text: i + "日"});
		}
		addOptions(["#merlinclash_select_day", "#merlinclash_select_clash_restart_day"], dayOptions);
	}
	function show_job() {
		const restartModeConfig = {
			"1": { hour: false, minute: false, day: false, week: false, minute2: false },
			"2": { hour: true, minute: true, day: false, week: false, minute2: false },
			"3": { hour: true, minute: true, day: false, week: true, minute2: false },
			"4": { hour: true, minute: true, day: true, week: false, minute2: false },
			"5": { hour: false, minute: false, day: false, week: false, minute2: true }
		};

		const mode = E("merlinclash_select_clash_restart").value;
		const config = restartModeConfig[mode] || restartModeConfig["1"];

		// 应用配置
		$('#merlinclash_select_clash_restart_hour').toggle(config.hour);
		$('#merlinclash_select_clash_restart_minute').toggle(config.minute);
		$('#merlinclash_select_clash_restart_day').toggle(config.day);
		$('#merlinclash_select_clash_restart_week').toggle(config.week);
		$('#merlinclash_select_clash_restart_minute_2').toggle(config.minute2);
	}
	//订阅规则模块显示
	function subc_rule_change(obj) {
		var value = $(obj).find('option:selected').text();
		switch (value){

			case "订阅原始规则":
			document.getElementById("merlinclash_sub_duplicate").style.display = "none";
			document.getElementById("merlinclash_sub_filter").style.display = "none";
			// document.getElementById("merlinclash_sub_updatetime").style.display = "none";
			break;

			default:
			document.getElementById("merlinclash_sub_duplicate").style.display = "";
			document.getElementById("merlinclash_sub_filter").style.display = "";
			// document.getElementById("merlinclash_sub_updatetime").style.display = "";
			break;

		}
	}

	function del_yaml_sel_change(obj) {
		var value = $(obj).find('option:selected').text();
		if (value.startsWith("AP_")) {
        document.getElementById("udpate_yaml_btn").style.display = "";
    	} else {
        document.getElementById("udpate_yaml_btn").style.display = "none";
    	}
	}

	//修改自定规则模式显示
	function CUSRULE_MODE(mode_tag) {
		if(mode_tag == "pro"){
			document.getElementById("merlinclash_cusrule_table").style.display="none"
			document.getElementById("delallowneracls_button").style.display="none"
			document.getElementById("merlinclash_acl_edit_content").style.display=""

		}else{
			document.getElementById("merlinclash_cusrule_table").style.display=""
			document.getElementById("delallowneracls_button").style.display=""
			document.getElementById("merlinclash_acl_edit_content").style.display="none"
		}
		var dbus_post={};
		dbus_post["merlinclash_acl_plan"] = db_merlinclash["merlinclash_acl_plan"] = mode_tag;
		push_data("dummy_script.sh", "", dbus_post, "2");
		// rule_tag = db_merlinclash["merlinclash_set_yamlsel_start"];
		if(init_cusrulecount == 0){
			var id = parseInt(Math.random() * 100000000);
			var dbus_post={};
			var postData = {"id": id, "method": "clash_getbasicyaml.sh", "params":[], "fields": dbus_post};
			intoQueue({
				type: "POST",
				cache:false,
				url: "/_api/",
				data: JSON.stringify(postData),
				dataType: "json",
				success: function(response) {
					// cusrule_view(rule_tag);
				}
			});
		}
		init_cusrulecount = 1;

	}

	//------------------------------------------本地上传clash二进制------------------------------------//
	function upload_clashbinary() {

		if(!$.trim($('#clashbinary').val())){
			alert("请先选择二进制文件");
			return false;
		}
		layer.confirm('<li>请确保二进制文件合法！仍要上传二进制吗？</li>', {
			shade: 0.8,
		}, function(index) {
			E('clashbinary_upload').style.display = "none";
			var uploadname = E("merlinclash_binary_type").value;
			var formData = new FormData();
			formData.append(uploadname, document.getElementById('clashbinary').files[0]);
			intoQueue({
				url: '/_upload',
				type: 'POST',
				cache: false,
				data: formData,
				processData: false,
				contentType: false,
				complete: function(res) {
					if (res.status == 200) {
						upload_binary(uploadname);
					}
				}
			});
			layer.close(index);
			return true;
		}, function(index) {
			layer.close(index);
			return false;
		});
	}
	function upload_binary(uploadname) {
		var dbus_post = {};
		action = dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = "12"
		dbus_post["merlinclash_binary_type"] = db_merlinclash["merlinclash_binary_type"] = E("merlinclash_binary_type").value;
		push_data("clash_local_binary_upload.sh", action,  dbus_post);
		E('clashbinary_upload').style.display = "block";
	}
	//------------------------------------------本地上传配置------------------------------------//
	function upload_clashconfig() {
		var filename = $("#clashconfig").val();
		filename = filename.split('\\');
		filename = filename[filename.length - 1];
		var filelast = filename.split('.');
		filelast = filelast[filelast.length - 1];
		if (filename.length > 15) {
			alert(filename + '上传文件的文件名超过15个字符，请修改');
			return false;
		}
		if (filelast != "yaml") {
			alert('上传文件格式非法！只支持上传yaml后缀的配置文件');
			return false;
		}
		var reg = new RegExp("^[A-Za-z0-9]+$");
		//用.分割文件名
		var filenameCheck = filename.split('.');
		//大于2段说明文件名含"."直接报错，否则就用正则判断
		if (filenameCheck.length > 2 || !reg.test(filenameCheck[0]) ) {
			alert("上传文件格式非法！只能由字母和数字组成");
			return false;
		}
		E('clashconfig_info').style.display = "none";
		var formData = new FormData();

		formData.append(filename, document.getElementById('clashconfig').files[0]);

		intoQueue({
			url: '/_upload',
			type: 'POST',
			cache: false,
			data: formData,
			processData: false,
			contentType: false,
			complete: function(res) {
				if (res.status == 200) {
					upload_config(filename);
				}
			}
		});
	}

	//配置文件处理
	function upload_config(filename) {
		var dbus_post = {};
		dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = "3"
		dbus_post["merlinclash_sub_upload_filename"] = db_merlinclash["merlinclash_sub_upload_filename"] = filename;
		push_data("clash_subscribe.sh", "upload",  dbus_post);
		E('clashconfig_info').style.display = "block";
		//20200713
		yaml_select();
	}
	//------------------------------------------本地上传配置 结束------------------------------------//


	function version_show() {
		if(!db_merlinclash["merlinclash_version"]) db_merlinclash["merlinclash_version"] = "0.0.0"
			$("#merlinclash_version_show").html("<a class='hintstyle'><i>插件版本：" + db_merlinclash['merlinclash_version'] + "</i></a>");
		$("#merlinclash_core_version").html("<span>【内核版本】：" + db_merlinclash['merlinclash_binary_ver'] + " </span></div></td>");
	}
	// function markdisplay(label) {
	// 	var A = {};
	// 	A = E(label).checked ? '1' : '0';
	// 	if(A == "1"){
	// 		document.getElementById("mark_value").style.display=""
	// 	}else{
	// 		document.getElementById("mark_value").style.display="none"
	// 	}
	// }

	// 判断字符串是否包含中文
	function hasChinese(str) {
		return /[\u4E00-\u9FA5]+/g.test(str)
	}

	//开启mixport开关
	function mixport_save() {
		var dbus_post = {};
		var id = parseInt(Math.random() * 100000000);
		if(E("merlinclash_set_mixport_sw").checked == false){
			layer.confirm('<li>请确保已经成功开启了路由器防火墙！！！</li><li>否则端口可能暴露在公网环境下，被偷取代理流量！！！</li><li>设置后，重启插件才能生效</li>', {
				shade: 0.8,
				closeBtn: 0,
				title: "确定开启http/socks代理端口吗？",
				btn: ["开启http/socks代理端口","取消"]
			}, function(index) {
				dbus_post["merlinclash_set_mixport_sw"] = db_merlinclash["merlinclash_set_mixport_sw"] = "1"
				push_data("dummy_script.sh", "", dbus_post, "2");
				layer.close(index);
				return true;
			}, function(index) {
				E("merlinclash_set_mixport_sw").checked = false;
				layer.close(index);
				return false;
			});
		}else{
			dbus_post["merlinclash_set_mixport_sw"] = db_merlinclash["merlinclash_set_mixport_sw"] = "0"
			push_data("dummy_script.sh", "", dbus_post, "2");
		}

	}

	//透明代理开关
	function tproxy_save() {
		var dbus_post = {};
		var id = parseInt(Math.random() * 100000000);
		if(E("merlinclash_ipt_closeproxy_sw").checked == false){
			layer.confirm('<li>关闭透明代理后，您将无法无感翻墙</li><li>必须要在软件/终端设备设置Socks/Http代理后才可以使用本插件</li><li>设置后，重启插件才能生效</li>', {
				shade: 0.8,
				closeBtn: 0,
				title: "确定要关闭透明代理吗？",
				btn: ["关闭透明代理","取消"]
			}, function(index) {
				document.getElementById("tproxy_seting").style.display="none"
				dbus_post["merlinclash_ipt_closeproxy_sw"] = db_merlinclash["merlinclash_ipt_closeproxy_sw"] = "1";
				push_data("dummy_script.sh", "", dbus_post, "2");
				layer.close(index);
				return true;
			}, function(index) {
				E("merlinclash_ipt_closeproxy_sw").checked = false;
				document.getElementById("tproxy_seting").style.display=""
				layer.close(index);
				return false;
			});
		}else{
			document.getElementById("tproxy_seting").style.display="";
			dbus_post["merlinclash_ipt_closeproxy_sw"] = db_merlinclash["merlinclash_ipt_closeproxy_sw"] = "0";
			push_data("dummy_script.sh", "", dbus_post, "2");
		}

	}

	//DNS方案即时改变
	function dnsplan_change(dnsMode) {
		var dbus_post = {};
		var id = parseInt(Math.random() * 100000000);
		if(dnsMode == 'rh'){
			dbus_post["merlinclash_dns_type"] = db_merlinclash["merlinclash_dns_type"] = E("merlinclash_dns_type").value = "rh";
			document.getElementById("dns_fakeipblack").style.display="none"
		}else if(dnsMode == 'fi'){
			dbus_post["merlinclash_dns_type"] = db_merlinclash["merlinclash_dns_type"] = E("merlinclash_dns_type").value = "fi";
			document.getElementById("dns_fakeipblack").style.display=""
		}
		push_data("dummy_script.sh", "", dbus_post, "2");

	}
	function proxymode_change(proxyMode) {
    	if(proxyMode != 'closed') {
    		alert("TProxy模块与以下路由功能冲突，请确认已经关闭！\n\n- AiProtection 网络神盾 -\n- Adaptive QoS 智能场景加速 -\n- Traffic Analyzer 流量分析 -");
    	}
    	var dbus_post = {};
    	var id = parseInt(Math.random() * 100000000);
    	const ipv6Element = document.getElementById("clash_ipv6");
    	if(proxyMode == 'closed' || proxyMode == 'udp') {
			E("merlinclash_ipt_ipv6_sw").checked = false;
			dbus_post["merlinclash_ipt_ipv6_sw"] = db_merlinclash["merlinclash_ipt_ipv6_sw"] = E("merlinclash_ipt_ipv6_sw").value = "0";
        	dbus_post["merlinclash_ipt_tproxy_type"] = db_merlinclash["merlinclash_ipt_tproxy_type"] = E("merlinclash_ipt_tproxy_type").value = proxyMode;
        	if(ipv6Element) {
            	ipv6Element.style.display = "none";
        	}
    	} else if(proxyMode == 'tcp' || proxyMode == 'tcpudp') {
        	dbus_post["merlinclash_ipt_tproxy_type"] = db_merlinclash["merlinclash_ipt_tproxy_type"] = E("merlinclash_ipt_tproxy_type").value = proxyMode;
        	if(ipv6Element) {
        	    ipv6Element.style.display = "";
        	}
    	}
   		push_data("dummy_script.sh", "", dbus_post, "2");
	}
	//定时重启
	function clash_restart_save() {
		var dbus_post = {};
		var id = parseInt(Math.random() * 100000000);
		dbus_post["merlinclash_select_clash_restart"]	= db_merlinclash["merlinclash_select_clash_restart"] = E("merlinclash_select_clash_restart").value;
		dbus_post["merlinclash_select_clash_restart_day"]	= db_merlinclash["merlinclash_select_clash_restart_day"] = E("merlinclash_select_clash_restart_day").value;
		dbus_post["merlinclash_select_clash_restart_week"] = db_merlinclash["merlinclash_select_clash_restart_week"] = E("merlinclash_select_clash_restart_week").value;
		dbus_post["merlinclash_select_clash_restart_hour"] = db_merlinclash["merlinclash_select_clash_restart_hour"] = E("merlinclash_select_clash_restart_hour").value;
		dbus_post["merlinclash_select_clash_restart_minute"] = db_merlinclash["merlinclash_select_clash_restart_minute"] = E("merlinclash_select_clash_restart_minute").value;
		dbus_post["merlinclash_select_clash_restart_minute_2"] = db_merlinclash["merlinclash_select_clash_restart_minute_2"] = E("merlinclash_select_clash_restart_minute_2").value;
		var postData = {"id": id, "method": "clash_restart_regularly.sh", "params":[], "fields": dbus_post};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			error: function(xhr) {

			},
			success: function(response) {
				refreshpage();
			}
		});
	}
	//导出日志
	function outputlog(){
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_outputlog.sh", "params":[], "fields": ""};
		intoQueue({
			type: "POST",
			async: true,
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				if(response.result == id){
					var downloadA = document.createElement('a');
					var josnData = {};
					var a = "http://"+window.location.hostname+"/_temp/"+"clash_run.log"
					var blob = new Blob([JSON.stringify(josnData)],{type : 'application/json'});
					downloadA.href = a;
					downloadA.download = "clash_run.log";
					downloadA.click();
					window.URL.revokeObjectURL(downloadA.href);
				}
			}
		});
	}
	//通用编辑框
	function common_text_editor_open(type, title) {
		getyaml_basic();
		$("#common_text_editor_title").html(title);

		const typeConfig = {
			sniffer: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/sniff/" target="_blank">Mihomo帮助文档-Sniffer</a>；',
				url: '/_temp/clash_sniffercontent.txt'
			},
			dns_rh: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/dns/" target="_blank">Mihomo帮助文档-DNS</a>；',
				url: '/_temp/clash_redirhost.txt'
			},
			dns_fi: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/dns/" target="_blank">Mihomo帮助文档-DNS</a>；',		
				url: '/_temp/clash_fakeip.txt'
			},
			hosts: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/dns/hosts/" target="_blank">Mihomo帮助文档-Hosts</a>；',
				url: '/_temp/clash_hosts.txt'
			},
			head: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/general/" target="_blank">Mihomo帮助文档-全局配置</a>；',
				url: '/_temp/clash_head.txt'
			},
			acl: {
				content: '更多设置内容，请查阅 <a href="https://wiki.metacubex.one/config/rules/" target="_blank">Mihomo帮助文档-路由规则</a>；',
				url: '/_temp/clash_rule.txt',
				ruletxt: true
			},
			ipt_black: {
				content: '请输入IP/域名，一行一个，可以带掩码声明；',
				url: '/_temp/clash_ipsetproxyarround.txt',
				hasErrorHandler: true
			},
			ipt_white: {
				content: '请输入IP/域名，一行一个，可以带掩码声明；',
				url: '/_temp/clash_ipsetproxy.txt',
				hasErrorHandler: true
			}
		};

		const config = typeConfig[type];
		if (config) {
			$("#common_text_editor_content").html(config.content);
			
			const ajaxConfig = {
				url: config.url,
				type: 'GET',
				cache: false,
				dataType: 'text',
				success: function (res) {
					$('#common_text_editor_text').val(res);
				}
			};

			if (config.hasErrorHandler) {
				ajaxConfig.error = function (xhr) {
					$('#common_text_editor_text').attr('placeholder','请输入IP/域名，一行一个，如：\nabc.com\n123.123.123.123/32');
				};
			}

			if (config.ruletxt) {
				{
					$('#common_text_editor_text').attr('placeholder', '请输入自定义规则，顶格写，不需要写“-”,每条规则占一行，如：\nDOMAIN,abc.com.io,DIRECT\nDOMAIN-SUFFIX,123.com,♻️ 手动切换');
				};
			}

			intoQueue(ajaxConfig);
		}

		//展示
		$("#common_text_editor").fadeIn(200);
		//给common_text_editor_save绑定点击事件
		$("#common_text_editor_save").unbind("click").click(function(){
			common_text_editor_save(type);
		});
	}

	function common_text_editor_close() {
		$('#common_text_editor_text').val('');
		$("#common_text_editor").fadeOut(200);
	}

	function common_text_editor_save(type) {
		//采取分段保存
		var dbus_post = {};
		var str = "";
		var n = 5000;
		var i = 0;
		var sr_content = E("common_text_editor_text").value;
		var check_chinese = false 
		if(type == 'sniffer'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "sniffer";
		}else if(type == 'hosts'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "hosts";
		}else if(type == 'head'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "head";
		}else if(type == 'dns_rh'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "redirhost";
		}else if(type == 'dns_fi'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "fakeip";
		}else if(type == 'acl'){
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "acl";
		}else if(type == 'ipt_black'){
			check_chinese = true
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "iptblack";
		}else if(type == 'ipt_white'){
			check_chinese = true
			dbus_post["merlinclash_yamledit_tag"] = db_merlinclash["merlinclash_yamledit_tag"] = "iptwhite";
		}
		if (sr_content != "") {
			if(check_chinese){
				if(hasChinese(sr_content)){
					alert("保存失败，请不要输入中文！");
					return false;
				}
			}
			str = Base64.encode(encodeURIComponent(sr_content));
			for (l = str.length; i < l / n; i++) {
				var a = str.slice(n * i, n * (i + 1));
				dbus_post[`merlinclash_yamledit_content_${i}`] = db_merlinclash[`merlinclash_yamledit_content_${i}`] = a;
			}
			dbus_post[`merlinclash_yamledit_content_count`] = db_merlinclash[`merlinclash_yamledit_content_count`] = i;
		} else {
			dbus_post[`merlinclash_yamledit_content_0`] = db_merlinclash[`merlinclash_yamledit_content_0`] = " ";
			dbus_post[`merlinclash_yamledit_content_count`] = db_merlinclash[`merlinclash_yamledit_content_count`] = 1;
		}
		//post data
		var id = parseInt(Math.random() * 100000000);
		var postData = { "id": id, "method": "clash_yamlfilechange.sh", "params": [], "fields": dbus_post };
		intoQueue({
			type: "POST",
			cache: false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			error: function (xhr) {

			},
			success: function (response) {
				refreshpage();
			}
		});
	}

	function getCurrentDateTime() {
		var date = new Date();
		var seperator1 = "-";
		var seperator2 = ":";
		var month = date.getMonth() + 1;
		var strDate = date.getDate();
		if (month >= 1 && month <= 9) {
			month = "0" + month;
		}
		if (strDate >= 0 && strDate <= 9) {
			strDate = "0" + strDate;
		}
		return date.getFullYear() + seperator1 + month + seperator1 + strDate
		+ " " + date.getHours() + seperator2 + date.getMinutes()
		+ seperator2 + date.getSeconds();
	}

	function updateDatabase(type, action, confirmMessage, script, updateTimeKey, dateElementId, extraFields) {
		var dbus_post = {};
		var currentdate = getCurrentDateTime();
		
		layer.confirm(confirmMessage, {
			shade: 0.8,
		}, function(index) {
			$("#log_content3").attr("rows", "20");
			dbus_post["merlinclash_action"] = db_merlinclash["merlinclash_action"] = action;
			dbus_post[updateTimeKey] = db_merlinclash[updateTimeKey] = currentdate;
			
			// 添加额外字段
			if (extraFields) {
				for (var key in extraFields) {
					dbus_post[key] = db_merlinclash[key] = extraFields[key];
				}
			}
			
			push_data(script, action, dbus_post);
			E(dateElementId).innerHTML = "<span style='color: gold'>上次更新时间："+currentdate+"</span>";
			layer.close(index);
			return true;

		}, function(index) {
			layer.close(index);
			return false;
		});
	}

	function geoip_update(action){
		updateDatabase(
			"geo",
			action,
			'<li>你确定要更新Geo数据库吗？</li>',
			"clash_update_ipdb.sh",
			"merlinclash_db_geo_updatetime",
			"geoip_updata_date",
			{
				"merlinclash_set_geoip_type": E("merlinclash_set_geoip_type").value,
				"merlinclash_set_geosite_type": E("merlinclash_set_geosite_type").value
			}
		);
	}

	function chnroute_update(action){
		updateDatabase(
			"chnroute",
			action,
			'<li>你确定要更新大陆白名单规则吗？</li>',
			"clash_update_chnroute.sh",
			"merlinclash_db_chnroute_updatetime",
			"chnroute_updata_date"
		);
	}
	//----------------下拉框获取配置文件名BEGIN--------------------------
	function yaml_select(){
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_getbasicyaml.sh", "params":[], "fields": ""};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				if(response.result == id){
					yaml_select_get();
				}
			}
		});
	}

	function yaml_select_get() {
		intoQueue({
			url: '/_temp/yamls.txt',
			type: 'GET',
			cache:false,
			dataType: 'text',
			success: function(response) {
				//按换行符切割
				var arr = response.split("\n");
				Myselect(arr);
			}
		});
	}
	var counts;
	counts=0;
	function Myselect(arr){
		var i;
		counts=arr.length;
		var yamllist = arr;
		$("#merlinclash_set_yamlsel_start").append("<option value=''>--请选择--</option>");
		$("#merlinclash_set_yamlsel_edit").append("<option value=''>--请选择--</option>");

		for(i=0;i<yamllist.length-1;i++){
			var a=yamllist[i];
			//$("#merlinclash_set_yamlsel_start").append("<option value='"+a+"' >"+a+"</option>");
			if(a == db_merlinclash["merlinclash_set_yamlsel_start"]){//如果是用户选择的，则变成被选中状态
				$("#merlinclash_set_yamlsel_start").append("<option value=" + a + " selected>" + a + "</option>")
			}else{
				$("#merlinclash_set_yamlsel_start").append("<option value=" + a + ">" + a + "</option>");
			}
			$("#merlinclash_set_yamlsel_edit").append("<option value=" + a + ">" + a + "</option>");
		}
	}

	//----------------------------proxy-group 下拉框部分代码BEGIN-------------------------//
	function proxygroup_select(){
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_getproxygroup.sh", "params":[], "fields": ""};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				if(response.result == id){
					setTimeout("proxygroup_select_get();", 300);
					setTimeout("proxytype_select_get();", 300);
				}
			}
		});
	}
	function proxygroup_select_get() {
		intoQueue({
			url: '/_temp/proxygroups.txt',
			type: 'GET',
			cache:false,
			dataType: 'text',
			success: function(response) {
				//按换行符切割
				var arr = response.split("\n");
				Mypgselect(arr);
			}
		});
	}
	var pgcounts;
	pgcounts=0;
	function Mypgselect(arr){
		var i;
		pgcounts=arr.length;
		var pglist = arr;  
		$("#merlinclash_acl_lianjie").append("<option value=''>--请选择--</option>");
		for(i=0;i<pglist.length-1;i++){
			var a=pglist[i];
			$("#merlinclash_acl_lianjie").append("<option value='"+a+"' >"+a+"</option>");
		}
	}
	function proxytype_select_get() {
		intoQueue({
			url: '/_temp/proxytype.txt',
			type: 'GET',
			cache:false,
			dataType: 'text',
			success: function(response) {
				//按换行符切割
				var arr = response.split("\n");
				Myptselect(arr);
			}
		});
	}
	var ptcounts;
	ptcounts=0;
	function Myptselect(arr){
		var i;
		ptcounts=arr.length;
		var ptlist = arr;  
		$("#merlinclash_acl_type").append("<option value=''>--请选择--</option>");
		for(i=0;i<ptlist.length-1;i++){
			var a=ptlist[i];
			$("#merlinclash_acl_type").append("<option value='"+a+"' >"+a+"</option>");
		}
	}
	//----------------------------proxy-group下拉框部分代码END--------------------------//

	//----------------------------自定规则代码部分BEGIN--------------------------------------//
	function refresh_acl_table(q) {
		var db_acl;
		$.ajax({
			type: "GET",
			url: "/_api/merlinclash_acl",
			dataType: "json",
			async: false,
			success: function(data) {
				db_acl = data.result[0];
				refresh_acl_html(db_acl);

			//write dynamic table value
			for (var i = 1; i < acl_node_max + 1; i++) {
				if (typeof db_acl["merlinclash_acl_type_" + i] == "undefined") {
					continue;
				}
				$('#merlinclash_acl_type_' + i).val(db_acl["merlinclash_acl_type_" + i]);
				// $('#merlinclash_acl_content_' + i).val(decodeURIComponent(Base64.decode(db_acl["merlinclash_acl_content_" + i])));
				var decoded = decodeURIComponent(Base64.decode(db_acl["merlinclash_acl_content_" + i]));
				// 去除所有控制字符和不可见字符
				decoded = decoded.replace(/[\x00-\x1F\x7F-\x9F]/g, '');
				$('#merlinclash_acl_content_' + i).val(decoded);
				$('#merlinclash_acl_lianjie_' + i).val(db_acl["merlinclash_acl_lianjie_" + i]);
				// $('#merlinclash_acl_protocol_' + i).val(db_acl["merlinclash_acl_protocol_" + i]);

			}
			//after table generated and value filled, set default value for first line_image1
			// $('#merlinclash_acl_protocol').val("none");
		}
	});
	}
	function addTr() {
		if(!$.trim($('#merlinclash_acl_type').val())){
			alert("类型不能为空！");
			return false;
		}
		if(!$.trim($('#merlinclash_acl_content').val())){
			alert("内容不能为空！");
			return false;
		}
		if(!$.trim($('#merlinclash_acl_lianjie').val())){
			alert("连接方式不能为空！");
			return false;
		}
		var acls = {};
		var p = "merlinclash_acl";
		acl_node_max += 1;
		var params = ["type", "content", "lianjie"];
		for (var i = 0; i < params.length; i++) {
			acls[p + "_" + params[i] + "_" + acl_node_max] = Base64.encode(encodeURIComponent($('#' + p + "_" + params[i]).val()));
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_saveacls.sh", "params":["save"], "fields": acls};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			error: function(xhr) {
				console.log("error in posting config of table");
			},
			success: function(response) {
				refresh_acl_table();
				proxygroup_select_get();
				proxytype_select_get();
				// $('#merlinclash_acl_protocol').val("none");
			}
		});
		aclid = 0;
	}
	function delTr(o) {
		var id = $(o).attr("id");
		var ids = id.split("_");
		var p = "merlinclash_acl";
		id = ids[ids.length - 1];
		var acls = {};
		var params = ["type", "content", "lianjie"];
		for (var i = 0; i < params.length; i++) {
			db_merlinclash[p + "_" + params[i] + "_" + id] = acls[p + "_" + params[i] + "_" + id] = "";
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "clash_saveacls.sh", "params":["del"], "fields": acls};

		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				proxygroup_select_get();
				proxytype_select_get();
				refresh_acl_table();

			}
		});
	}
	//-----------------------删除所有自定规则 开始----------------------//
	function delallaclconfigs() {
		layer.confirm('<li>确定删除所有自定义规则吗？</li>', {
			shade: 0.8,
		}, function(index) {
			getaclconfigsmax();
			if(acl_node_max != "undefined"){
				var p = "merlinclash_acl";
				acl_node_del = acl_node_max;
				var acls = {};
				var params = ["type", "content", "lianjie"];
				for (var j=acl_node_del; j>0; j--) {
					for (var i = 0; i < params.length; i++) {
						db_merlinclash[p + "_" + params[i] + "_" + j] = acls[p + "_" + params[i] + "_" + j] = "";
					}
				}
				acl_node_max = 0;
				var id = parseInt(Math.random() * 100000000);
				var postData = {"id": id, "method": "clash_saveacls.sh", "params":["del"], "fields": acls};

				intoQueue({
					type: "POST",
					cache:false,
					url: "/_api/",
					data: JSON.stringify(postData),
					dataType: "json",
					success: function(response) {
						refresh_acl_table();
						refreshpage();
					}
				});
			}
			layer.close(index);
			return true;
		}, function(index) {
			layer.close(index);
			return false;
		});
	}
	function getaclconfigsmax(){
		intoQueue({
			type: "GET",
			url: "/_api/merlinclash_acl",
			dataType: "json",
			async: false,
			success: function(data) {
				db_acls = data.result[0];
				getACLConfigs();
				//after table generated and value filled, set default value for first line_image1
			}
		});
	}
	//-----------------------删除所有自定规则 结束----------------------//	

function refresh_acl_html(db_acl) {
    	acl_confs = getACLConfigs(db_acl);
    	var n = 0;
    	for (var i in acl_confs) {
    	    n++;
    	}
    	var code = '';
    	code += '<div id="merlinclash_cusrule_table">'
    	// acl table th
    	code += '<table width="750px" border="0" align="center" cellpadding="4" cellspacing="0" class="FormTable_table acl_lists" style="margin:-1px 0px 0px 0px;">'
    	code += '<tr>'
    	code += '<th width="20%" style="text-align: center; vertical-align: middle;"><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(2)">类型</a></th>'
    	code += '<th width="30%" style="text-align: center; vertical-align: middle;"><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(3)">内容</a></th>'
	    code += '<th width="20%" style="text-align: center; vertical-align: middle;"><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(4)">连接方式</a></th>'
    	code += '<th width="8%">操作</th>'
    	code += '</tr>'
	    code += '</table>'
    	// acl table input area
	    code += '<table id="ACL_table" width="750px" border="0" align="center" cellpadding="4" cellspacing="0" class="list_table acl_lists" style="margin:-1px 0px 0px 0px;">'
	    code += '<tr>'
	    //类型
	    code += '<td width="20%">'
	    code += '<select id="merlinclash_acl_type" style="width:120px;margin:0px 0px 0px 2px;text-align:center;text-align-last:center;padding-left: 12px;" class="input_option">'
	    code += '</select>'
    	code += '</td>'
    	//内容
    	code += '<td width="30%">'
    	code += '<input type="text" id="merlinclash_acl_content" class="input_15_table" maxlength="9999" style="width:200px;text-align:center" placeholder="" />'
    	code += '</td>'
    	//连接
    	code += '<td width="20%">'
    	code += '<select id="merlinclash_acl_lianjie" style="width:120px;margin:0px 0px 0px 2px;text-align:center;text-align-last:center;padding-left: 12px;" class="input_option">'
    	code += '</select>'
    	code += '</td>'

    	// add/delete 按钮
    	code += '<td width="8%">'
    	code += '<input style="margin-left: 6px;margin: -2px 0px -4px -2px;" type="button" class="add_btn" onclick="addTr()" value="" />'
    	code += '</td>'
    	code += '</tr>'
    	// acl table rule area
    	// 获取所有键并保持原顺序（正序）
    	var fields = [];
    	for (var field in acl_confs) {
	        fields.push(field);
    	}
    	// 直接按原顺序遍历（正序）
    	for (var i = 0; i < fields.length; i++) {
        	var field = fields[i];
        	var ac = acl_confs[field];
        	code += '<tr id="acl_tr_' + ac["acl_node"] + '">';
        	code += '<td width="20%" id="merlinclash_acl_type_' + ac["acl_node"] + '">' + ac["type"] + '</td>';
        	code += '<td width="40%">';
        	code += '<input type="text" id="merlinclash_acl_content_' + ac["acl_node"] + '" class="input_option_2" maxlength="9999" placeholder="" />';
        	code += '</td>';
        	code += '<td width="20%" id="merlinclash_acl_lianjie_' + ac["acl_node"] + '">' + ac["lianjie"] + '</td>';
        	code += '<td width="10%">';
        	code += '<input style="margin: -2px 0px -4px -2px;" id="acl_node_' + ac["acl_node"] + '" class="remove_btn" type="button" onclick="delTr(this);" value="">'
        	code += '</td>';
        	code += '</tr>';
    	}
    	code += '</table>';
    	code += '</div>'
    	$(".acl_lists").remove();
    	$('#merlinclash_acl_table').after(code);
	}
function getACLConfigs(db_acl) {
    var dict = {};
    for (var field in db_acl) {
        names = field.split("_");
        dict[names[names.length - 1]] = 'ok';
    }
    acl_confs = {};
    var p = "merlinclash_acl";
    var params = ["type", "content", "lianjie"];
    for (var field in dict) {
        var obj = {};
        for (var i = 0; i < params.length; i++) {
            var ofield = p + "_" + params[i] + "_" + field;
            if (typeof db_acl[ofield] == "undefined") {
                obj = null;
                break;
            }
            var value = decodeURIComponent(Base64.decode(db_acl[ofield]));
            // 对 lianjie 字段进行特殊处理，将 + 替换为空格
            if (params[i] === "lianjie") {
                value = value.replace(/\+/g, ' ');
            }
            obj[params[i]] = value;
        }
        if (obj != null) {
            var node_a = parseInt(field);
            if (node_a > acl_node_max) {
                acl_node_max = node_a;
            }
            obj["acl_node"] = field;
            acl_confs[field] = obj;
        }
    }
    return acl_confs;
}
	//----------------------------自定规则代码部分END--------------------------------------//
	//----------------------------访问控制部分BEGIN--------------------------------//
	function getnoKPACLConfigs() {
		var dict = {};
		for (var field in db_nokpacl) {
			names = field.split("_");
			dict[names[names.length - 1]] = 'ok';
		}
		nokpacl_confs = {};
		var p = "merlinclash_nokpacl";
		var params = ["ip", "mac", "port", "mode"];
		for (var field in dict) {
			var obj = {};
			if (typeof db_nokpacl[p + "_name_" + field] == "undefined") {
				obj["name"] = db_nokpacl[p + "_ip_" + field];
			} else {
				obj["name"] = db_nokpacl[p + "_name_" + field];
			}
			for (var i = 0; i < params.length; i++) {
				var ofield = p + "_" + params[i] + "_" + field;
				if (typeof db_nokpacl[ofield] == "undefined") {
					obj = null;
					break;
				}
				obj[params[i]] = db_nokpacl[ofield];
			}
			if (obj != null) {
				var node_a = parseInt(field);
				if (node_a > nokpacl_node_max) {
					nokpacl_node_max = node_a;
				}
				obj["nokpacl_node"] = field;
				nokpacl_confs[field] = obj;
			}
		}
		return nokpacl_confs;
	}
	function addnokpaclTr() {
		if(!$.trim($('#merlinclash_nokpacl_ip').val())){
			alert("主机IP地址不能为空！");
			return false;
		}
		if(!$.trim($('#merlinclash_nokpacl_name').val())){
			alert("主机别名不能为空！");
			return false;
		}
		var nokpacls = {};
		var p = "merlinclash_nokpacl";
		nokpacl_node_max += 1;
		var params = ["ip", "mac", "name", "port", "mode"];
		for (var i = 0; i < params.length; i++) {
			nokpacls[p + "_" + params[i] + "_" + nokpacl_node_max] = $('#' + p + "_" + params[i]).val();
		}
		if(nokpacls["merlinclash_nokpacl_mac_" + nokpacl_node_max] ==""){
			nokpacls["merlinclash_nokpacl_mac_" + nokpacl_node_max] = " "
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "dummy_script.sh", "params":[], "fields": nokpacls};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			error: function(xhr) {
				console.log("error in posting config of table");
			},
			success: function(response) {
				refresh_nokpacl_table();
				E("merlinclash_nokpacl_name").value = ""
				E("merlinclash_nokpacl_ip").value = ""
				E("merlinclash_nokpacl_mac").value = ""
			}
		});
		nokpaclid = 0;
	}
	function delnokpaclTr(o) {
		var id = $(o).attr("id");
		var ids = id.split("_");
		var p = "merlinclash_nokpacl";
		id = ids[ids.length - 1];
		var nokpacls = {};
		var params = ["ip", "mac", "name", "port", "mode"];
		for (var i = 0; i < params.length; i++) {
			db_merlinclash[p + "_" + params[i] + "_" + id] = nokpacls[p + "_" + params[i] + "_" + id] = "";
		}
		var id = parseInt(Math.random() * 100000000);
		var postData = {"id": id, "method": "dummy_script.sh", "params":[], "fields": nokpacls};
		intoQueue({
			type: "POST",
			cache:false,
			url: "/_api/",
			data: JSON.stringify(postData),
			dataType: "json",
			success: function(response) {
				refresh_nokpacl_table();
			}
		});
	}
	function refresh_nokpacl_table(q) {
		intoQueue({
			type: "GET",
			url: "/_api/merlinclash_nokpacl",
			dataType: "json",
			async: false,
			success: function(data) {
				db_nokpacl = data.result[0];
				refresh_nokpacl_html();
				//write default rule port
				//console.log(db_nokpacl["merlinclash_nokpacl_default_port"]);
				if (typeof db_nokpacl["merlinclash_nokpacl_default_port"] != "undefined") {
					$('#merlinclash_nokpacl_default_port').val(db_nokpacl["merlinclash_nokpacl_default_port"]);
				} else {
					//console.log("进来这里");
					$('#merlinclash_nokpacl_default_port').val("all");
				}
				//write dynamic table value
				for (var i = 1; i < nokpacl_node_max + 1; i++) {
					$('#merlinclash_nokpacl_mode_' + i).val(db_nokpacl["merlinclash_nokpacl_mode_" + i]);
					$('#merlinclash_nokpacl_port_' + i).val(db_nokpacl["merlinclash_nokpacl_port_" + i]);
					$('#merlinclash_nokpacl_name_' + i).val(db_nokpacl["merlinclash_nokpacl_name_" + i]);
					$('#merlinclash_nokpacl_mac_' + i).val(db_nokpacl["merlinclash_nokpacl_mac_" + i]);
				}
				if(db_merlinclash["merlinclash_nokpacl_default_mode"]){
					$('#merlinclash_nokpacl_default_mode').val(db_merlinclash["merlinclash_nokpacl_default_mode"]);
				}
				//set default rule port to all when game mode enabled
				set_nodefault_port();
				//after table generated and value filled, set default value for first line_image1
				$('#merlinclash_nokpacl_mode').val("0");
				$('#merlinclash_nokpacl_port').val("all");
				set_nomode_1();
			}
		});
	}
	function set_nomode_1() {
		if ($('#merlinclash_nokpacl_mode').val() == 0) {
			$("#merlinclash_nokpacl_port").val("all");
			E("merlinclash_nokpacl_port").disabled = true;
			E("merlinclash_nokpacl_port").title = "不可更改，不走代理下默认全端口";
		} else if ($('#merlinclash_nokpacl_mode').val() == 1) {
			$("#merlinclash_nokpacl_port").val("80,443");
			E("merlinclash_nokpacl_port").disabled = false;
			E("merlinclash_nokpacl_port").title = "";
		}
	}
	function set_nomode_2(o) {
		var id2 = $(o).attr("id");
		var ids2 = id2.split("_");
		id2 = ids2[ids2.length - 1];
		if ($(o).val() == 0) {
			$("#merlinclash_nokpacl_port_" + id2).val("all");
			E("merlinclash_nokpacl_port_" + id2).readOnly = "readonly";
		} else if ($(o).val() == 1) {
			$("#merlinclash_nokpacl_port_" + id2).val("all");
			E("merlinclash_nokpacl_port_" + id2).readOnly = "";
		} else if ($(o).val() == 2) {
			$("#merlinclash_nokpacl_port_" + id2).val("22,80,443");
		}
	}
	function set_nodefault_port() {
		//console.log($('#merlinclash_nokpacl_default_mode').val());
		if ($('#merlinclash_nokpacl_default_mode').val() == 0) {
			$("#merlinclash_nokpacl_default_port").val("all");
			E("merlinclash_nokpacl_default_port").readOnly = "readonly";
			E("merlinclash_nokpacl_default_port").title = "不可更改，不走代理下默认全端口";
		} else {

			//$("#merlinclash_nokpacl_default_port").val("all");
			//console.log(db_merlinclash["merlinclash_nokpacl_default_port"]);
			if(db_merlinclash["merlinclash_nokpacl_default_port"]){
				$("#merlinclash_nokpacl_default_port").val(db_merlinclash["merlinclash_nokpacl_default_port"]);
			}else{
				$("#merlinclash_nokpacl_default_port").val("all");
			}

			E("merlinclash_nokpacl_default_port").readOnly = "";
			E("merlinclash_nokpacl_default_port").title = "";
		}
	}
	function refresh_nokpacl_html() {
		nokpacl_confs = getnoKPACLConfigs();
		var n = 0;
		for (var i in nokpacl_confs) {
			n++;
		}
		var code = '';
		// acl table th
		code += '<table width="750px" border="0" align="center" cellpadding="4" cellspacing="0" class="FormTable_table nokpacl_lists" style="margin:-1px 0px 0px 0px;">'
		code += '<tr>'
		code += '<th width="20%">主机IP地址</th>'
		code += '<th width="20%">主机MAC地址</th>'
		code += '<th width="22%">主机别名</th>'
		code += '<th width="15%">访问控制</th>'
		code += '<th width="15%">目标端口</th>'
		code += '<th width="8%">操作</th>'
		code += '</tr>'
		code += '</table>'
		// acl table input area
		code += '<table id="noKPACL_table" width="750px" border="0" align="center" cellpadding="4" cellspacing="0" class="list_table nokpacl_lists" style="margin:-1px 0px 0px 0px;">'
		code += '<tr>'
		// ip addr merlinclash_nokpacl_ip 主机IP地址
		code += '<td width="20%">'
		code += '<input type="text" maxlength="18" class="input_15_table" id="merlinclash_nokpacl_ip" align="left" style="float:left;width:110px;margin-left:0px;text-align:center" autocomplete="off" onClick="hidenokpClients_Block();" autocorrect="off" autocapitalize="off">'
		code += '<img id="pull_arrow" height="14px;" src="images/arrow-down.gif" align="right" onclick="pullnokpLANIPList(this);" title="<#select_IP#>">'
		code += '<div id="nokpClientList_Block" class="clientlist_dropdown" style="margin-left:2px;margin-top:25px;"></div>'
		code += '</td>'
		// name merlinclash_nokpacl_mac 主机MAC地址
		code += '<td width="20%">'
		code += '<input type="text" id="merlinclash_nokpacl_mac" class="input_15_table" maxlength="50" style="width:133px;text-align:center" placeholder="" />'
		code += '</td>'
		// name merlinclash_kpacl_name 主机别名
		code += '<td width="22%">'
		code += '<input type="text" id="merlinclash_nokpacl_name" class="input_15_table" maxlength="50" style="width:133px;text-align:center" placeholder="" />'
		code += '</td>'
		// mode merlinclash_kpacl_mode 访问控制
		code += '<td width="15%">'
		code += '<select id="merlinclash_nokpacl_mode" style="width:100px;margin:0px 0px 0px 2px;text-align:center;text-align-last:center;padding-left: 0px;" class="input_option" onchange="set_nomode_1(this);">'
		code += '<option value="0">不通过代理</option>'
		code += '<option value="1">通过clash</option>'
		code += '</select>'
		code += '</td>'
		// port merlinclash_kpacl_port 目标端口
		code += '<td width="15%">'
		code += '<select id="merlinclash_nokpacl_port" style="width:100px;margin:0px 0px 0px 2px;text-align-last:center;padding-left: 0px;" class="input_option">'
		code += '<option value="all">all</option>'
		code += '<option value="80,443">80,443</option>'
		code += '<option value="22,80,443">22,80,443</option>'
		code += '</select>'
		code += '</td>'
		// add/delete 按钮
		code += '<td width="8%">'
		code += '<input style="margin-left: 6px;margin: -2px 0px -4px -2px;" type="button" class="add_btn" onclick="addnokpaclTr()" value="" />'
		code += '</td>'
		code += '</tr>'
		// acl table rule area
		for (var field in nokpacl_confs) {
			var nokp = nokpacl_confs[field];
			code += '<tr id="nokpacl_tr_' + nokp["nokpacl_node"] + '">';
			// ip merlinclash_nokpacl_ip 主机IP地址
			code += '<td width="20%">' + nokp["ip"] + '</td>';
			//merlinclash_nokpacl_mac 主机MAC地址
			code += '<td width="20%">';
			code += '<input type="text" placeholder="' + nokp["nokpacl_node"] + '号机" id="merlinclash_nokpacl_mac_' + nokp["nokpacl_node"] + '" name="merlinclash_nokpacl_mac_' + nokp["nokpacl_node"] + '" class="input_option_2" maxlength="50" style="width:133px;" placeholder="" />';
			code += '</td>';
			//merlinclash_nokpacl_name 主机别名
			code += '<td width="22%">';
			code += '<input type="text" placeholder="' + nokp["nokpacl_node"] + '号机" id="merlinclash_nokpacl_name_' + nokp["nokpacl_node"] + '" name="merlinclash_nokpacl_name_' + nokp["nokpacl_node"] + '" class="input_option_2" maxlength="50" style="width:133px;" placeholder="" />';
			code += '</td>';
			//merlinclash_nokpacl_mode 访问控制
			code += '<td width="15%">';
			code += '<select id="merlinclash_nokpacl_mode_' + nokp["nokpacl_node"] + '" name="merlinclash_nokpacl_mode_' + nokp["nokpacl_node"] + '" style="width:100px;margin:0px 0px 0px 2px;" class="sel_option" onchange="set_nomode_2(this);">';
			code += '<option value="0">不通过代理</option>';
			code += '<option value="1">通过clash</option>';
			code += '</select>'
			code += '</td>';
			//merlinclash_nokpacl_port 目标端口
			code += '<td width="15%">';
			if (nokp["mode"] == 0) {
				code += '<input type="text" id="merlinclash_nokpacl_port_' + nokp["nokpacl_node"] + '" name="merlinclash_nokpacl_port_' + nokp["nokpacl_node"] + '" class="input_option_2" maxlength="50" style="width:100px;" title="不可更改，不通过clash下默认全端口" readonly = "readonly" />';
			} else {
				code += '<input type="text" id="merlinclash_nokpacl_port_' + nokp["nokpacl_node"] + '" name="merlinclash_nokpacl_port_' + nokp["nokpacl_node"] + '" class="input_option_2" maxlength="50" style="width:100px;" placeholder="" />';
			}
			code += '</td>';
			//按钮
			code += '<td width="8%">';
			code += '<input style="margin: -2px 0px -4px -2px;" id="nokpacl_node_' + nokp["nokpacl_node"] + '" class="remove_btn" type="button" onclick="delnokpaclTr(this);" value="">'
			code += '</td>';
			code += '</tr>';
		}
		//底行
		code += '<tr>';
		//所有主机
		if (n == 0) {
			code += '<td width="20%">所有主机</td>';
		} else {
			code += '<td width="20%">其它主机</td>';
		}
		//默认规则
		code += '<td width="20%">默认规则</td>';
		//默认规则
		if (n == 0) {
			code += '<td width="20%">所有主机</td>';
		} else {
			code += '<td width="20%">其它主机</td>';
		}
		//访问控制

		code += '<td width="15%">';
		code += '<select id="merlinclash_nokpacl_default_mode" style="width:100px;margin:0px 0px 0px 2px;" class="sel_option" onchange="set_nodefault_port();">';
		code += '<option value="0">不通过代理</option>';
		code += '<option value="1" selected>通过clash</option>';
		code += '</select>';
		code += '</td>';

		//默认端口
		code += '<td width="15%">';
		code += '<input type="text" id="merlinclash_nokpacl_default_port" class="input_option_2" maxlength="50" style="width:100px;" placeholder="" />';
		code += '</td>';
		//按钮为空
		code += '<td width="8%">';
		code += '</td>';
		code += '</tr>';
		code += '</table>';

		$(".nokpacl_lists").remove();
		$('#merlinclash_nokpacl_table').after(code);

		showDropdownClientList('setnokpClientIP', 'ip>mac>name', 'all', 'nokpClientList_Block', 'pull_arrow', 'online');
	}
	function setnokpClientIP(ip, mac, name) {
		E("merlinclash_nokpacl_ip").value = ip;
		E("merlinclash_nokpacl_mac").value = mac;
		E("merlinclash_nokpacl_name").value = name;
		hidenokpClients_Block();
	}
	function pullnokpLANIPList(obj) {
		var element = E('nokpClientList_Block');
		var isMenuopen = element.offsetWidth > 0 || element.offsetHeight > 0;
		if (isMenuopen == 0) {
			obj.src = "/images/arrow-top.gif"
			element.style.display = 'block';
		} else{
			hidenokpClients_Block();
		}
	}
	function hidenokpClients_Block() {
		E("pull_arrow").src = "/images/arrow-down.gif";
		E('nokpClientList_Block').style.display = 'none';
	}
	//----------------------------访问控制部分END----------------------------------//

	var merlinclash = {
		checkIP: () => {
		},
	}
	
	// 订阅链接生成助手弹窗相关函数
	function showSubLinkGenerator() {
		document.getElementById('subLinkGeneratorModal').style.display = 'block';
		document.getElementById('subLinkModalOverlay').style.display = 'block';
		parseExistingLinks();
	}
	
	function parseExistingLinks() {
		var linksText = document.getElementById('merlinclash_sub_links').value.trim();
		if (!linksText) return;
		
		var tbody = document.querySelector('#subLinkGeneratorModal tbody');
		tbody.innerHTML = '';
		
		var links = linksText.split('|');
		for (var i = 0; i < links.length; i++) {
			var link = links[i].trim();
			if (!link) continue;
			
			var url = link;
			var name = '';
			var ua = '';
			
			var nameMatch = link.match(/\(([^)]+)\)/);
			if (nameMatch) {
				name = nameMatch[1];
				url = url.replace(/\([^)]+\)/, '');
			}
			
			var uaMatch = link.match(/<([^>]+)>/);
			if (uaMatch) {
				ua = uaMatch[1];
				url = url.replace(/<[^>]+>/, '');
			}
			
			addSubLinkRowWithData(url, name, ua);
		}
		
		if (tbody.children.length === 0) {
			addSubLinkRow();
		}
	}
	
	function addSubLinkRowWithData(url, name, ua) {
		var tbody = document.querySelector('#subLinkGeneratorModal tbody');
		var row = document.createElement('tr');
		row.innerHTML = 
			'<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="机场名称(选填)" value="' + escapeHtml(name) + '"></td>' +
			'<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="https://abc.com 或 ss://xxxxxxx(必填)" value="' + escapeHtml(url) + '"></td>' +
			'<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="clash-verge/v2.4.7(选填)" value="' + escapeHtml(ua) + '"></td>' +
			'<td style="text-align: center;"><input class="remove_btn" type="button" onclick="removeSubLinkRow(this)"></td>';
		tbody.appendChild(row);
	}
	
	function escapeHtml(str) {
		if (!str) return '';
		return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
	}
	
	function hideSubLinkGenerator() {
		document.getElementById('subLinkGeneratorModal').style.display = 'none';
		document.getElementById('subLinkModalOverlay').style.display = 'none';
	}
	
	function addSubLinkRow() {
		var tbody = document.getElementById('subLinkTableBody');
		var row = document.createElement('tr');
		row.innerHTML = '<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="机场名称(选填)"></td>' +
						'<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="https://abc.com 或 ss://xxxxxxx(必填)"></td>' +
						'<td><input type="text" class="input_15_table" style="width: 95%;" placeholder="clash-verge/v2.4.7(选填)"></td>' +
						'<td style="text-align: center;"><input class="remove_btn" type="button" onclick="removeSubLinkRow(this)"></td>';
		tbody.appendChild(row);
	}
	
	function removeSubLinkRow(btn) {
		var row = btn.parentNode.parentNode;
		var tbody = row.parentNode;
		if (tbody.children.length > 1) {
			tbody.removeChild(row);
		}
	}
	
	function generateSubLinks() {
		var rows = document.getElementById('subLinkTableBody').getElementsByTagName('tr');
		var links = [];
		
		for (var i = 0; i < rows.length; i++) {
			var inputs = rows[i].getElementsByTagName('input');
			var name = inputs[0].value.trim();
			var url = inputs[1].value.trim();
			var ua = inputs[2].value.trim();
			
			if (!url) {
				alert('第 ' + (i + 1) + ' 行的订阅链接不能为空！');
				return;
			}
			
			var link = url;
			if (name) {
				link += '(' + name + ')';
			}
			if (ua) {
				link += '<' + ua + '>';
			}
			links.push(link);
		}
		
		document.getElementById('merlinclash_sub_links').value = links.join('|');
		hideSubLinkGenerator();
	}
function set_skin(){
	var SKN = '<% nvram_get("sc_skin"); %>';
	if(SKN){
		$("#scapp").attr("skin", SKN);
	}
}
</script>
</head>
<body onload="init();" id="scapp" scskin="swrt" skin="ASUSWRT">
	<div id="TopBanner"></div>
	<div id="Loading" class="popup_bg"></div>
	<div id="LoadingBar" class="popup_bar_bg_ks" style="z-index: 200;" >
		<table cellpadding="5" cellspacing="0" id="loadingBarBlock" class="loadingBarBlock" align="center">
			<tr>
				<td height="100">
					<div id="loading_block3" style="margin:10px auto;margin-left:10px;width:85%; font-size:12pt;"></div>
					<div id="loading_block2" style="margin:10px auto;width:95%;"></div>
					<div id="log_content2" style="margin-left:15px;margin-right:15px;margin-top:10px;overflow:hidden">
						<textarea cols="50" rows="30" wrap="off" readonly="readonly" id="log_content3" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" style="border:1px solid #000;width:99%; font-family:'Lucida Console'; font-size:11px;background:transparent;color:#FFFFFF;outline: none;padding-left:3px;padding-right:22px;overflow-x:hidden"></textarea>
					</div>
					<div id="ok_button" class="apply_gen" style="background: #000;display: none;">
						<input id="ok_button1" class="button_gen" type="button" onclick="hideMCLoadingBar()" value="确定">
					</div>
				</td>
			</tr>
		</table>
	</div>
	<table class="content" align="center" cellpadding="0" cellspacing="0">
		<tr>
			<td width="17">&nbsp;</td>
			<td valign="top" width="202">
				<div id="mainMenu"></div>
				<div id="subMenu"></div>
			</td>
			<td valign="top">
				<div id="tabMenu" class="submenuBlock"></div>
				<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0" style="display: block;">
					<tr>
						<td align="left" valign="top">
							<div>
								<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
									<tr>
										<td bgcolor="#4D595D" colspan="3" valign="top">
											<div>&nbsp;</div>
											<div class="formfonttitle">Magic Catling 2</div>
											<div style="float:right; width:15px; height:25px;margin-top:-20px">
												<img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'"></img>
											</div>
											<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
											<div class="SimpleNote" id="head_illustrate"><i></i>
												<p>Magic Catling2</u></em></a>是一个基于<a href='https://github.com/MetaCubeX/mihomo' target='_blank'><em><u>Mihomo内核</u></em></a>的代理程序，支持<em>SS</em>、<em>SSR</em>、<em>Vmess</em>、<em>Vless</em>、<em>Trojan</em>、<em>Hysteria</em>等协议科学上网。</p>
												<p>&nbsp;</p>
												<p id="showmsg1"></p>
												<p id="showmsg2"></p>
												<p id="showmsg3"></p>
												<p id="showmsg4"></p>
												<p id="showmsg5"></p>
												<p id="showmsg6"></p>
												<p id="showmsg7"></p>
												<p id="showmsg8"></p>
												<p id="showmsg9"></p>
												<p id="showmsg10"></p>
											</div>
											<!-- this is the popup area for process status -->
											<div id="detail_status"  class="content_status" style="box-shadow: 3px 3px 10px #000;margin-top: -20px;display: none;">
												<div class="user_title">【Magic Catling】状态检测</div>
												<div style="margin-left:15px"><i>&nbsp;&nbsp;目前本功能支持Magic Catling相关进程状态和iptables表状态检测。</i></div>
												<div style="margin: 10px 10px 10px 10px;width:98%;text-align:center;overflow:hidden">
													<textarea cols="63" rows="36" wrap="off" id="proc_status" style="width:98%;padding-left:13px;padding-right:33px;border:0px solid #222;font-family:'Lucida Console'; font-size:11px;background: transparent;color:#FFFFFF;outline: none;overflow-x:hidden;" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false"></textarea>
												</div>
												<div class="apply_gen" style="margin-top:5px;padding-bottom:10px;width:100%;text-align:center;">
													<input class="button_gen" type="button" onclick="close_proc_status();" value="返回主界面">
												</div>
											</div>
											<!-- 通用编辑框-->
											<div id="common_text_editor" class="contentMKP_qis" style="box-shadow: 3px 3px 10px #000;margin-top: -65px;display: none;">
												<div class="user_title">编辑<span id="common_text_editor_title">未知</span></div>
												<div style="margin-left:15px"><i>1&nbsp;&nbsp;更改配置内容后，需要重启Magic Catling才能生效；</i></div>
												<div style="margin-left:15px"><i>2&nbsp;&nbsp;<span id="common_text_editor_content">更多设置内容，请查阅https://docs.metacubex.one/</span></i></div>
												<div style="margin-left:15px"><i>3&nbsp;&nbsp;由于固件限制，文本框内容最多支持约2000个字符，超出后无法保存；</i></div>
												<div style="margin-left:15px"><i>4&nbsp;&nbsp;首次加载较慢！如果内容为空，请关闭弹窗尝试重新打开。</i></div>
												<div style="margin: 10px 10px 10px 10px;width:98%;text-align:center;">
													<textarea cols="63" rows="16" wrap="off" id="common_text_editor_text" autocomplete="off" autocorrect="off"
													autocapitalize="off" spellcheck="false"
													style="width: 900px;height:400px ;background: black; color: white; resize: none;"></textarea>
												</div>
												<div class="apply_gen" style="margin-top:5px;padding-bottom:10px;width:100%;text-align:center;">
													<input id="common_text_editor_save" class="button_gen" type="button"  value="保存设置">
													<input id="edit_node" class="button_gen" type="button" onclick="common_text_editor_close();" value="返回主界面">
												</div>
											</div>
											<div id="merlinclash_switch_show" style="margin:-1px 0px 0px 0px;">
												<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="merlinclash_switch_table">
													<thead>
														<tr>
															<td colspan="2">状态</td>
														</tr>
													</thead>
													<tr>
														<th class="sp_bottom_line" id="merlinclash_switch">总开关</th>
														<td class="sp_bottom_line" colspan="2">
															<div class="switch_field" style="display:table-cell;float: left;">
																<label for="merlinclash_enable">
																	<input id="merlinclash_enable" onclick="apply()" class="switch" type="checkbox" style="display: none;">
																	<div class="switch_container" >
																		<div class="switch_bar"></div>
																		<div class="switch_circle transition_style">
																			<div></div>
																		</div>
																	</div>
																</label>
															</div>
															<div id="merlinclash_version_show" style="display:table-cell;float: left;position: absolute;margin-left:70px;padding: 5.5px 0px;">
																<a class="hintstyle">
																	<i>当前版本：</i>
																</a>
															</div>
															<div id="merlinclash_restart" style="display:table-cell;float: left;position: absolute;margin-left:300px;padding: 5.5px 0px;">
																<a type="button" class="ks_btn" style="cursor:pointer" onclick="apply()" href="javascript:void(0);">重启&保存</a>
															</div>
															<div style="display:table-cell;float: left;margin-left:380px;position: absolute;padding: 5.5px 0px;">
																<a type="button" class="ks_btn" style="cursor:pointer" onclick="get_proc_status()" href="javascript:void(0);">详细状态</a>
															</div>
														</td>
													</tr>
													<tr id="clash_state">
														<th class="sp_bottom_line">运行状态</th>
														<td class="sp_bottom_line">
															<div style="display:table-cell;float: left;margin-left:0px;">
																<div id="merlinclash_core_version">
																	<span id="core_state1">clash：</span>
																</div>
																<span id="clash_state1">内核启动时间 - Waiting...</span>
																<br/>
																<span id="clash_state2">内核进程状态 - Waiting...</span>
																<br/>
																<span id="clash_state3">实时守护进程 - Waiting...</span>
															</div>
														</td>
													</tr>
													<tr id="ip_state">
														<th>连通检查</th>
														<td>
															<div style="padding-right: 20px;">
																<div style="display: flex;">
																	<div style="width: 61.8%">IP 地址检查</div>
																	<div style="width: 20%">网站访问检查</div>
																</div>
															</div>
															<div>
																<div style="display: flex;">
																	<div style="width: 61.8%">
																		<p><span class="ip-title">国内</span>:&nbsp;<span id="ip-ipipnet">Waiting....</span></p>
																		<p><span class="ip-title">海外</span>:&nbsp;<span id="ip-ipapi">Waiting....</span>&nbsp;<span id="ip-ipapi-geo"></span></p>
																	</div>
																	<div style="width: 40%">

																		<p><span class="ip-title">国内</span>&nbsp;:&nbsp;<span id="http-baidu">Waiting....</span></p>
																		<p><span class="ip-title">海外</span>&nbsp;:&nbsp;<span id="http-google">Waiting....</span></p>
																	</div>
																</div>
															</div>
														</td>
													</tr>
												</table>
											</div>

											<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
												<thead>
													<tr>
														<td colspan="2">控制</td>
													</tr>
												</thead>
												<tr id="yamlselect">
													<th>配置文件选择</th>
													<td colspan="2">
														<select id="merlinclash_set_yamlsel_start"  name="yamlsel" dataType="Notnull" msg="配置文件不能为空!" class="input_option" ></select>
													</td>
												</tr>

												<tr>
													<th>访问管理面板</th>
													<td colspan="2">
														<div class="merlinclash-btn-container" style="margin-top: 10px">
															<a type="button" id="zash" ></a>
															<p style="margin-top: 8px">只有在内核正常运行时才可以访问 管理面板</p>
														</div>
													</td>
												</tr>
											</table>
											<div id="tablets">
												<table style="margin:10px 0px 0px 0px;border-collapse:collapse" width="100%" height="37px">
													<tr>
														<td cellpadding="0" cellspacing="0" style="padding:0" border="1" bordercolor="#222">
															<input id="show_btn1" class="show-btn1" style="cursor:pointer" type="button" value="订阅管理" />
															<input id="show_btn0" class="show-btn0" style="cursor:pointer" type="button" value="DNS设置" />
															<input id="show_btn2" class="show-btn2" style="cursor:pointer" type="button" value="自定规则" />
															<input id="show_btn9" class="show-btn9" style="cursor:pointer" type="button" value="访问控制" />
															<input id="show_btn3" class="show-btn3" style="cursor:pointer" type="button" value="高级设置" />
															<input id="show_btn4" class="show-btn4" style="cursor:pointer" type="button" value="附加功能" />
															<input id="show_btn7" class="show-btn7" style="cursor:pointer" type="button" value="日志记录" />
															<input id="show_btn6" class="show-btn6" style="cursor:pointer" type="button" value="当前配置" />
														</td>
													</tr>
												</table>
											</div>
											<!--首页功能区-->
											<div id="tablet_0" style="display: none;">
												<div id="merlinclash-dns" style="margin:-1px 0px 0px 0px;">
													<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
														<thead>
															<tr>
																<td colspan="2">DNS方案</td>
															</tr>
														</thead>
														<tr id="dns_plan">
															<th class="sp_bottom_line"><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(1)">DNS方案</a></th>
															<td class="sp_bottom_line" colspan="2">
																<p style="color:#FC0">&nbsp;</p>
																<label>
																	<input id="merlinclash_dns_type" type="radio" name="dnsplan" value="rh" checked="checked" onclick="dnsplan_change('rh')">Redir-Host&nbsp;&nbsp;&nbsp;&nbsp;
																</label>
																<label>
																	<input id="merlinclash_dns_type" type="radio" name="dnsplan" value="fi" onclick="dnsplan_change('fi')">Fake-ip&nbsp;&nbsp;&nbsp;&nbsp;
																</label>
																<p style="color:#FC0">&nbsp;</p>																			
															</td>
														</tr>
														<tr id="dns_fakeipblack">
															<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(28)">黑名单设备解析服务器</a></th>
															<td colspan="2">
																<div class="SimpleNote" id="head_illustrate">
																	<input id="merlinclash_dns_fakeip_server" class="input_15_table" value="223.5.5.5">
																</div>
															</td>
														</tr>
														<tr>
															<th>自定义DNS</th>
															<td colspan="2">
																<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-top: 8px;margin-right: 20px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('dns_rh','Redir-Host');" >编辑Redir-Host</a>
																<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-top: 8px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('dns_fi','Fake-ip');" >编辑Fake-IP</a>
															</td>
														</tr>																			
													</table>
												</div>
												<div id="merlinclash-dns" style="margin:-1px 0px 0px 0px;">
													<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
														<thead>
															<tr>
																<td colspan="2">其他设置</td>
															</tr>
														</thead>			
														<tr id="dns_hijack">
															<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(12)">DNS劫持</a></th>
															<td colspan="2">
																<label for="merlinclash_dns_dnshijack_sw">
																	<input id="merlinclash_dns_dnshijack_sw" type="checkbox" name="dnshijack" class="switch" style="display: none;">
																	<div class="switch_container" >
																		<div class="switch_bar"></div>
																		<div class="switch_circle transition_style">
																			<div></div>
																		</div>
																	</div>
																</td>
															</tr>
															<tr id="dns_inclash">
																<th>路由自身DNS使用Clash设定</th>
																<td colspan="2">
																	<div class="switch_field" style="display:table-cell;float: left;">
																		<label for="merlinclash_dns_proxydns_sw">
																			<input id="merlinclash_dns_proxydns_sw" type="checkbox" name="cir" class="switch" style="display: none;">
																			<div class="switch_container" >
																				<div class="switch_bar"></div>
																				<div class="switch_circle transition_style">
																					<div></div>
																				</div>
																			</div>
																		</label>
																	</div>
																</td>
															</tr>
															<tr id="dns_clear">
																<th class="sp_bottom_line">清除路由自定义DNS</th>
																<td class="sp_bottom_line" colspan="2">
																	<div class="switch_field" style="display:table-cell;float: left;">
																		<label for="merlinclash_dns_cleardns_sw">
																			<input id="merlinclash_dns_cleardns_sw" type="checkbox" name="dnsclear" class="switch" style="display: none;">
																			<div class="switch_container" >
																				<div class="switch_bar"></div>
																				<div class="switch_circle transition_style">
																					<div></div>
																				</div>
																			</div>
																		</label>
																	</div>
																</td>
															</tr>
															<tr id="ena_sniffer">
																<th>Sniffer域名嗅探</th>
																<td colspan="2">
																	<div class="switch_field" style="display:table-cell;float: left;">
																		<label for="merlinclash_dns_sniffer_sw">
																			<input id="merlinclash_dns_sniffer_sw" type="checkbox" name="sniffer" class="switch" style="display: none;">
																			<div class="switch_container" >
																				<div class="switch_bar"></div>
																				<div class="switch_circle transition_style">
																					<div></div>
																				</div>
																			</div>
																		</label>
																	</div>
																	<input type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-bottom: -8px; margin-left: 20px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('sniffer','Sniffer域名嗅探');" value="内容编辑" />
																</td>
															</tr>
															<tr>
																<th>自定义Hosts</th>
																<td colspan="2">
																	<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-bottom: 8px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('hosts','Hosts');" >编辑Hosts</a>
																</td>
															</tr>	

														</table>
													</div>
												</div>

												<!--配置文件-->
												<div id="tablet_1" style="display: none;">
													<div style="margin:-1px 0px 0px 0px;" >
														<table  id="clashimport" style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
															<thead>
																<tr>
																	<td colspan="2">订阅配置</td>
																</tr>
															</thead>
															<tr>
																<th class="sp_bottom_line">
																	<p >&nbsp;</p>
																	<p >配置上传</p>
																	<br><em style="color: gold;">自定义Yaml配置文件</em>
																	<p >&nbsp;</p>
																</th>
																<td class="sp_bottom_line"colspan="2">
																	<div class="SimpleNote" style="display:table-cell;float: left; height: 110px; line-height: 110px; margin:-40px 0;">
																		<input type="file" id="clashconfig" size="50" name="file"/>
																		<span id="clashconfig_info" style="display:none;">完成</span>
																		<a type="button" style="vertical-align: middle; cursor:pointer;" id="clashconfig-btn-upload" class="ks_btn" onclick="upload_clashconfig()" >上传配置文件</a>
																	</div>
																</td>
															</tr>
															<tr id="subscribe">
																<th>
																	<p>&nbsp;</p>
																	<p><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(6)">配置订阅</a></p>
																	<br><em style="color: gold;">所有通用订阅&nbsp;|&nbsp;Clash专用订阅</em>
																	<p >&nbsp;</p>
																</th>
																<td>
																	<div class="SimpleNote" style="display:table-cell;float: left; position: relative;">
																		<textarea id="merlinclash_sub_links" warp="on" placeholder="请输入订阅连接，支持多个订阅地址（协议地址），格式如下：&#13;&#10;https://aaa.com|http://bbb.com|vemss://xxxxxx" type="text"></textarea>
																		<input type="button" id="subLinkHelperBtn" value="+" onclick="showSubLinkGenerator()" class="button-add" style="position: absolute; left: 12px; bottom: 7px; width: 24px; height: 24px; padding: 0; font-size: 18px; font-weight: bold; border: none; border-radius: 50%; cursor: pointer; text-align: center; line-height: 22px;">
																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 420px;" id="merlinclash_sub_duplicate">
																		<label>节点覆写：</label>
																		<label>
																		<span>添加Emoji:</span>
																		<input id="merlinclash_sub_emoji" type="checkbox" name="subconverter_emoji">
																		</label>
																		<label>
																		<span>&nbsp;&nbsp;&nbsp;跳过证书:</span>
																		<input id="merlinclash_sub_scv" type="checkbox" name="subconverter_scv">
																		</label>
																		<label>
																		<span>&nbsp;&nbsp;&nbsp;启用UDP:</span>
																		<input id="merlinclash_sub_udp" type="checkbox" name="subconverter_udp" checked="checked">
																		</label>
																		<label>
																		<span>&nbsp;&nbsp;&nbsp;启用TFO:</span>
																		<input id="merlinclash_sub_tfo" type="checkbox" name="subconverter_tfo">
																		</label>
																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 400px; line-height: 40px; " id="merlinclash_sub_filter">
																		<p><label>包含节点：</label>
																			<input id="merlinclash_sub_include" class="input_25_table" style="width:320px" placeholder="&nbsp;筛选包含关键字的节点名，支持正则">
																		</p>

																		<p><label>排除节点：</label>
																			<input id="merlinclash_sub_exclude" class="input_25_table" style="width:320px" placeholder="&nbsp;过滤包含关键字的节点名，支持正则">
																		</p>

																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 400px; line-height: 40px; ">
																		<p><label>订阅&nbsp;&nbsp;UA：</label>
																			<input id="merlinclash_sub_useragent" class="input_25_table" style="width:320px" placeholder="">
																		</p>
																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 400px; height: 30px; line-height: 30px; " id="merlinclash_sub_updatetime">

																		<label>定时更新：</label>
																		<select id="merlinclash_sub_updatecycle" style="width:328px;margin:0px 0px 0px 2px;text-align:left;padding-left: 5px;" class="input_option">
																			<option value="0">不更新</option>
																			<option value="86400">每天</option>
																			<option value="259200" selected>三天</option>
																			<option value="604800">一周</option>
																		</select>
																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 400px; height: 30px; line-height: 30px; ">

																		<label style="color: gold;">订阅规则：</label>
																		<select id="merlinclash_sub_type" style="width:328px;margin:0px 0px 0px 2px;text-align:left;padding-left: 5px;" class="input_option" onchange="subc_rule_change(this)">
																			<option value="MCrule">MC_常规规则</option>
																			<option value="MCrule_No">MC_常规_无测Ping</option>
																			<option value="MCrule_Media">MC_多媒体全量</option>
																			<option value="MCrule_Media_No">MC_多媒体全量_无测Ping</option>
																			<option value="MCrule_Media_AreaU">MC_多媒体全量_分地区_延迟最低</option>
																			<option value="MCrule_Media_AreaF">MC_多媒体全量_分地区_故障转移</option>
																			<option value="APrule">订阅原始规则</option>																		
																		</select>
																	</div>
																	<div class="SimpleNote" style="display:table-cell;float: left; width: 400px; height: 30px; line-height: 30px; ">
																		<label style="color: gold;">订阅名称：</label>
																			<input onkeyup="value=value.replace(/[^a-zA-Z0-9]/g,'')" id="merlinclash_sub_rename" maxlength="20" class="input_25_table" style="width:226px" placeholder="&nbsp;配置文件名称(支持20位数字/字母)">
																				<a type="button" style="vertical-align: middle; margin:-10px 10px;" class="ks_btn" style="cursor:pointer" onclick="get_online_yaml3('subscribe')" href="javascript:void(0);">&nbsp;&nbsp;开始订阅&nbsp;&nbsp;</a>
																	</div>
																</td>
															</tr>
														</table>

														<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
															<thead>
																<tr>
																	<td colspan="2">订阅设置</td>
																</tr>
															</thead>
																<tr id="delyamlselect">
																	<th class="sp_bottom_line">配置管理&nbsp;&nbsp;<span id="clash_yamlsel">当前配置为：</span></th>
																	<td class="sp_bottom_line" colspan="2">
																		<div class="SimpleNote" style="display:table-cell;float: left; height: 110px; line-height: 110px; margin:-40px 0;">
																			<select id="merlinclash_set_yamlsel_edit"  name="delyamlsel" dataType="Notnull" msg="配置文件不能为空!" class="input_option" onchange="del_yaml_sel_change(this)" ></select>
																				<a type="button" style="vertical-align: middle;" class="ks_btn" style="cursor:pointer" onclick="download_yaml_sel('downyaml')" href="javascript:void(0);">&nbsp;&nbsp;下载配置&nbsp;&nbsp;</a>
																				<a type="button" style="vertical-align: middle;" class="ks_btn" style="cursor:pointer" onclick="del_yaml_sel(0)" href="javascript:void(0);" >&nbsp;&nbsp;删除配置&nbsp;&nbsp;</a>
																				<a id="udpate_yaml_btn" type="button" style="vertical-align: middle; display: none;" class="ks_btn" style="cursor:pointer" onclick="update_yaml_sel(0)" href="javascript:void(0);" >&nbsp;&nbsp;更新配置&nbsp;&nbsp;</a>
																		</div>
																	</td>
																</tr>
																<tr>
																	<th>基础配置</th>
																	<td colspan="2">
																		<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-top: 8px;margin-left: 10px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('head','基础配置');" >编辑基础配置</a>
																	</td>
																</tr>	
														</table>
																		
													</div>
												</div>
																<!--日志记录-->
																<div id="tablet_7" style="display: none;">
																	<div id="merlinclash-notelog" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2"><em style="color: gold;">节点恢复日志/记录</em></td>
																				</tr>
																			</thead>
																		</table>
																		<div id="nodes_content" class="mc_outline" style="height: 160px;">
																			<textarea class="sbar" cols="63" rows="36" wrap="on" readonly="readonly" id="nodes_content1" style="margin: 0px; width: 709px; height: 150px; resize: none;"></textarea>
																		</div>
																	</div>
																	<div id="merlinclash-OPLOG" style="margin:5px 0px 0px 0px;">
																		<table style="margin:5px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2"><em style="color: gold;">操作日志</em></td>
																				</tr>
																			</thead>
																		</table>
																		<div id="log_content" class="mc_outline" style=" height: 550px;">
																			<textarea class="sbar" cols="63" rows="36" wrap="on" readonly="readonly" id="log_content1" style="margin: 0px; width: 709px; height: 545px; resize: none;"></textarea>
																		</div>
																	</div>
																</div>
																<!--自定规则-->
																<div id="tablet_2" style="display: none;">
																	<div id="merlinclash-iptbles" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2">IPtables前置分流</td>
																				</tr>
																			</thead>	
																			<!--绕行大陆IP-->
																			<tr id="china_ip_route">
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(17)">大陆IP不经过内核</a><span id="cirtag"></span></th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_chnroute_sw">
																							<input id="merlinclash_set_chnroute_sw" type="checkbox" name="cir" class="switch" style="display: none;">
																							<div class="switch_container" >
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th>自定义IPtables分流规则</th>
																				<td colspan="2">
																					<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-top: 8px;margin-right: 20px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('ipt_black','强制绕行规则');" >编辑强制绕行规则</a>
																					<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-top: 8px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('ipt_white','强制转发规则');" >编辑强制转发规则</a>
																				</td>
																			</tr>													
																		</table>
																	</div>				
																	<div id="custom_rule_plan">
																		<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2">自定Clash规则</td>
																				</tr>
																			</thead>
																			<tr id="cusrule_plan">
																				<th><a class="hintstyle" >自定规则模式</a></th>
																				<td colspan="2">
																					<label>
																						<input id="merlinclash_acl_plan" type="radio" name="cusruleplan" value="easy">简单模式
																						<input id="merlinclash_acl_plan" type="radio" name="cusruleplan" value="pro">专业模式
																					</label>
																					<script>
																						$("[name='cusruleplan']").on("change",
																							function (e) {
																								var mode_tag=$(e.target).val();
																								CUSRULE_MODE(mode_tag);
																							});
																						</script>
																					</td>
																				</tr>
																				<tr id="merlinclash_acl_edit_content">
																				<th>编辑自定义规则</th>
																				<td colspan="2">
																					<a type="button" id="merlinclash_clash_routerrules_open" class="ks_btn" style="margin-bottom: 8px; vertical-align: middle; cursor:pointer;" onclick="common_text_editor_open('acl','自定义规则');" >编辑自定义规则</a>
																				</td>
																			</tr>
																			</table>
																		</div>										
																		<div id="merlinclash_acl_table">
																		</div>
																		<div class="apply_gen">
																		<input class="button_gen" id="delallowneracls_button" type="button" onclick="delallaclconfigs()" value="删除所有规则">
																	    </div>
																		<div id="ACL_note" style="margin:10px 0 0 5px">
																			<div><i>&nbsp;&nbsp;1.[简单模式]必须正常启动一次，才可以正常添加自定义规则。</i></div>
																			<div><i>&nbsp;&nbsp;2.自定义规则跟随配置文件名称自动切换；编辑新规则后，必须重启插件后才能生效。</i></div>
																			<div><i>&nbsp;&nbsp;4.更多说明请点击表头查看，或者参阅【<a href="https://mcreadme.gitbook.io/mc/Advanced/Custom" target="_blank"><em><u>Magic Catling帮助文档</u></em></a>】。</i></div>
																			<div><i>&nbsp;</i></div>
																		</div>
																	</div>
																</div>
																
																<!--访问控制-->
																<div id="tablet_9" style="display: none;">
																	<div id="nokpacllist">
																		<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="merlinclash_switch_table">
																			<thead>
																				<tr>
																					<td colspan="2">访问控制</td>
																				</tr>
																			</thead>
																			<tr id="wb_method_tr">
																				<th>访问控制匹配方法</th>
																				<td>
																					<select name="merlinclash_nokpacl_method" id="merlinclash_nokpacl_method" class="input_option" style="width:127px;margin:0px 0px 0px 2px;" onchange="update_visibility();">
																						<option value="1" selected>IP + MAC匹配</option>
																						<option value="2">仅IP匹配</option>
																						<option value="3">仅MAC匹配</option>
																					</select>
																				</td>
																			</tr>
																		</table>
																		<div id="merlinclash_nokpacl_table">
																		</div>
																	</div>
																	<div id="DEVICE_note" style="margin:10px 0 0 5px">
																		<div><i>&nbsp;&nbsp;1.本功能通过iptables实现设备访问控制，优先级高于Clash访问控制规则。</i></div>
																		<div><i>&nbsp;&nbsp;2.使用MAC地址匹配时，请关闭iPhone等设备的随机MAC地址功能。</i></div>
																		<div><i>&nbsp;&nbsp;3.IP地址匹配仅支持IPv4，无法控制设备的IPv6流量；支持CIDR格式，如：192.168.50.0/24。</i></div>
																		<div><i>&nbsp;&nbsp;4.可自定义端口范围，如：80,443,5566:6677,7777:8888。</i></div>																
																		<div><i>&nbsp;</i></div>
																	</div>
																</div>
																<!--高级模式-->
																<div id="tablet_3" style="display: none;">
																	<!--补丁更新 -->
																	<div id="merlinclash-patch" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="merlinclash_switch_table">
																			<thead>
																				<tr>
																					<td colspan="2">插件设置</td>
																				</tr>
																			</thead>
																			<tr>
																				<th class="sp_bottom_line">实时进程守护</th>
																				<td colspan="2" class="sp_bottom_line">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_watchdog_sw">
																							<input id="merlinclash_set_watchdog_sw" class="switch" type="checkbox" style="display: none;">
																							<div class="switch_container" >
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																					<div class="SimpleNote" id="head_illustrate">
																						<p>实时守护内核进程，如果进程丢失则会自动实时重新拉起进程。</p>
																						<p style="color:gold; margin-top: 8px">注意：插件本身运行稳定，通常不必开启该功能。</p>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(31)">开启队列请求</a></th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_queue_sw">
																							<input id="merlinclash_set_queue_sw" type="checkbox" name="cir" class="switch" style="display: none;">
																							<div class="switch_container" >
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr id="record_by_cron">
																				<th>使用定时脚本记录代理组状态</th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_recordbycron_sw">
																							<input id="merlinclash_set_recordbycron_sw" type="checkbox" name="cir" class="switch" style="display: none;">
																							<div class="switch_container" >
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(20)">开机自启推迟时间</a></th>
																				<td colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<input id="merlinclash_set_startdelay_val" maxlength="3" class="input_6_table" value="120" ><span>&nbsp;秒&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>
																						<label>
																						<input id="merlinclash_set_startdelay_sw" type="checkbox" name="merlinclash_set_startdelay_sw"><span>&nbsp;勾选后提交生效</span>
																						</label>
																					</div>
																					<script>
																						$("#merlinclash_set_startdelay_val").on("keyup",function(){
																							$(this).val($(this).val().replace(/[^0-9]+/,''));
																							if($(this).val().length == 1){
																								$(this).val() == '0' ? $(this).val('2') : $(this).val();
																							}
																						});
																						$("#merlinclash_set_startdelay_val").on("keydown",function(){
																							$(this).val($(this).val().replace(/[^0-9]+/,''));
																							if($(this).val().length == 1){
																								$(this).val() == '0' ? $(this).val('2') : $(this).val();
																							}
																						});
																					</script>
																				</td>
																			</tr>
																			<tr>
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(13)">检查日志重试次数</a></th>
																				<td colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<input id="merlinclash_set_logcheck_val" maxlength="3" class="input_6_table" value="40" ><span>&nbsp;次&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;尝试次数需大于20次</span>
																						<input id="merlinclash_set_logcheck_sw" type="hidden" name="merlinclash_set_logcheck_sw">
																					</div>
																					<script>
																						$("#merlinclash_set_logcheck_val").on("keyup",function(){
																							$(this).val($(this).val().replace(/[^0-9]+/,''));
																							if($(this).val().length == 1){
																								$(this).val() == 0 ? $(this).val('40') : $(this).val();
																							}
																						});
																						$("#merlinclash_set_logcheck_val").on("keydown",function(){
																							$(this).val($(this).val().replace(/[^0-9]+/,''));
																							if($(this).val().length == 1){
																								$(this).val() == 0 ? $(this).val('40') : $(this).val();
																							}
																						});
																					</script>
																				</td>
																			</tr>
																		</table>
																	</div>
																	<div id="merlinclash-autodelay" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2">内核设置</td>
																				</tr>
																			</thead>
																			<tr>
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(30)">TCP连接并发</a></th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_tcpcon_sw">
																							<input id="merlinclash_set_tcpcon_sw" type="checkbox" name="tcp_concurrent" class="switch" style="display: none;">
																							<div class="switch_container" >
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr id="mix_port">
																				<th>开启http/socks代理端口</th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_set_mixport_sw">
																							<input id="merlinclash_set_mixport_sw" type="checkbox" name="mixport" class="switch" style="display: none;">
																							<div class="switch_container"  onclick="mixport_save()" href="javascript:void(0);">
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th> <a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(11)">自定义测速时间值</a></th>
																				<td colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<select id="merlinclash_set_interval_val" style="width:80px;margin:0px 0px 0px 2px;text-align:left;padding-left: 0px;" class="input_option">
																							<option value="60">60秒</option>
																							<option value="120">120秒</option>
																							<option value="180">180秒</option>
																							<option value="240">240秒</option>
																							<option value="300" selected>300秒</option>
																							<option value="360">360秒</option>
																							<option value="420">420秒</option>
																							<option value="480">480秒</option>
																							<option value="540">540秒</option>
																							<option value="600">600秒</option>
																						</select>
																						<label>
																						&nbsp;&nbsp;&nbsp;&nbsp;<input id="merlinclash_set_interval_sw" type="checkbox" name="merlinclash_set_interval_sw"><span>&nbsp;勾选后提交生效</span>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(16)">自定义容差值</a></th>
																				<td colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<select id="merlinclash_set_tolerance_val" style="width:80px;margin:0px 0px 0px 2px;text-align:left;padding-left: 0px;" class="input_option">
																							<option value="100" selected>100毫秒</option>
																							<option value="200">200毫秒</option>
																							<option value="300">300毫秒</option>
																							<option value="500">500毫秒</option>
																							<option value="1000">1000毫秒</option>
																						</select>
																						<label>
																						&nbsp;&nbsp;&nbsp;&nbsp;<input id="merlinclash_set_tolerance_sw" type="checkbox" name="merlinclash_set_tolerance_sw"><span>&nbsp;勾选后提交生效</span>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tr>
																				<th>管理面板密码</th>
																				<td colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<input onkeyup="value=value.replace(/[^a-zA-Z0-9]/g,'')" id="merlinclash_set_dashboard_password" class="input_15_table" placeholder="">
																					</div>
																				</td>
																			</tr>
																		</table>
																	</div>
																	<div id="tproxy" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" >
																			<thead>
																				<tr>
																					<td colspan="2">代理设置</td>
																				</tr>
																			</thead>
																			<tr>
																				<th>关闭透明代理</th>
																				<td colspan="2">
																					<div class="switch_field" style="display:table-cell;float: left;">
																						<label for="merlinclash_ipt_closeproxy_sw">
																							<input id="merlinclash_ipt_closeproxy_sw" type="checkbox" name="closeproxy" class="switch" style="display: none;">
																							<div class="switch_container" onclick="tproxy_save()" href="javascript:void(0);">
																								<div class="switch_bar"></div>
																								<div class="switch_circle transition_style">
																									<div></div>
																								</div>
																							</div>
																						</label>
																					</div>
																				</td>
																			</tr>
																			<tfoot id="tproxy_seting">
																				<tr id="ipt_proxyiot">
																					<th>代理访客/IoT网络</th>
																					<td colspan="2">
																						<div class="switch_field" style="display:table-cell;float: left;">
																							<label for="merlinclash_ipt_proxyiot_sw">
																								<input id="merlinclash_ipt_proxyiot_sw" type="checkbox" name="proxyiot" class="switch" style="display: none;">
																								<div class="switch_container" >
																									<div class="switch_bar"></div>
																									<div class="switch_circle transition_style">
																										<div></div>
																									</div>
																								</div>
																							</label>
																						</div>
																					</td>
																				</tr>
																				<tr id="dns_goclash">
																					<th>代理路由自身访问</th>
																					<td colspan="2">
																						<div class="switch_field" style="display:table-cell;float: left;">
																							<label for="merlinclash_ipt_proxyrouter_sw">
																								<input id="merlinclash_ipt_proxyrouter_sw" type="checkbox" name="dnsgoclash" class="switch" style="display: none;" >
																								<div class="switch_container" >
																									<div class="switch_bar"></div>
																									<div class="switch_circle transition_style">
																										<div></div>
																									</div>
																								</div>
																							</label>
																						</div>
																					</td>
																				</tr>
																				<!-- <tr id="mark_value">
																					<th>路由自身流量标记值</th>
																					<td colspan="2">
																						<div class="SimpleNote" id="head_illustrate">
																							<input onkeyup="this.value=this.value.replace(/[^1-9]+/,'0')" id="merlinclash_ipt_routingmark_val" maxlength="5" class="input_6_table" value="255" >
																							<em style="color: gold;">(默认值：255。不懂勿动！)</em>
																						</div>
																					</td>
																				</tr> -->
																				<tr id="Tproxy_plan">
																					<th><a class="hintstyle" >代理模式</a></th>
																					<td colspan="2">
																						<label>
																							<input id="merlinclash_ipt_tproxy_type" type="radio" name="tproxymode" value="closed" checked="checked" onclick="proxymode_change('closed')" >Redir TCP&nbsp;
																						</label>
																						<label>
																							<input id="merlinclash_ipt_tproxy_type" type="radio" name="tproxymode" value="tcp" onclick="proxymode_change('tcp')" >Tproxy TCP&nbsp;
																						</label>
																						<label>
																							<input id="merlinclash_ipt_tproxy_type" type="radio" name="tproxymode" value="udp" onclick="proxymode_change('udp')" >Redir TCP & Tproxy UDP&nbsp;
																						</label>
																						<label>
																							<input id="merlinclash_ipt_tproxy_type" type="radio" name="tproxymode" value="tcpudp" onclick="proxymode_change('tcpudp')" >Tproxy TCP & UDP
																						</label>
																						<p style="color:#FC0">&nbsp;&nbsp;1.默认模式为 Redir TCP</p>
																						<p style="color:#FC0">&nbsp;&nbsp;2.只代理TCP协议：Redir TCP 或者 Tproxy TCP</p>
																						<p style="color:#FC0">&nbsp;&nbsp;3.同时代理TCP和UDP协议：Redir TCP & Tproxy UDP 或者 Tproxy TCP & UDP</p>
																						<p style="color:#FC0">&nbsp;&nbsp;4.支持代理IPv6：TProxy TCP 或者 Tproxy TCP & UDP</p>
																					</td>
																				</tr>
																				<tr id="clash_ipv6" style="height: 30px;" >
																					<th>代理IPv6</th>
																					<td colspan="2">
																						<div class="switch_field" style="display:table-cell;float: left;">
																							<label for="merlinclash_ipt_ipv6_sw">
																								<input id="merlinclash_ipt_ipv6_sw" type="checkbox" name="ipv6" class="switch" style="display: none;">
																								<div class="switch_container" >
																									<div class="switch_bar"></div>
																									<div class="switch_circle transition_style">
																										<div></div>
																									</div>
																								</div>
																							</label>
																						</div>
																						</div>
																					</td>
																				</tr>
																			</tfoot>	
																		</table>
																	</div>				
																</div>

																<!--附加功能-->
																<div id="tablet_4" style="display: none;">
																	<div id="merlinclash-content-additional" style="margin:-1px 0px 0px 0px;">
																		<table style="margin:-1px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="merlinclash_switch_table">
																			<thead>
																				<tr>
																					<td colspan="2">组件更新</a></td>
																				</tr>
																			</thead>
																			<tr>
																				<th class="sp_bottom_line"><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(21)">Geo数据库</a></th>
																				<td class="sp_bottom_line" colspan="2">
																					<div class="SimpleNote" id="head_illustrate">
																						<p>GeoIP数据库
																							<select id="merlinclash_set_geoip_type" style="width:180px;margin:0px 0px 0px 15px;text-align:left;padding-left: 0px;" class="input_option">
																								<option value="lite">GeoIP-Lite-200K</option>
																								<option value="full">GeoIP-Full-20M</option>
																								<option value="head">跟随基础配置</option>
																							</select></p>
																							<p>&nbsp;</p>
																							<p>GeoSite数据库
																								<select id="merlinclash_set_geosite_type" style="width:180px;margin:0px 0px 0px 6px;text-align:left;padding-left: 0px;" class="input_option">
																									<option value="default">GeoSite-Default-800K</option>
																									<option value="lite">GeoSite-Lite-200K</option>
																									<option value="full">GeoSite-Full-5M</option>
																									<option value="head">跟随基础配置</option>
																								</select></p>
																								<p>&nbsp;</p>
																								<a type="button" class="ks_btn" style="cursor:pointer" onclick="geoip_update(5)">设置并更新Geo数据库</a>
																								<span id="geoip_updata_date">上次更新时间：</span>
																							</div>
																						</td>
																					</tr>
																					<tr class="sp_bottom_line">
																						<th class="sp_bottom_line">大陆IP白名单</th>
																						<td class="sp_bottom_line" colspan="2">
																							<div class="SimpleNote" id="head_illustrate">
																								<p>大陆IP白名单 使用由Fernvenue提供的 <a href="https://github.com/fernvenue/chn-cidr-list" target="_blank"><u>CHN CIDR list</u></a>规则</p>
																								<p>&nbsp;</p>
																								<a type="button" class="ks_btn" style="cursor:pointer" onclick="chnroute_update(25)">更新大陆白名单规则</a>
																								<span id="chnroute_updata_date">上次更新时间：</span>
																							</div>
																						</td>
																					</tr>
																					<th>本地更新内核</th>
																					<td colspan="2">
																						<div class="SimpleNote" style="display:table-cell;float: left; height: 110px; line-height: 110px; margin:-40px 0;">
																							<select id="merlinclash_binary_type" style="width:80px;margin:0px 0px 0px 2px;text-align:left;padding-left: 0px;" class="input_option">
																								<option value="clash">&nbsp;Mihomo</option>
																								<!-- <option id="subc_show" value="subconverter">Subconverter</option> -->
																							</select>
																							<input type="file" id="clashbinary" size="50" name="file"/>
																							<span id="clashbinary_upload" style="display:none;">完成</span>
																							<a type="button" style="vertical-align: middle; cursor:pointer;" id="clashbinary-btn-upload" class="ks_btn" onclick="upload_clashbinary()" >上传二进制</a>
																						</div>
																					</td>
																				</tr>
																			</table>
																			<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="merlinclash_switch_table">
																				<thead>
																					<tr>
																						<td colspan="2">备份与排障</td>
																					</tr>
																				</thead>
																				<tr>
																					<th>备份/恢复内容</th>
																					<td colspan="2">
																						<label>
																						<span>基础设置:</span>
																						<input id="merlinclash_bak_set" type="checkbox" name="backup_set">
																						</label>
																						<label>
																						<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;订阅配置:&nbsp;&nbsp;&nbsp;</span>
																						<input id="merlinclash_bak_yaml" type="checkbox" name="backup_yaml">
																						</label>
																						<label>
																						<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DNS设置:</span>
																						<input id="merlinclash_bak_dns" type="checkbox" name="backup_dns">
																						</label>																				
																						<label>
																						<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;自定义规则:</span>
																						<input id="merlinclash_bak_rule" type="checkbox" name="backup_rule">
																						</label>
																						</br>
																						<label>
																						<span>访问控制:</span>
																						<input id="merlinclash_bak_acl" type="checkbox" name="backup_acl">
																						</label>
																						<label>
																						<span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;规则数据库:</span>
																						<input id="merlinclash_bak_db" type="checkbox" name="backup_db">
																						</label>
																					</td>
																				</tr>
																				<tr>
																					<th>备份MC设置</th>
																					<td colspan="2">
																						<a type="button" style="vertical-align: middle; cursor:pointer;" id="clashdata-btn-download" class="ks_btn" onclick="down_clashdata('backup')" >下载备份</a>
																					</td>
																				</tr>
																				<tr>
																					<th class="sp_bottom_line">还原MC设置</th>
																					<td class="sp_bottom_line" colspan="2">
																						<div class="SimpleNote" style="display:table-cell;float: left; height: 110px; line-height: 110px; margin:-40px 0;">
																							<input type="file" style="width: 200px;margin: 0,0,0,0px;" id="clashdata" size="50" name="file"/>
																							<span id="clashdata_info" style="display:none;">完成</span>
																							<a type="button" style="vertical-align: middle; cursor:pointer;" id="clashdata-btn-upload" class="ks_btn" onclick="upload_clashdata()" >恢复备份</a>
																						</div>
																					</td>
																				</tr>																			
																				<tr id="clash_restart_job_tr">
																					<th>
																						<label >定时重启</label>
																					</th>
																					<td>
																						<select name="select_clash_restart" id="merlinclash_select_clash_restart" onChange="show_job()"  class="input_option" style="margin:-1 0 0 10px;">
																							<option value="1" selected>关闭</option>
																							<option value="5">每隔</option>
																							<option value="2">每天</option>
																							<option value="3">每周</option>
																							<option value="4">每月</option>
																						</select>
																						<select name="select_clash_restart_day" id="merlinclash_select_clash_restart_day" class="input_option" ></select>
																						<select name="select_clash_restart_week" id="merlinclash_select_clash_restart_week" class="input_option" ></select>
																						<select name="select_clash_restart_hour"  id="merlinclash_select_clash_restart_hour" class="input_option" ></select>
																						<select name="select_clash_restart_minute"  id="merlinclash_select_clash_restart_minute" class="input_option" ></select>
																						<select name="select_clash_restart_minute_2"  id="merlinclash_select_clash_restart_minute_2" class="input_option" ></select>
																						<input  type="button" id="merlinclash_select_clash_restart_save" class="ks_btn" style="vertical-align: middle; cursor:pointer;" onclick="clash_restart_save();" value="保存设置" />
																					</td>
																				</tr>
																				<tr>
																					<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(27)">重建服务</a></th>
																					<td colspan="2">
																						<div class="merlinclash-btn-container">
																							<a type="button" style="vertical-align: middle; cursor:pointer;" class="ks_btn" id="selectlist" onclick="selectlist_rebuild()">&nbsp;&nbsp;重建下拉列表&nbsp;&nbsp;</a>
																						</div>
																					</td>
																				</tr>
																				<tr>
																					<th><a class="hintstyle" href="javascript:void(0);" onclick="openmcHint(25)">强制关闭插件</a></th>
																					<td colspan="2">
																						<div class="merlinclash-btn-container">
																							<a type="button" style="vertical-align: middle; cursor:pointer;" class="ks_btn" id="hot_off" onclick="hot_off_mc()">&nbsp;&nbsp;热关闭&nbsp;&nbsp;</a>
																							<a type="button" style="vertical-align: middle; cursor:pointer;" class="ks_btn" id="cool_off" onclick="cool_off_mc()">&nbsp;&nbsp;冷关闭&nbsp;&nbsp;</a>
																						</div>
																					</td>
																				</tr>
																				<tr>
																					<th>导出内核日志</th>
																					<td colspan="2">
																						<div class="merlinclash-btn-outputlog">
																							<a type="button" style="vertical-align: middle; cursor:pointer;" class="ks_btn" id="outputlog" onclick="outputlog()">&nbsp;&nbsp;导出日志&nbsp;&nbsp;</a>
																						</div>
																					</td>
																				</tr>
																			</table>
																		</div>
																	</div>

																	<!--当前配置-->
																	<div id="tablet_6" style="display: none;">
																		<div id="yaml_content" class="mc_outline" style="height: 650px;">
																			<textarea class="sbar" cols="63" rows="36" wrap="on" readonly="readonly" id="yaml_content1" style="margin: 0px; width: 709px; height: 645px; resize: none;"></textarea>
																		</div>
																	</div>
																	<!--底部按钮-->
																	<div class="apply_gen" id="loading_icon">
																		<img id="loadingIcon" style="display:none;" src="/images/InternetScan.gif">
																	</div>
																</td>
															</tr>
														</table>
													</div>
												</td>
											</tr>
										</table>
									</td>
									<td width="10" align="center" valign="top"></td>
								</tr>
							</table>
							<div id="footer"></div>
							<div id="loadingMask" style="display: none; position: fixed; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0); z-index: 9999;">
								<p style="position: absolute; top: 2%; right: 0%; transform: translate(-50%, -50%); color: white;">加载中...</p>
							</div>
							
							<!-- 订阅链接生成助手弹窗 -->
							<div id="subLinkGeneratorModal" class="contentMKP_qis" style="display: none; position: fixed; left: 65%; top: 40%; transform: translate(-50%, -50%); box-shadow: 3px 3px 10px #000; z-index: 10000; width: 800px; padding: 15px;">
								<div class="user_title">合并订阅生成助手</div>
								<div style="color:#FC0; margin-left:15px; font-size: 12px;" >1&nbsp;&nbsp;本工具帮助您将多个订阅合并生成一个订阅链接，只支持MC_*内置规则；</div>
								<div style="color:#FC0; margin-left:15px; font-size: 12px;" >2&nbsp;&nbsp;单独订阅UA如果不填，则使用外面设置的UA；</div>
								<div style="color:#FC0; margin-left:15px; font-size: 12px;" >3&nbsp;&nbsp;由于文本框字符限制，一次添加太多订阅可能会导致订阅失败。</div>
								<div style="margin-left:15px">&nbsp;</div>														
								<div style="overflow-x: auto;">
									<table border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" style="width: 100%;">
										<thead>
											<tr border="0" class="FormTable_table nokpacl_lists">			
												<th style="width: 15%;">订阅名称</th>
												<th style="width: 55%;">订阅链接</th>
												<th style="width: 25%;">订阅UA</th>
												<th style="width: 5%;">操作</th>
											</tr>
										</thead>
										<tbody id="subLinkTableBody">
											<tr>												
												<td><input type="text" class="input_15_table"  style="width: 95%;" placeholder="机场名称(选填)"></td>
												<td><input type="text" class="input_15_table"  style="width: 95%;" placeholder="https://abc.com 或 ss://xxxxxxx(必填)"></td>
												<td><input type="text" class="input_15_table"  style="width: 95%;" placeholder="clash-verge/v2.4.7(选填)"></td>
												<td style="text-align: center;"><input class="remove_btn" type="button" onclick="removeSubLinkRow(this)"></td>
											</tr>
										</tbody>
									</table>
								</div>
								<div class="apply_gen" style="margin-top: 10px;">
									<input type="button" class="button_gen" value="新增" onclick="addSubLinkRow()" style="float: left;">
									<input type="button" class="button_gen" value="生成合并订阅链接" onclick="generateSubLinks()" style="float: right; margin-left: 10px;">
									<input type="button" class="button_gen" value="取消" onclick="hideSubLinkGenerator()" style="float: right;">
								</div>
							</div>
							
							<!-- 弹窗遮罩 -->
							<div id="subLinkModalOverlay" style="display: none; position: fixed; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); z-index: 9999;"></div>
						</body>
						</html> 
