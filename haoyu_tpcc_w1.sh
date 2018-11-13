#!/bin/bash

killall sar
killall java
killall twemcache

base="/proj/BG/yaz/ycsbcache"
bench="/proj/BG/yaz/ycsbcache/oltpbench-wb"
results="/tmp/results"
exp_results_dir="/proj/BG/yaz/ycsbcache/wb-results"
cahce_dir="/proj/BG/haoyu/IQ-Twemcached-wb"

# Rebuild the project
cd $bench
ant
cd /proj/BG/yaz/ycsbcache/scripts/ngcache

mkdir -p $exp_results_dir
mkdir -p $results

#cache="true"
#nthreads="100"

dbip="h0"

#cacheips=( "h11" "h12" "h13" "h14" "h15" "h16" "h17" "h18" "h19" "h20" )
cacheips=( "h2" "h3" "h4" )
# cacheips=( "h2" )
cacheperserver="1"
threadsPerCMI="8"
rep="1"
storesess="false"
total_caches=$((${#cacheips[@]}*$cacheperserver))
echo "total caches: $total_caches"

memcache=""
cache_instances=()
for ip in ${cacheips[@]}
do
	port=11211
	for ((i=0; i < $cacheperserver; i++))
	do
		memcache=$memcache$ip":$port,"
		cache_instances=(${cache_instances[@]} "$ip:$port")
		port=$((port+1))
	done
done
memcache=${memcache::-1}
echo $memcache
echo "cache instances: ${cache_instances[@]}"

cliperserver="1"
#clis=( "h1" "h2" "h3" "h4" "h5" "h6" "h7" "h8" "h9" "h10" )
clis=( "h1" )

machines=( $dbip ${cacheips[@]} ${clis[@]} )
echo ${machines[@]}

warehouses="1"
copydb="false"
batch="100"
arsleep="0"
storesess="false"
manualwarmup="true"
parallel="true"
eviction="true"

for try in 6 7
do
for warehouses in 1
do
for cache in "true"
do
for eviction in "false" "true"
do
for rep in 1 #2 3
do
    if [[ $rep == "1" ]]; then
        parallel="false"
    else
    	parallel="true"
    fi
    echo "Parallel = "$parallel
for persistMode in "async_bdb" #"sync_bdb" "no_persist"
do
for cachesize in 6000 #37 75 150 300 1000
do
for threads in 1
do
for ar in 1
do
for threadsPerCMI in 2
do
for cacheperserver in 1
do
	if [[ $eviction == "false" ]]; then
		if [[ $cachesize -lt 6000 ]]; then
			continue
		fi
	fi
	if [[ $eviction == "true" ]]; then
		if [[ $persistMode == "no_persist" ]]; then
			continue
		fi
		if [[ $cachesize -eq 6000 ]]; then
			continue
		fi
	fi

	echo "running configuration bdb-w-$warehouses-ar-$ar-th-$threads-tpc-$threadsPerCMI-cps-$cacheperserver-pm-$persistMode-rep-$rep-cz-$cachesize-eviction-$eviction"
		
	# create a dir
	#dir="bdb-"$cache"-try-"$try"-w-"$warehouses"-ar-"$ar"-th-"$threads"-tpc-"$threadsPerCMI"-cps-"$cacheperserver"-pm-"$persistMode"-rep-"$rep"-cz-"$cachesizei
	for m in ${machines[@]}
	do
		echo "clean up $m result dir $results"
    	ssh $m "sudo rm -rf $results"
    	ssh $m "sudo mkdir -p $results"
    	ssh $m "sudo chmod -R 777 $results"
	done

	#mkdir -p $results/$dir
	#dir=$results/$dir
	dir=$results
    echo "Created dir $dir."	

    for cli in ${clis[@]}
    do
		ssh $cli "killall java"
	done

    for ip in ${cacheips[@]}
    do
        ssh $ip "killall java"
    done

	#exit -1

	# start cache
	if [ $cache == "true" ]; then
		echo "Start cache"

		for ip in ${cacheips[@]}
		do
            ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
            sleep 2

			ssh $ip "sudo rm -rf /mnt/bdb*"

			port=11211
			for ((i=0; i < $cacheperserver; i++))
			do
				time=$(date +%s%N)
				ssh $ip "sudo mkdir -p /mnt/bdb-$persistMode-$ip-$port-$time"
				ssh $ip "sudo chmod -R 777 /mnt/bdb-$persistMode-$ip-$port-$time"
				valgr="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose --log-file=/tmp/valgrind-out.txt"

				if [[ $persistMode == "sync_bdb" ]]; then
					cmd="$cahce_dir/src/twemcache -q 1 -Q 1 -i /mnt/bdb-$persistMode-$ip-$port-$time -w 1 -F 1 -t $threadsPerCMI -c 8000 -m $cachesize -g 7000 -G 999999 -p $port"
				elif [[ $persistMode == "async_bdb" ]]; then
					cmd="$cahce_dir/src/twemcache -q 1 -i /mnt/bdb-$persistMode-$ip-$port-$time -w 1 -F 1 -t $threadsPerCMI -c 8000 -m $cachesize -g 7000 -G 999999 -p $port -Z 31"
				else
					cmd="$cahce_dir/src/twemcache -t $threadsPerCMI -c 8000 -m $cachesize -g 7000 -G 999999 -p $port"
				fi

				if [[ $eviction == "true" ]]; then
					cmd=$cmd" -T 1"
				fi

				echo $cmd

				ssh -oStrictHostKeyChecking=no $ip "nohup $cmd >& $dir/cache$ip-$port.txt &" &
				port=$((port+1))
			done
		done
	fi

	# copy database
	if [[ $copydb == "true" ]]; then
		sudo service mysql stop
		sudo cp -av $base/mysql_tpcc_"$warehouses"w/* /mnt/mysql
		sudo service mysql start
	else
		cd $bench
		./oltpbenchmark -b tpcc -c config/tpcc_mysql.xml --create=true --load=true --scalefactor=$warehouses --threads=$threads
		cd $base/scripts/ngcache
	fi
	echo "Loaded database."

	sleep 5

    for ip in ${cacheips[@]}
    do
        while ssh -oStrictHostKeyChecking=no $ip "screen -list | grep -q tpcc"
        do
            sleep 10
            echo "waiting for $ip "
        done
    done

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
	ssh $cli "rm -r $bench/results/*"
	numClis=${#clis[@]}
	cache_instance_id=0
	
	for cli in ${clis[@]}
	do
		for ((i=0; i < $cliperserver; i++))
		do
			cache_instance=${cache_instances[$cache_instance_id]}
			if [[ $rep -eq 2 ]]; then
				sid=$((($cache_instance_id+1)%$total_caches))
				cache_instance="$cache_instance,${cache_instances[$sid]}"
			elif [[ $rep -eq 3 ]]; then
				sid=$((($cache_instance_id+1)%$total_caches))
				tid=$((($cache_instance_id+2)%$total_caches))
				cache_instance="$cache_instance,${cache_instances[$sid]},${cache_instances[$tid]}"
			fi

			cmd="bash $bench/tpcc_runbench.sh $cache $cli $dir $ar $batch $cache_instance $threads $warehouses $arsleep 1 1 1.0 $rep $storesess $parallel $persistMode $manualwarmup"
			echo $cmd
			ssh -oStrictHostKeyChecking=no -n -f $cli screen -S mtpcc -dm $cmd
		done
	done

	for cli in ${clis[@]}
	do
		while ssh -oStrictHostKeyChecking=no $cli "screen -list | grep -q mtpcc"
		do
			sleep 10
			echo "waiting for $cli "
		done
	done

	# get cachestats
	for ip in ${cacheips[@]}
	do
		{ sleep 2; echo "stats"; sleep 2; echo "quit"; sleep 1; } | telnet $ip 11211 > $dir/"cachestats-$ip.txt"
		ssh $ip "top -b -n 1 > $dir/log-mem-bdb-$ip.txt"
		ssh $ip "bash $base/scripts/ngcache/test.sh $dir/log-bdb-$ip.txt"
	done

	echo "Copy results"
    ssh $cli "sudo cp $bench/results/* $dir"
	ssh $cli "sudo rm -r $bench/results/*"

	# Copy the files over local node
    dir="bdb-$cache-try-$try-w-$warehouses-ar-$ar-th-$threads-tpc-$threadsPerCMI-cps-$cacheperserver-pm-$persistMode-rep-$rep-cz-$cachesize-eviction-$eviction"
	dir="$exp_results_dir/$dir"
    echo "Save to $dir..."
    sudo rm -rf $dir
    sudo mkdir -p $dir
    sudo chmod -R 777 $dir

    for m in ${machines[@]}
    do
        scp -r $m:$results/* $dir
    done

	grep "NewOrder" $dir/*.csv | wc -l > $dir/totalNewOrder.out
	grep "Payment" $dir/*.csv | wc -l > $dir/totalPayment.out
	grep "Delivery" $dir/*.csv | wc -l > $dir/totalDelivery.out
	grep "OrderStatus" $dir/*.csv | wc -l > $dir/totalOrderStatus.out
	grep "StockLevel" $dir/*.csv | wc -l > $dir/totalStockLevel.out
	python anas.py $dir
	python admCntrl.py $dir/throughput.txt $dir/throughput
    python admCntrl.py $dir/NewOrder.txt $dir/NewOrderLatency
    python admCntrl.py $dir/Payment.txt $dir/PaymentLatency
    python admCntrl.py $dir/Delivery.txt $dir/DeliveryLatency
    python admCntrl.py $dir/OrderStatus.txt $dir/OrderStatusLatency
    python admCntrl.py $dir/StockLevel.txt $dir/StockLevelLatency

	# collect stats
	for m in ${machines[@]}
	do
		ssh -oStrictHostKeyChecking=no $m "killall sar"
	done
	for ip in ${cacheips[@]}
    do
        ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
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
done
done
done
done
done
done
done
done
done
