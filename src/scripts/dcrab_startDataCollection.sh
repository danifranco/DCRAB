#!/bin/bash

i=0
DCRAB_NODE_HOSTNAME=`hostname`
while [ 1 ]; do
	sleep 3
	echo "$i" >> "$1/$DCRAB_NODE_HOSTNAME"_data.txt
	i=$((i + 1))
done
