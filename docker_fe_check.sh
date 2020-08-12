#!/bin/env bash
#2haohr-前端容器接口检测
# 


source /etc/profile

#docker状态检测
docker ps &>/dev/null
docker_status=$?
if [ ${docker_status} -ne 0 ];then
	echo "docker 没有运行"
	exit 1
fi

#避免多脚本运行
echo "pid=$$"
echo "pid_name=$0"
echo ""
#if [ $(ps aux |grep -Ei "$0"|grep -Eiv "grep|$$"|wc -l) -ge 2 ];then
#	echo "进程过多"
#	exit 0
#fi

##获取系统ip
ip_gateway=$(route -n|grep -E "^0.0.0.0"|awk '{print $2}'|grep -v '0.0.0.0')
ip_interface=$(route -n|grep $ip_gateway |awk '{print $NF}')
ucloud_ip=$(ifconfig ${ip_interface}|grep -Ei " inet "|awk '{print $2}')
deploy_time=`date +"%F %T"`

##企业微信机器人
function weixin_webhook {

	#webhook_key='1dacde5e-cc46-4e88-80c2-db965c645bf3' #zabbix-webhook
	webhook_key='1d1540fb-503c-4721-abd0-c0f62056b1ce' #前端大师哥	
	curl 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key='${webhook_key}'' -H 'Content-Type: application/json' -d ' { "msgtype": "text", "text": { "content": "'"$subject"'"} }'
}


##容器健康检查
for i in `docker ps|grep -Evi 'CONTAINER'|awk '{print $(NF-1)}'|awk -F':' '{print $2}'|awk -F'->' '{print $1}'`
do
	deploy_time=`date +"%F %T"`
	docker_image=$(docker ps|grep -Ei ":${i}->"|awk '{print $2}')
	docker_container_name=$(docker ps|grep -Ei ":${i}"|awk '{print $NF}')

	##部署环境识别
	if [ $(echo ${docker_image}|grep -Ei "\-dev"|wc -l) -ge 1 ];then
		deploy_env='开发环境'
	elif [ $(echo ${docker_image}|grep -Ei "\-test"|wc -l) -ge 1 ];then
		deploy_env='测试环境'
	elif [ $(echo ${docker_image}|grep -Ei "\-pre|uat"|wc -l) -ge 1 ];then
		deploy_env='预发布环境'
	else
		deploy_env='正式环境'
	fi
        
	if [ $(echo ${docker_image}|grep -Ei "2haohr\-fe\-node"|wc -l) -ge 1 ];then
		if [ $(timeout 5 ping -c 2 10.13.119.113 2>&1 |grep -Ei " 0\% "|wc -l) -ge 1  ];then
	                deploy_env='开发环境/测试环境'
		fi
        fi

	echo "${deploy_env} ${docker_container_name} ${docker_image}"

	if [ $(curl -sI --connect-timeout 7 ${ucloud_ip}:${i}|grep -Ei "^HTTP/"|grep -v grep|wc -l) -le 0 ];then

		#当检测异常的时候
		if [ $(curl -sI --connect-timeout 7 ${ucloud_ip}:${i}|grep -Ei "^HTTP/"|grep -v grep|wc -l) -le 0 ];then
			i=1     ##进行多次测试异常状态
			while [ $i -le 5 ]
			do
				echo "$i"
				let i=$i+1
				sleep 15
				if [ $(curl -sI --connect-timeout 7 ${ucloud_ip}:${i}|grep -Ei "^HTTP/"|grep -v grep|wc -l) -ge 1 ];then
					return_status='0'
					break
				else
					return_status='1'
				fi
			done

			if [ "${return_status}" =="0" ];then
				continue
			fi

		fi
		
		if [ $(echo ${docker_container_name}|grep -Ei "2haohr\-fe\-node"|wc -l) -ge 1 ];then
			if [ $(timeout 5 ping -c 2 10.13.119.113 2>&1 |grep -Ei " 0\% "|wc -l) -ge 1  ];then
				deploy_env='开发环境/测试环境'
			fi
                fi

		subject="[${deploy_env}] 时间:'"$deploy_time\'" 节点:${ucloud_ip} 问题:容器${docker_container_name},部署镜像${docker_image} 健康检查失败,触发重启!"	
		weixin_webhook
		docker restart ${docker_container_name}
		sleep 10
		if [ $(curl -sI --connect-timeout 7 ${ucloud_ip}:${i}|grep -Ei "^HTTP/"|grep -v grep|wc -l) -ge 1 ];then
			deploy_time=`date +"%F %T"`
			subject="[${deploy_env}] 时间:'"$deploy_time\'" 节点:${ucloud_ip} 问题:容器${docker_container_name},部署镜像${docker_image} 健康检查成功,重启成功!"
			weixin_webhook
		else
			deploy_time=`date +"%F %T"`
			subject="[${deploy_env}] 时间:'"$deploy_time\'" 节点:${ucloud_ip} 问题:容器${docker_container_name},部署镜像${docker_image} 健康检查持续失败,请联系管理员检查!"
			weixin_webhook
		fi
	fi

done


##僵尸进程父进程获取
echo ""
for ppid_z in `ps -A -ostat,ppid,pid,cmd |grep -e '^[Zz]'|awk '{print $2}'|sort -n|uniq`
do
	deploy_time=`date +"%F %T"`

	#echo "系统的僵尸进程-父进程=$ppid_z"
	
	for ppid_z_ppid in `ps -ef |grep ${ppid_z}|grep -v "grep"|awk '{print $3}'|grep -v "${ppid_z}"`
	do
		#echo "系统的僵尸进程-父父进程=${ppid_z_ppid}"	
		docker_id=$(ps -ef|grep ${ppid_z_ppid}|grep -v grep|grep -Ei "/containerd/daemon/"|tr ' '  '\n'|grep -Eiv "^$"|grep -Ei "/containerd/daemon/"|awk -F'/' '{print $NF}'|cut -c1-12)
		if [ -n "${docker_id}"  ];then

			docker_container_name=$(docker ps|grep -Ei "${docker_id}"|awk '{print $NF}')
			echo "容器名字:${docker_container_name} 容器id=${docker_id} 系统的僵尸进程-父进程=$ppid_z 系统的僵尸进程-父父进程=${ppid_z_ppid}"

			if [ $(date +"%H:%H") == '04:05' ];then
				docker restart ${docker_id}
				docker_image=$(docker ps|grep -Ei "${docker_id}"|awk '{print $2}')
				##部署环境识别
	                        if [ $(echo ${docker_image}|grep -Ei "\-dev"|wc -l) -ge 1 ];then
	                                deploy_env='开发环境'
	                        elif [ $(echo ${docker_image}|grep -Ei "\-test"|wc -l) -ge 1 ];then
	                                deploy_env='测试环境'
	                        elif [ $(echo ${docker_image}|grep -Ei "\-pre|uat"|wc -l) -ge 1 ];then
	                                deploy_env='预发布环境'
	                        else 
	                                deploy_env='正式环境' 
	                        fi 
				docker_image=$(docker ps|grep -Ei "${docker_id}"|awk '{print $2}')
				docker_container=$(docker ps|grep -Ei "${docker_id}"|awk '{print $1}')
				docker_container_name=$(docker ps|grep -Ei "${docker_id}"|awk '{print $NF}')
				
				#if [ $(echo ${docker_container_name}|grep -Ei "2haohr\-node\-print"|wc -l) -ge 1 -a "${ucloud_ip}" == '10.13.13.101' ];then
				if [ $(echo ${docker_container_name}|grep -Ei "2haohr\-fe\-node"|wc -l) -ge 1 ];then
					if [ $(timeout 5 ping -c 2 10.13.119.113 2>&1 |grep -Ei " 0\% "|wc -l) -ge 1  ];then
		                        	deploy_env='开发环境/测试环境'
					fi
		                fi

				subject="[${deploy_env}] 时间:'"$deploy_time\'" 节点:${ucloud_ip} 问题:容器${docker_container_name} 存在僵尸进程,触发重启!"
				weixin_webhook
				
			fi

		fi
	done
done
