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
# Only if the main node's DCRAB instance isn't still in execution this function will stop DCRAB. For this check
# a few attemps will be done with the DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE file counter
#
dcrab_check_alive_main_node() {

	if [ -f $DCRAB_WAIT_MPI_PROCESSES_FILE ]; then

		# Indicate the main node that this node will wait for the next MPI job
	        echo "1" > $DCRAB_WAIT_MPI_PROCESSES_FILE
	
	        # If the main node's DCRAB instance is still alive, which means that the job is still alive also, do not stop the process
	        # and wait until a new MPI job reaches, otherwise DCRAB will be stopped. This check will be done in 90 seconds.
	        if [ -f $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE ]; then
	                counter=$(cat $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE)
	                DCRAB_CHECK_ALIVE_ATTEMPS=0
	                DCRAB_CHECK_NO_ALIVE_ATTEMPS=0
	                while [ 1 ]; do
				echo "Checking alive on the main node (30 seconds sleep)"
	                        sleep 30        
	                        nextCounter=$(cat $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE)
	                        if [ $counter -eq $nextCounter ]; then
	                                DCRAB_CHECK_NO_ALIVE_ATTEMPS=$((DCRAB_CHECK_NO_ALIVE_ATTEMPS + 1))
	                                [ $DCRAB_CHECK_NO_ALIVE_ATTEMPS -ge 3 ] && break
	                        else
					DCRAB_CHECK_NO_ALIVE_ATTEMPS=0
	                                DCRAB_CHECK_ALIVE_ATTEMPS=$((DCRAB_CHECK_ALIVE_ATTEMPS + 1))
	                                [ $DCRAB_CHECK_ALIVE_ATTEMPS -ge 3 ] && break
	                        fi
	                        counter=$nextCounter
		        done
	
	                # If the main node didn't modify the DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE will advice that the processes there have been stopped so 
	                # DCRAB will be stopped
	                if [ $DCRAB_CHECK_NO_ALIVE_ATTEMPS -ge 3 ]; then
	                        echo "Waiting too much time to control_port$DCRAB_NUMBER_OF_MPI_COMMANDS"
	                        echo "DCRAB stop"
	                        exit 3
	                else
	                        echo "The main node is still alive so we will wait more"
	                fi
	        else
	                echo "The file $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE can not be read and no control_port file was created"
	                echo "DCRAB stop"       
	                exit 3
	        fi
	else
		echo "There is no $DCRAB_WAIT_MPI_PROCESSES_FILE file so directory has been deleted or moved"
                echo "DCRAB stop"      
                exit 3
	fi
}


#
# Checks exit status in different situations
# Arguments:
#	1- Int --> 	With '0' checks exit conditions while the script tries to take the lock 
#   			With '1' checks exit conditions in the main loop of the monitoring script in the nodes  
#
dcrab_check_exit () {

	case $1 in
	0)
		# To avoid block in the loop when the number of attemps is greater than a certain value 
		if [ "$j" -ge "$DCRAB_LOOP_BEFORE_CRASH" ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: too many attemps to write in the main html report" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 4 
		# Finish if the report directory has been removed or moved
		elif [ ! -d "$DCRAB_REPORT_DIR" ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 5
		fi
	;;
	1)
		# Finish if the report directory has been removed or moved
		if [ ! -d "$DCRAB_REPORT_DIR" ] && [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
			echo "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			echo "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
			exit 5
		fi

		# Finish if all the processes in the current node and in the main node have finished
		if [ -f $DCRAB_USER_PROCESSES_FILE ]; then
			if [ $DCRAB_TOTAL_PROCESSES -eq 0 ]; then
				
				# To check if the main node is still in execution
				dcrab_check_alive_main_node

				# If the check_alive_main_node function didn't stop DCRAB means that on the main node are still processes executing 
				# so it will wait until another MPI job reaches
				DCRAB_SLEEP_FOR_NEXT_MPI_JOB=1	
                	fi	
		else
			echo "DCRAB terminated: the file $DCRAB_USER_PROCESSES_FILE can not be read"
                        echo "DCRAB stop" 
                        exit 6	
		fi
	;;
	esac
}


#
# Stops DCRAB's processes 
#
dcrab_finalize () {

	if [ -d "$DCRAB_REPORT_DIR" ]; then
		# Restore environment
		source $DCRAB_REPORT_DIR/aux/env.txt
	
		# Kill remote processes running in background
	        i=0
	        echo "DCRAB processes started in compute nodes have these PIDs: "${DCRAB_PIDs[*]}
	
	        for node in $DCRAB_NODES; do
	                echo "Killing the DCRAB's process with PID ${DCRAB_PIDs[$i]} in the node $node"
	                ssh -f $node "$COMMAND"
	                i=$((i+1))
	        done	
	fi
}
