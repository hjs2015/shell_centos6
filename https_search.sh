for i in `cat /root/file`
do
	if [ $(curl -sv "${i}" 2>&1 |grep -E "HTTP/"|grep -Ei "ok"|wc -l) -ge 1 ];then
	#echo "${i}"
	#curl -sv "${i}" 2>&1 |grep -E "HTTP/"|grep -Ei "ok"
	test_i=$(echo $i|awk -F"https://" '{print $NF}')
	test_ip=$(ping -w 1 ${test_i}|head -1|awk '{match($0,/\([^()]*\)/);print substr($0,RSTART+1,RLENGTH-2)}')
	echo "${i} ${test_ip}"	
	fi

done
