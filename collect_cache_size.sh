#!/bin/bash

memcache=${1}
output=${2}

cs=()
IFS=',' read -ra ADDR <<< "$memcache"
idx=0
for i in ${ADDR[@]}
do
	cs[$idx]=$i
	idx=$((idx+1))
done
echo ${cs[@]}

total=0
s=()
while true; do
	total=0
	idx=0
	for c in ${cs[@]}
	do
		IFS=':' read -ra ADDR <<< "$c"
		ip=${ADDR[0]}
		port=${ADDR[1]}

		{ sleep 1; echo "stats"; sleep 1; echo "quit"; } | telnet $ip $port | grep bytes_allocated > $output/tmp_cz$c.txt &
		idx=$((idx+1))
	done

	wait ${!}
	
	idx=0
	for c in ${cs[@]}
	do
		s[$idx]=$(<$output/tmp_cz$c.txt)
		idx=$((idx+1))
	done

	for ((i=0;i<$idx;i++)); do
		echo ${s[$i]}
       		IFS=' ' read -ra ADDR <<< "${s[$i]}"
        	x=${ADDR[2]}

        	total=$((total+x))
	done


	echo $total >> $output/cz.txt
done
