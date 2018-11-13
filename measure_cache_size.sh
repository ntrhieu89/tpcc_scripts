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
cacheips=( "h0")
cacheperserver="1"
threadsPerCMI="8"

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
clis=( "h0" )

machines=( $dbip ${cacheips[@]} ${clis[@]} )
echo ${machines[@]}
#exit -1

warehouses="1"
copydb="false"

for warehouses in 1
do
for dpw in 1000
do
for cpd in 3000 30000
do
	# create a dir
	dir="cachesize-w-"$warehouses"-d-"$dpw"-c-"$cpd

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
		./oltpbenchmark -b tpcc -c config/tpcc_mysql.xml --create=true --load=true --scalefactor=$warehouses --threads=100 --distperwhse=$dpw --custperdist=$cpd
		cd $base/scripts/ngcache
	fi
	echo "Loaded database."

	#exit -1

	# start cache
		echo "Start cache"

		for ip in ${cacheips[@]}
		do
                        ssh -oStrictHostKeyChecking=no $ip "killall twemcache"
                        sleep 2

			port=11211
			for ((i=0; i < $cacheperserver; i++))
			do
				ssh -oStrictHostKeyChecking=no $ip "nohup $base/IQ-Twemcached/src/twemcache -t $threadsPerCMI -c 8192 -m 48000 -g 7000 -G 999999 -p $port > $dir/cache$ip-$port.txt &" &
				port=$((port+1))
			done
		done
        	echo "Started cache $cache."

	sleep 5

	# perform warm up
	numClis=${#cacheips[@]}
	numThreadsPerWarmupCli=$((warehouses / numClis))

		for ((i=0; i < $numClis; i++))
		do
			min=$((i*numThreadsPerWarmupCli + 1))
			max=$(( (i+1) * numThreadsPerWarmupCli ))
			remain=$((warehouses - max))
			if [ $remain -ge $numThreadsPerWarmupCli ]; then
				cmd="bash $bench/tpcc_warmup.sh $warehouses $memcache $dbip hieun golinux $min $max $dpw $cpd"
			else
				cmd="bash $bench/tpcc_warmup.sh $warehouses $memcache $dbip hieun golinux $min $warehouses $dpw $cpd"
			fi
			echo "Warmup up "$cmd
			ssh -oStrictHostKeyChecking=no -n -f ${cacheips[$i]} screen -S tpcc -dm $cmd
		done		

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

 	{ sleep 2; echo "stats"; sleep 2; echo "quit"; sleep 1; } | telnet h0 11211 > $dir/"cachestats.txt"
done
done
done
