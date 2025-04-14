#!/bin/bash
#####	更新bt-tracker脚本			#####
#####	作者：xiaoz.me, People11		#####
#####	更新时间：2025-04-14			#####

#导入环境变量
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

function up_tracker(){
	#下载最新的bt-tracker
	wget -O /tmp/trackers_best.txt https://raw.githubusercontent.com/XIU2/TrackersListCollection/refs/heads/master/best_aria2.txt
	# 确保临时文件有正确权限
	chmod 644 /tmp/trackers_best.txt
	
	tracker=$(cat /tmp/trackers_best.txt)
	#替换处理bt-tracker
	tracker="bt-tracker="${tracker}
	#更新aria2配置
	sed -i '/bt-tracker.*/'d /etc/ccaa/aria2.conf
	echo ${tracker} >> /etc/ccaa/aria2.conf
	echo '-------------------------------------'
	echo 'bt-tracker update completed.'
	echo '-------------------------------------'
}

up_tracker

#重启aria2服务
/usr/sbin/ccaa restart