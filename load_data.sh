#!/bin/bash

bench="/proj/BG/yaz/ycsbcache/oltpbench-wb"
warehouses=1000
threads=100
warehouses=1000

cd $bench
./oltpbenchmark -b tpcc -c config/tpcc_mysql.xml --create=true --load=true --scalefactor=$warehouses --threads=$threads

