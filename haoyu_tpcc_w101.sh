#!/bin/bash

base="/proj/BG/yaz/ycsbcache"
bench="/proj/BG/yaz/ycsbcache/oltpbench-hi"
results="/tmp/results"
exp_results_dir="/proj/BG/yaz/ycsbcache/wb-results"
cache_dir="/proj/BG/yaz/ycsbcache/IQ-Twemcached-wb"

# Rebuild the project
cd $bench
ant
cd /proj/BG/yaz/ycsbcache/scripts/ngcache

mkdir -p $results

#cache="true"
#nthreads="100"

#sleep 14400

dbip="h0"
cacheips=( "h11" "h12" "h13" "h14" "h15" "h16" "h17" "h18" "h19" "h20" )
cacheperserver="10"
total_caches=$((${#cacheips[@]}*$cacheperserver))
echo "total caches: $total_caches"

threadsPerCMI="2"
rep=1
storesess="false"
parallel="true"

memcache=""
cache_instances=()
port=11211
cliperserver="10"
clis=( "h1" "h2" "h3" "h4" "h5" "h6" "h7" "h8" "h9" "h10" )
machines=( $dbip ${cacheips[@]} ${clis[@]} )
echo ${machines[@]}

for ((i=0; i < $cacheperserver; i++))
do
	for ip in ${cacheips[@]}
	do
		memcache=$memcache$ip":$port,"
		cache_instances=(${cache_instances[@]} "$ip:$port")
	done
	port=$((port+1))
done
memcache=${memcache::-1}
echo $memcache
echo "cache instances: ${cache_instances[@]}"

batch="100"
copydb="true"
arsleep="0"
storesess="false"
manualwarmup="true"
eviction="false"
threads="1"
threadsPerCMI="2"
ar=1
for warehouses in 100
do
	for cache in "true"
	do
		for try in 1
		do
			for parallel in "true"
			do
				for rep in 2 3
				do
			        if [[ $rep == "1" ]]; then
			                parallel="false"
			        else
					parallel="true"
				fi
				
			        echo "Parallel = "$parallel
					for eviction in "false" "true"
					do
						for cachesize in 6000 4 30
						do
							for persistMode in "async_bdb"
							do
								for threadsPerCMI in "2"
								do
									dir=$results

									# skip 
									if [[ $eviction == "false" ]]; then
										if [[ $cachesize -lt 6000 ]]; then
											continue
										fi
									fi
									if [[ $eviction == "true" ]]; then
										if [[ $cachesize == "6000" ]]; then
											continue
										fi
									fi
									if [[ $eviction == "true" ]]; then
										if [[ $persistMode == "no_persist" ]]; then
											continue
										fi
									fi

									kkk="bdb-$cache-w-$warehouses-ar-$ar-th-$threads-tpc-$threadsPerCMI-cps-$cacheperserver-pm-$persistMode-rep-$rep-cz-$cachesize-eviction-$eviction"   
									echo "running experiment $kkk"

									for m in ${machines[@]}
									do
										echo "remove $dir at machine $m"
							        	ssh $m "sudo rm -rf $dir"
								        ssh $m "sudo mkdir -p $dir"
								        ssh $m "sudo chmod -R 777 $dir"
									done
									
							        for cli in ${clis[@]}
							        do
										echo "kill java at $cli"
										ssh $cli "killall java"
									done
							        for ip in ${cacheips[@]}
							        do
							        	echo "kill java at $ip"
							            ssh $ip "killall java"
							            ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
							            ssh $ip "sudo rm -rf /mnt/bdb*"
							        done

							        # start cache
									if [ $cache == "true" ]; then
										echo "Start cache with size $cachesize"

										for ip in ${cacheips[@]}
										do
					                        sleep 2
											port=11211
											for ((i=0; i < $cacheperserver; i++))
											do
												time=$(date +%s%N)
												ssh $ip "sudo mkdir -p /mnt/bdb-$persistMode-$ip-$port-$time"
												ssh $ip "sudo chmod -R 777 /mnt/bdb-$persistMode-$ip-$port-$time"

												if [[ $persistMode == "async_bdb" ]]; then
													cmd="nohup $cache_dir/src/twemcache -q 1 -i /mnt/bdb-$persistMode-$ip-$port-$time -w 100 -F 1 -t $threadsPerCMI -c 8192 -m $cachesize -g 7000 -G 999999 -p $port"
												elif [[ $persistMode == "sync_bdb" ]]; then
													cmd="nohup $cache_dir/src/twemcache -q 1 -Q 1 -i /mnt/bdb-$persistMode-$ip-$port-$time -w 100 -F 1 -t $threadsPerCMI -c 8192 -m $cachesize -g 7000 -G 999999 -p $port"
												else
													cmd="nohup $cache_dir/src/twemcache -t $threadsPerCMI -c 8192 -m $cachesize -g 7000 -G 999999 -p $port"
												fi

												if [[ $eviction == "true" ]]; then
													cmd=$cmd" -T 1"
												fi

												echo $cmd
												ssh -oStrictHostKeyChecking=no $ip "$cmd >& $dir/cachelog$ip.$port.txt &" &
												port=$((port+1))
											done
										done
								        echo "Started cache $cache."
									fi

									# copy database
									if [[ $copydb == "true" ]]; then
										sudo service mysql stop
										sudo cp -av $base/mysql_tpcc_"$warehouses"w/* /mnt/mysql
										sudo chmod -R 777 /mnt/mysql
										sudo service mysql start
									else
										cd $bench
										./oltpbenchmark -b tpcc -c config/tpcc_mysql.xml --create=true --load=true --scalefactor=$warehouses --threads=$threads
										cd $base/scripts/ngcache
									fi
									echo "Loaded database."

									sleep 60

							   #      if [ $cache == "true" ]; then
										# cache_instance_id=0
										# warehouse_id=1
										# for ip in ${cacheips[@]}
										# do
										# 	for ((i=0; i < $cliperserver; i++))
										# 	do
										# 		cache_instance=${cache_instances[$cache_instance_id]}
										# 		if [[ $rep -eq 2 ]]; then
										# 			sid=$((($cache_instance_id+1)%$total_caches))
										# 			echo "$cache_instance,${cache_instances[$sid]}"
										# 		elif [[ $rep -eq 3 ]]; then
										# 			sid=$((($cache_instance_id+1)%$total_caches))
										# 			tid=$((($cache_instance_id+2)%$total_caches))
										# 			echo  "$cache_instance,${cache_instances[$sid]},${cache_instances[$tid]}"
										# 		fi

										# 		cmd="bash $bench/tpcc_warmup.sh $warehouses $cache_instance $dbip hieun golinux $warehouse_id $warehouse_id 10 3000"
										# 		echo $cmd
										# 		ssh -oStrictHostKeyChecking=no -n -f $ip screen -S tpcc$i -dm $cmd
										# 		((cache_instance_id++))
										# 		((warehouse_id++))
										# 	done
										# done
							   #      fi

							   #      sleepcount="0"
							   #      for ip in ${cacheips[@]}
							   #      do
							   #      	for ((i=0; i < $cliperserver; i++))
										# do
							   #              while ssh -oStrictHostKeyChecking=no $ip "screen -list | grep -q tpcc$i"
							   #              do
						    #                     ((sleepcount++))
						    #                     sleep 10
						    #                     echo "waiting for $ip $i"
							   #              done
							   #          done
							   #      done

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
									echo "remove $bench/results/* from at $cli"
									rm -r $bench/results/*
									
									cache_instance_id=0
									warehouse_id=1
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

											cmd="bash $bench/tpcc_runbench.sh $cache $cli $dir $ar $batch $cache_instance 1 $warehouses $arsleep $warehouse_id $warehouse_id 1.0 $rep $storesess $parallel $persistMode $manualwarmup"
											echo $cmd
											ssh -oStrictHostKeyChecking=no -n -f $cli screen -S tpcc$i -dm $cmd
											((cache_instance_id++))
											((warehouse_id++))
										done
									done

									sleepcount="0"
									for cli in ${clis[@]}
									do
										for ((i=0; i < $cliperserver; i++))
										do
											while ssh -oStrictHostKeyChecking=no $cli "screen -list | grep -q tpcc$i"
											do
												((sleepcount++))
												sleep 10
												echo "waiting for $cli $i "
											done
										done
									done

							        # get cachestats
							        for ip in ${cacheips[@]}
							        do
										port=11211
										for ((i=0; i < $cacheperserver; i++))
										do
								            { sleep 2; echo "stats"; sleep 2; echo "quit"; sleep 1; } | telnet $ip $port > $dir/"cachestats$ip-$port.txt"
											port=$((port+1))
										done

										ssh $ip "top -b -n 1 > $dir/log-mem-bdb-$ip.txt" &
										ssh $ip "bash $base/scripts/ngcache/test.sh $dir/log-bdb-$ip.txt" &
								    done

									echo "Copy results in $cli"
								    sudo cp $bench/results/* $dir
									rm -r $bench/results/*

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

									grep "NewOrder" $dir/*.csv | wc -l > $dir/totalNewOrder$m.out
									grep "Payment" $dir/*.csv | wc -l > $dir/totalPayment$m.out
									grep "Delivery" $dir/*.csv | wc -l > $dir/totalDelivery$m.out
									grep "OrderStatus" $dir/*.csv | wc -l > $dir/totalOrderStatus$m.out
									grep "StockLevel" $dir/*.csv | wc -l > $dir/totalStockLevel$m.out
									python anas.py $dir &
									python admCntrl.py $dir/throughput.txt $dir/throughput &
							        python admCntrl.py $dir/NewOrder.txt $dir/NewOrderLatency &
							        python admCntrl.py $dir/Payment.txt $dir/PaymentLatency &
							        python admCntrl.py $dir/Delivery.txt $dir/DeliveryLatency &
							        python admCntrl.py $dir/OrderStatus.txt $dir/OrderStatusLatency &
							        python admCntrl.py $dir/StockLevel.txt $dir/StockLevelLatency &

									# collect stats
									for m in ${machines[@]}
									do
										ssh -oStrictHostKeyChecking=no $m "killall sar" &
									done

									# draw graphs
									for m in ${machines[@]}
									do
										java -jar ExtractSarInfo.jar CPU $dir/"$m"-cpu.txt $dir/tmp-"$m"-cpu.txt &
										java -jar ExtractSarInfo.jar NET $dir/"$m"-net.txt $dir/tmp-"$m"-net.txt &
										java -jar ExtractSarInfo.jar MEM $dir/"$m"-mem.txt $dir/tmp-"$m"-mem.txt &
										java -jar ExtractSarInfo.jar DISK $dir/"$m"-disk.txt $dir/tmp-"$m"-disk.txt &

										echo "==========================="
										python admCntrl.py $dir/tmp-"$m"-cpu.txt $dir/"$m"-cpu &
						                python admCntrl.py $dir/tmp-"$m"-net.txt $dir/"$m"-net &
						                python admCntrl.py $dir/tmp-"$m"-mem.txt $dir/"$m"-mem &
						                python admCntrl.py $dir/tmp-"$m"-disk.txt $dir/"$m"-disk &
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
