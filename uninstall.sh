#!/bin/bash
#####	一键卸载CCAA					#####
#####	作者：xiaoz.me, People11		#####
#####	更新时间：2025-04-14			#####

#导入环境变量
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

# 获取下载路径
if [ -f "/etc/ccaa/aria2.conf" ]; then
    download_dir=$(grep "^dir=" /etc/ccaa/aria2.conf | cut -d= -f2)
fi

#删除端口函数
function del_post() {
	if [ -e "/etc/sysconfig/iptables" ]
	then
		sed -i '/^.*6080.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6081.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6800.*/'d /etc/sysconfig/iptables
		sed -i '/^.*51413.*/'d /etc/sysconfig/iptables
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --remove-port=6080/tcp --permanent
		firewall-cmd --zone=public --remove-port=6081/tcp --permanent
		firewall-cmd --zone=public --remove-port=6800/tcp --permanent
		firewall-cmd --zone=public --remove-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		ufw delete allow 6080/tcp
		ufw delete allow 6081/tcp
		ufw delete allow 6800/tcp
		ufw delete allow 51413/tcp
	fi
}

# 处理下载目录权限
function handle_download_dir() {
    if [ -n "$download_dir" ] && [ -d "$download_dir" ]; then
        echo "------------------------------------------------"
        echo "检测到下载目录: $download_dir"
        echo "当前所有者: $(stat -c '%U:%G' "$download_dir")"
        echo ""
        
        read -p "您想更改下载目录的所有者吗? [y/n]: " change_owner < /dev/tty
        
        if [ "$change_owner" = "y" ] || [ "$change_owner" = "Y" ]; then
            # 列出可用的常规用户（UID >= 1000）
            echo "系统上的可用用户:"
            awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd
            
            read -p "请输入新所有者用户名 (按回车使用当前用户: $USER): " new_owner < /dev/tty
            new_owner=${new_owner:-$USER}
            
            if id "$new_owner" &>/dev/null; then
                echo "正在将 $download_dir 所有权更改为 $new_owner..."
                chown -R $new_owner:$new_owner "$download_dir"
                echo "所有权已更改为: $(stat -c '%U:%G' "$download_dir")"
            else
                echo "错误: 用户 $new_owner 不存在，保持原有权限"
            fi
        else
            echo "保持原有权限不变"
        fi
        
        echo "------------------------------------------------"
    fi
}

#停止所有服务
echo "停止服务..."
systemctl stop ccaa.service 2>/dev/null
systemctl disable ccaa.service 2>/dev/null

# 处理下载目录权限问题
handle_download_dir

#删除文件
echo "删除程序文件..."
rm -rf /etc/ccaa
rm -rf /usr/sbin/ccaa_web
rm -rf /usr/sbin/ccaa
rm -rf /usr/bin/aria2c
rm -rf aria2-1.*
rm -rf AriaNg*
rm -rf /usr/share/man/man1/aria2c.1
rm -rf /etc/systemd/system/ccaa.service

#删除filebrowser
rm -rf /usr/sbin/filebrowser

#删除日志
rm -rf /var/log/aria2.log
rm -rf /var/log/ccaa_web.log
rm -rf /var/log/fbrun.log
rm -rf /var/log/filebrowser.log

#删除端口
echo "删除防火墙规则..."
del_post

# 删除sudo规则
rm -f /etc/sudoers.d/ccaa

# 删除ccaa用户 (最后删除用户，确保先处理文件权限)
echo "删除ccaa用户..."
userdel ccaa 2>/dev/null

echo "------------------------------------------------"
echo '卸载完成！'
echo "------------------------------------------------"

#删除自身
rm -rf ccaa-uninstall.sh