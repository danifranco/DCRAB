#!/bin/bash
# DCRAB SOFTWARE
# Version: 1.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains the functions to be done in the finalization of DCRAB. Used in DCRAB main script.
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================


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
