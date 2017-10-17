#!/bin/bash

dcrab_stop_remote_processes () {
	# Kill remote remora processes running in background
	i=0
	echo "PID: "${DCRAB_PIDs[*]}
	
	for node in $DCRAB_NODES; do
		echo "Node: $node"
		COMMAND="kill ${DCRAB_PIDs[$i]}"
		echo "Comando: $COMMAND"
	        ssh -f $node "$COMMAND"
	        i=$((i+1))
	done
}
