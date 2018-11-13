#!/bin/bash

base="/proj/BG/yaz/ycsbcache"
bench="/proj/BG/yaz/ycsbcache/oltpbench-wb"
results="/proj/BG/hieun/tpcc"

# Rebuild the project
cd $bench
ant
cd /proj/BG/yaz/ycsbcache/scripts/ngcache

mkdir -p $results

#cache="true"
#nthreads="100"

dbip="h0"
#cacheips=( "h11" "h12" "h13" "h14" "h15" "h16" "h17" "h18" "h19" "h20" )
cacheips=( "h2" )
cacheperserver="1"
threadsPerCMI="8"
rep="1"
storesess="false"

memcache=""
for ip in ${cacheips[@]}
do
	port=11211
	for ((i=0; i < $cacheperserver; i++))
	do
		memcache=$memcache$ip":$port,"
		port=$((port+1))
	done
done
memcache=${memcache::-1}
echo $memcache

cliperserver="1"
#clis=( "h1" "h2" "h3" "h4" "h5" "h6" "h7" "h8" "h9" "h10" )
clis=( "h1" )

machines=( $dbip ${cacheips[@]} ${clis[@]} )
echo ${machines[@]}
#exit -1

warehouses="1"
#threads="20"
#batch="10"
copydb="false"

for warehouses in 1
do
for cache in "true"
do
for try in 7
do
for threads in 1
do
for ar in 0
#ar=$threads
#ar=0
#ar="1"
do
for threadsPerCMI in 8
do
for batch in 100
do
for arsleep in 0
do
for cacheperserver in 1
do
for storesess in "false"
do
	# create a dir
	dir="cache-"$cache"-try-"$try"-w-"$warehouses"-ar-"$ar"-th-"$threads"-batch-"$batch"-arsleep-"$arsleep"-tpc-"$threadsPerCMI"-cps-"$cacheperserver"-storesess-"$storesess

	mkdir -p $results/$dir
	dir=$results/$dir
        echo "Created dir $dir."	

        for cli in ${clis[@]}
        do
		ssh $cli "killall java"
	done

        for ip in ${cacheips[@]}
        do
                ssh $ip "killall java"
        done

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

	#exit -1

	# start cache
	if [ $cache == "true" ]; then
		echo "Start cache"

		for ip in ${cacheips[@]}
		do
                        ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
                        sleep 2

			port=11211
			for ((i=0; i < $cacheperserver; i++))
			do
				ssh $ip "sudo rm -rf /mnt/bdb/*"
				ssh $ip "sudo mkdir -p /mnt/bdb"
				ssh $ip "sudo chmod -R 777 /mnt/bdb"
				
				cmd="$base/IQ-Twemcached/src/twemcache -q 1 -Q 1 -i /mnt/bdb -w 1 -F 1 -t $threadsPerCMI -c 8192 -m 10000 -g 7000 -G 999999 -p $port"

				#cmd="$base/IQ-Twemcached/src/twemcache -t $threadsPerCMI -c 8192 -m 10000 -g 7000 -G 999999 -p $port"

				ssh -oStrictHostKeyChecking=no $ip "nohup $cmd > $dir/cache$ip-$port.txt &" &
				port=$((port+1))
				echo $cmd

				#sleep 5

				#cmd="db_deadlock -h /mnt/bdb -L $dir/deadlock_log.txt -v -t 0.10000"
				#ssh -oStrictHostKeyChecking=no $ip "nohup $cmd > $dir/dl_log.txt &" &
			done
		done
        	echo "Started cache $cache."
	fi
	#exit 0

	sleep 5

        sleepcount="0"
        for ip in ${cacheips[@]}
        do
                while ssh -oStrictHostKeyChecking=no $ip "screen -list | grep -q tpcc"
                do
                        ((sleepcount++))
                        sleep 30
                        echo "waiting for $ip "
                done
        done
	
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
	ssh $cli "rm -r $bench/results/*"
	numClis=${#clis[@]}
#	exit -1

	numThreadsPerCli=$((threads / (numClis * cliperserver)))
	remain=$((threads - (numThreadsPerCli * numClis * cliperserver)))
        echo "Num warehouses per client "$numThreadsPerCli" and remain "$remain
	minw=1
	maxw=1
	for cli in ${clis[@]}
	do
		for ((i=0; i < $cliperserver; i++))
		do

			if [ $remain -gt 0 ]; then
				numThreads=$((numThreadsPerCli+1))	
				remain=$((remain-1))			
			else
				numThreads=$numThreadsPerCli
			fi
			maxw=$((minw + numThreads-1))

			if [ $maxw -gt $warehouses ]; then
				maxw=$warehouses
			fi

			if [ $numThreads -gt 0 ]; then			
				cmd="bash $bench/tpcc_runbench.sh $cache $cli $dir $ar $batch $memcache $numThreads $warehouses $arsleep $minw $maxw 1.0 $rep $storesess false"
				echo $cmd
				ssh -oStrictHostKeyChecking=no -n -f $cli screen -S tpcc -dm $cmd
			fi
			minw=$((maxw+1))

			if [[ $maxw == $warehouses ]]; then 
				break 
			fi
		done
               	
		if [[ $maxw == $warehouses ]]; then
                	break 
                fi   
	done

	sleepcount="0"
	for cli in ${clis[@]}
	do
		while ssh -oStrictHostKeyChecking=no $cli "screen -list | grep -q tpcc"
		do
			((sleepcount++))
			sleep 10
			echo "waiting for $cli "
		done
	done

	# get cachestats
	for ip in ${cacheips[@]}
	do
		{ sleep 2; echo "stats"; sleep 2; echo "quit"; sleep 1; } | telnet $ip 11211 > $dir/"cachestats.txt"
	done

	echo "Copy results"
        ssh $cli "cp $bench/results/* $dir"
	ssh $cli "rm -r $bench/results/*"
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
