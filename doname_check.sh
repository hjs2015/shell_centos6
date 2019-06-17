#!/bin/bash

read -p "输入域名文件：" file
now_time=`date +%s`
for i in `cat $file`
do
   name=`curl -v "$i" 2>&1 | grep "common\ name"`
   expire=`curl -v "$i" 2>&1 | grep "expire\ date"`
   line=`echo "$name$expire" | awk '{if($7=="Jan")print $10"01"$8;if($7=="Feb")print $10"02"$8;if($7=="Mar")print $10"03"$8;if($7=="Apr")print $10"04"$8;if($7=="May")print $10"05"$8;else if($7=="Jun")print $10"06"$8;if($7=="Jul")print $10"07"$8;if($7=="Aug")print $10"08"$8;if($7=="Sep")print $10"09"$8;if($7=="Oct")print $10"10"$8;if($7=="Nov")print $10"11"$8;if($7=="Dec")print $10"12"$8}'`
   domain_time=`date -d $line +%s`
   expire_time=`expr $domain_time - $now_time`
   expire_days=`expr $expire_time / 86400`
   if [ $expire_days -lt 30 ];then
       msg=`echo "$name 证书还有 $expire_days 天过期" | awk '{for(i=1;i<=3;i++)$i="";print $0}'`
       echo $msg >> domain.txt
       echo -e "\033[31m$msg\033[0m"
   else
       echo "$name 证书还有 $expire_days 天过期" | awk '{for(i=1;i<=3;i++)$i="";print $0}'
   fi
done
