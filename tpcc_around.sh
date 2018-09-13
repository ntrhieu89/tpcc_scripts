#!/bin/bash

base="/proj/BG/yaz/ycsbcache"
bench="/proj/BG/yaz/ycsbcache/oltpbench-wb"
bench_around="/proj/BG/yaz/ycsbcache/OLTPBench_Edited"
results="/proj/BG/hieun/tpcc"

mkdir -p $results

#cache="true"
#nthreads="100"

dbip="h0"
cacheips=("h17" "h18" "h19")
clis=( "h1" ) #"h2" "h3" "h4" "h5" "h6" "h7" "h8" "h9" "h10" "h11" "h12" "h13" "h14" "h15" "h16" )

machines=( $dbip ${cacheips[@]} ${clis[@]} )
echo ${machines[@]}
#exit -1

for cache in "true"
do
for try in 1 #2 3 4 5
do
#for nthreads in "50" "200" "400"
#do
	# create a dir
	dir="around-cache-"$cache"-time-600-ntheads-320-try-"$try
	mkdir -p $results/$dir
	dir=$results/$dir
        echo "Created dir $dir."	

        for cli in ${clis[@]}
        do
		ssh $cli "killall java"
	done

	# copy database
	#ssh $dbip sudo service mysql stop
	#ssh $dbip sudo cp -av $base/mysql_smallbank_1m/* /mnt/mysql
	#ssh $dbip sudo service mysql start
	cd $bench
	./oltpbenchmark -b tpcc -c config/tpcc_mysql.xml --create=true --load=true
	cd $base/scripts/ngcache
	echo "Loaded database."

	# start cache
	if [ $cache == "true" ]; then
		echo "Start cache"

		for ip in ${cacheips[@]}
		do
     	           	ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
        	        sleep 2

			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11211 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11212 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11213 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11214 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11215 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11216 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11217 &" &
			ssh -oStrictHostKeyChecking=no $ip "nohup /tmp/IQ-Twemcached/src/twemcache -t 8 -c 8192 -m 20000 -g 7000 -G 999999 -p 11218 &" &
		done
        	echo "Started cache $cache."
	fi
	#exit 0

	sleep 5

	# perform warm up
	#echo "Warm up"
	#cd $bench
	#if [ $cache == "true" ]; then
	#	./warmup $dbip $cacheip:11211,$cacheip:11212,$cacheip:11213,$cacheip:11214,$cacheip:11215,$cacheip:11216,$cacheip:11217,$cacheip:11218
	#else
	#	./warmup $dbip
	#fi
	cd $base/scripts/ngcache
	
	#exit 0

	# start stats
	echo "Preparing sar"
	for m in ${machines[@]}
	do
		ssh -oStrictHostKeyChecking=no $m "killall sar"
		ssh -oStrictHostKeyChecking=no $m "sar -P ALL 10 > $dir/"$m"-cpu.txt &"
		ssh -oStrictHostKeyChecking=no $m "sar -n DEV 10 > $dir/"$m"-net.txt &"
		ssh -oStrictHostKeyChecking=no $m "sar -r 10 > $dir/"$m"-mem.txt &"
		ssh -oStrictHostKeyChecking=no $m "sar -d 10 > $dir/"$m"-disk.txt &"
	done

	# run
	for cli in ${clis[@]}
	do
		echo "bash $bench_around/tpcc_runbench.sh $cache $cli $dir"
		ssh -oStrictHostKeyChecking=no -n -f $cli screen -S tpcc -dm "bash $bench_around/tpcc_runbench.sh $cache $cli $dir"
	done

	sleepcount="0"
	for cli in ${clis[@]}
	do
		while ssh -oStrictHostKeyChecking=no $cli "screen -list | grep -q tpcc"
		do
			((sleepcount++))
			sleep 30
			echo "waiting for $cli "
		done
	done

	echo "Copy results"
        ssh $cli "cp $bench_around/results/* $dir"
	ssh $cli "rm -r $bench_around/results/*"
	grep "NewOrder" $dir/*.csv | wc -l > $dir/totalNewOrder.out


	# collect stats
	for m in ${machines[@]}
	do
		ssh -oStrictHostKeyChecking=no $m "killall sar"
	done

	# draw graphs
	for m in ${machines[@]}
	do
		java -jar ExtractSarInfo.jar CPU $dir/"$m"-cpu.txt $dir/tmp-"$m"-cpu.txt
		java -jar ExtractSarInfo.jar NET $dir/"$m"-net.txt $dir/tmp-"$m"-net.txt
		java -jar ExtractSarInfo.jar MEM $dir/"$m"-mem.txt $dir/tmp-"$m"-mem.txt
		java -jar ExtractSarInfo.jar DISK $dir/"$m"-disk.txt $dir/tmp-"$m"-disk.txt

		echo "==========================="

		python admCntrl.py $dir/tmp-"$m"-cpu.txt $dir/"$m"-cpu
                python admCntrl.py $dir/tmp-"$m"-net.txt $dir/"$m"-net
                python admCntrl.py $dir/tmp-"$m"-mem.txt $dir/"$m"-mem
                python admCntrl.py $dir/tmp-"$m"-disk.txt $dir/"$m"-disk
	done
done
done
#done
