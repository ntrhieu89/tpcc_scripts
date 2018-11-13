#!/bin/bash

n=$1

for i in {0..40}
do
  echo "Kill processes on h$i"
  ssh h$i "killall sar"
  ssh h$i "killall java"
  ssh h$i "killall twemcache" 
  ssh h$i "rm /tmp/clienth*"
done

for i in {1..40}
do
  ssh h$i "killall /bin/bash"
done

#ssh h0 "killall /bin/bash"
