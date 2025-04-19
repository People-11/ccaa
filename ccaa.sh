#!/bin/bash
#####	一键安装File Browser + Aria2 + AriaNg		#####
#####	作者：xiaoz.me, People11						#####
#####	更新时间：2025-04-14							#####

#导入环境变量
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

#设备类型设置
if [ "$1" = 'arm' ]
	then
	aria2_url='https://github.com/abcfy2/aria2-static-build/releases/download/1.37.0/aria2-arm-linux-musleabi_static.zip'
	filebrowser_url='https://github.com/filebrowser/filebrowser/releases/download/v2.32.0/linux-arm64-filebrowser.tar.gz'
	master_url='https://github.com/People-11/ccaa/archive/master.zip'
	ccaa_web_url='https://github.com/People-11/ccaa/raw/master/ccaa_web'
	flag='arm'
	else
	aria2_url='https://github.com/abcfy2/aria2-static-build/releases/download/1.37.0/aria2-x86_64-linux-musl_static.zip'
	filebrowser_url='https://github.com/filebrowser/filebrowser/releases/download/v2.32.0/linux-amd64-filebrowser.tar.gz'
	master_url='https://github.com/People-11/ccaa/archive/master.zip'
	ccaa_web_url='https://github.com/People-11/ccaa/raw/master/ccaa_web'
	flag='amd'
fi

#检查是否为root用户
function check_root() {
    if [ $(id -u) -ne 0 ]; then
        echo "错误: 必须使用root用户运行此脚本!"
        exit 1
    fi
}

#安装前的检查
function check(){
	echo '-------------------------------------------------------------'
	if [ -e "/etc/ccaa" ]
        then
        echo 'CCAA已经安装，若需要重新安装，请先卸载再安装！'
        echo '-------------------------------------------------------------'
        exit
	else
	        echo '检测通过，即将开始安装。'
	        echo '-------------------------------------------------------------'
	fi
}

#安装之前的准备
function setout(){
	if [ -e "/usr/bin/yum" ]
	then
		yum -y install curl gcc wget unzip tar
	else
		#更新软件，否则可能make命令无法安装
		sudo apt-get update
		sudo apt-get install -y curl wget unzip sudo
	fi
	#创建临时目录
	cd
	mkdir ./ccaa_tmp
}

#创建ccaa用户
function create_user() {
    echo "正在创建ccaa用户..."
    
    # 检查用户是否已存在
    if id "ccaa" &>/dev/null; then
        echo "用户ccaa已存在，跳过创建"
    else
        # 创建用户，不允许登录
        if [ -e "/usr/bin/yum" ]; then
            useradd -r -s /sbin/nologin ccaa
        else
            useradd -r -s /usr/sbin/nologin ccaa
        fi
        echo "用户ccaa创建成功"
    fi
}

#安装Aria2
function install_aria2(){
	#进入临时目录
	cd ./ccaa_tmp
	#安装aria2静态编译版本
	wget -c ${aria2_url}
	if [ ${flag} = 'arm' ]
		then
		unzip aria2-arm-linux-musleabi_static.zip
		cd aria2-arm-linux-musleabi_static
		else
		unzip aria2-x86_64-linux-musl_static.zip
		cd aria2-x86_64-linux-musl_static
	fi
	cp aria2c /usr/bin/
	chmod +x /usr/bin/aria2c
	cd
}

#安装File Browser文件管理器
function install_file_browser(){
	cd ./ccaa_tmp
	#下载File Browser
	wget ${filebrowser_url}
	#解压
	if [ ${flag} = 'arm' ]
		then
		tar -zxvf linux-arm64-filebrowser.tar.gz
		else
		tar -zxvf linux-amd64-filebrowser.tar.gz
	fi
	#移动位置
	mv filebrowser /usr/sbin
	chmod +x /usr/sbin/filebrowser
	cd
}

#处理配置文件
function dealconf(){
	cd ./ccaa_tmp
	#下载CCAA项目
	wget ${master_url}
	#解压
	unzip master.zip
	
	#创建CCAA配置目录
	mkdir -p /etc/ccaa
	
	#复制CCAA核心目录
	cp -r ccaa-master/ccaa_dir/* /etc/ccaa/
	
	#设置目录权限
	chmod 755 /etc/ccaa
	chown -R ccaa:ccaa /etc/ccaa
	
	#创建其他日志文件
	touch /var/log/aria2.log
	touch /var/log/ccaa_web.log
	touch /var/log/fbrun.log
	touch /var/log/filebrowser.log
	chown ccaa:ccaa /var/log/aria2.log
	chown ccaa:ccaa /var/log/ccaa_web.log
	chown ccaa:ccaa /var/log/fbrun.log
	chown ccaa:ccaa /var/log/filebrowser.log
	
	#upbt增加执行权限
	chmod +x /etc/ccaa/upbt.sh
	
	#ccaa增加执行权限
	chmod +x ccaa-master/ccaa
	cp ccaa-master/ccaa /usr/sbin
	
	#创建空的session文件并设置权限
	touch /etc/ccaa/aria2.session
	chmod 644 /etc/ccaa/aria2.session
	chown ccaa:ccaa /etc/ccaa/aria2.session
	
	cd
}

#更新systemd服务文件
function update_service_files() {
    cd ./ccaa_tmp
    
    # 修改服务文件，添加用户运行
    mkdir -p /etc/systemd/system

    # 更新ccaa主服务文件
    cat > /etc/systemd/system/ccaa.service << EOF
[Unit]
Description=CCAA Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/ccaa start
ExecStop=/usr/sbin/ccaa stop
ExecReload=/usr/sbin/ccaa restart

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    
    cd
}

#自动放行端口
function chk_firewall(){
	if [ -e "/etc/sysconfig/iptables" ]
	then
		iptables -I INPUT -p tcp --dport 6080 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6081 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6800 -j ACCEPT
		iptables -I INPUT -p tcp --dport 51413 -j ACCEPT
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --add-port=6080/tcp --permanent
		firewall-cmd --zone=public --add-port=6081/tcp --permanent
		firewall-cmd --zone=public --add-port=6800/tcp --permanent
		firewall-cmd --zone=public --add-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		ufw allow 6080/tcp #AriaNG
		ufw allow 6081/tcp #Filebrowser
		ufw allow 6800/tcp #AriaRPC
		ufw allow 51413/tcp #BTPort
	fi
}

#设置账号密码
function setting(){
	cd
	cd ./ccaa_tmp
	echo '-------------------------------------------------------------'
	read -p "设置下载路径（请填写绝对地址，默认/downloads/realdownloads）:" downpath < /dev/tty
	read -p "Aria2 RPC 密钥:(字母或数字组合，不要含有特殊字符):" secret < /dev/tty
	#如果Aria2密钥为空
	while [ -z "${secret}" ]
	do
		read -p "Aria2 RPC 密钥:(字母或数字组合，不要含有特殊字符):" secret < /dev/tty
	done
	
	#如果下载路径为空，设置默认下载路径
	if [ -z "${downpath}" ]
	then
		downpath='/downloads/realdownloads'
	fi

	#获取ip
	osip=$(curl ipv4.ip.sb)
	
	#执行替换操作
	mkdir -p ${downpath}
	# 设置下载目录权限
	chmod 755 ${downpath}
	chown -R ccaa:ccaa ${downpath}
	
	sed -i "s%dir=%dir=${downpath}%g" /etc/ccaa/aria2.conf
	sed -i "s/rpc-secret=/rpc-secret=${secret}/g" /etc/ccaa/aria2.conf
	#替换filebrowser读取路径
	sed -i "s%ccaaDown%${downpath}%g" /etc/ccaa/config.json
	#替换AriaNg服务器链接
	sed -i "s/server_ip/${osip}/g" /etc/ccaa/AriaNg/index.html
	
	#更新tracker
	bash /etc/ccaa/upbt.sh
	
	#安装AriaNg
	wget ${ccaa_web_url}
	cp ccaa_web /usr/sbin/
	chmod +x /usr/sbin/ccaa_web
	
	# 创建sudo规则允许ccaa用户无密码执行特定命令
	echo "ccaa ALL=(ALL) NOPASSWD: /usr/sbin/ccaa start, /usr/sbin/ccaa stop, /usr/sbin/ccaa restart" > /etc/sudoers.d/ccaa
	chmod 440 /etc/sudoers.d/ccaa

	# 使用systemd启动服务
	systemctl enable ccaa.service
	
	systemctl start ccaa.service

	echo '-------------------------------------------------------------'
	echo "大功告成，请访问: http://${osip}:6080/#!/settings/rpc/set/http/${osip}/6800/jsonrpc/${secret}"
	echo 'File Browser 用户名:ccaa'
	echo 'File Browser 密码:admin'
	echo '帮助文档: https://doc.xiaoz.org/books/ccaa' 
	echo '-------------------------------------------------------------'
}

#清理工作
function cleanup(){
	cd
	rm -rf ccaa_tmp
}

#卸载
function uninstall(){
	wget -O ccaa-uninstall.sh https://raw.githubusercontent.com/People-11/ccaa/master/uninstall.sh
	bash ccaa-uninstall.sh
	
	# 删除sudo配置
	rm -f /etc/sudoers.d/ccaa
}

#选择安装方式
while true
do
  echo "------------------------------------------------"
  echo "Linux + File Browser + Aria2 + AriaNg一键安装脚本(CCAA)"
  echo "1) 安装CCAA"
  echo "2) 卸载CCAA"
  echo "3) 更新bt-tracker"
  echo "q) 退出！"
  
  # 从终端设备读取输入
  read -p ":" istype < /dev/tty
  
  # 去除可能的空格
  istype=$(echo "$istype" | tr -d '[:space:]')
  
  if [ "$istype" = "1" ]; then
    check_root
    check
    setout
    create_user
    chk_firewall
    install_aria2
    install_file_browser
    dealconf
    update_service_files
    setting
    cleanup
    break  # 完成安装后退出循环
  elif [ "$istype" = "2" ]; then
    uninstall
    break  # 完成卸载后退出循环
  elif [ "$istype" = "3" ]; then
    bash /etc/ccaa/upbt.sh
    break  # 完成更新后退出循环
  elif [ "$istype" = "q" ] || [ "$istype" = "Q" ]; then
    echo "退出脚本"
    exit 0
  elif [ "$istype" = "" ]; then
    echo "请选择一个选项"
    # 继续循环
  else
    echo '参数错误！请重新选择'
    # 继续循环
  fi
done