#!/bin/bash


# Kill remote remora processes running in backgroud
idx=0
echo ${PID[*]}
for NODE in $NODES; do
        ssh -f $NODE 'kill '${PID[$idx]} 
        idx=$((idx+1))
done

