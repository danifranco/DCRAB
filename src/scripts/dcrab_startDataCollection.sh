#!/bin/bash

i=0
DCRAB_HOSTNAME=`hostname`
while [ 1 ]; do
	sleep 10
	echo "$i" >> "$1/$DCRAB_HOSTNAME"_data.txt
	i=$((i + 1))
done
