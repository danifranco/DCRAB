#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains the functions to stop DCRAB
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================


#
# Checks exit status in different situations
# Arguments:
#	1- Int --> 	With '0' checks exit conditions while the script tries to take the lock 
#   			With '1' checks exit conditions for the main loop of the monitoring script in the nodes  
#
dcrab_check_exit () {

	case $1 in
	0)
		# To avoid block in the loop when the number of attemps is greater than a certain value 
		if [ "$j" -ge "$DCRAB_LOOP_BEFORE_CRASH" ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: too many attemps to write in the main html report" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 1
		# Finish if the report directory has been removed or moved
		elif [ ! -d "$DCRAB_REPORT_DIR" ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 2
		fi
	;;
	1)
		# Finish DCRAB if the main process has finished. This avoids DCRAB continues running if
		# the scheduler kills the job before the execution of 'dcrab finish'
		kill -0 $DCRAB_FIRST_MAIN_PROCESS_PID >> /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "DCRAB terminated: first main process '$DCRAB_FIRST_MAIN_PROCESS_NAME, PID: $DCRAB_FIRST_MAIN_PROCESS_PID' has been killed"
			echo "DCRAB stop" 
			exit 0
		# Finish if the report directory has been removed or moved
		elif [ ! -d "$DCRAB_REPORT_DIR" ] && [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 2
		fi
	;;
	esac
}


#
# Stops DCRAB execution
#
dcrab_finalize () {

	if [ -d "$DCRAB_REPORT_DIR" ]; then
		# Restore environment
		source $DCRAB_REPORT_DIR/aux/env.txt
	
		# Kill remote processes running in background
	        i=0
	        echo "PID: "${DCRAB_PIDs[*]}
	
	        for node in $DCRAB_NODES; do
	                echo "Node: $node"
	                COMMAND="kill ${DCRAB_PIDs[$i]}"
	                echo "Comando: $COMMAND"
	                ssh -f $node "$COMMAND"
	                i=$((i+1))
	        done	
	fi
}
