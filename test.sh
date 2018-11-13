#!/bin/bash

output=${1}

echo "Waiting before db_stat..."
#sleep 120

find /mnt -maxdepth 5 -type f -print0 |
  while IFS= read -rd '' dir; do 
    if [[ $dir == *"."db ]]
    then
      size=$(stat -c%s "$dir")
      echo "DB $dir $size" >> $output
#      db_stat -d $dir -f >> $output
    fi

  done
