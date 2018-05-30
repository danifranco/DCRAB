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
# Check if the main node is still executing the job. For this check a few 
# attemps to ensure main node's state before doing something
#
dcrab_check_alive_main_node() {

    if [ -f $DCRAB_WAIT_MPI_PROCESSES_FILE ]; then

        # Indicate the main node that this node will wait for the next MPI job
        echo "1" > $DCRAB_WAIT_MPI_PROCESSES_FILE
    
        # If the main node's DCRAB instance is still alive, which means that the job is still alive also, do not stop the process
        # and wait until a new MPI job reaches, otherwise DCRAB will be stopped. 
        if [ -f $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE ]; then

            counter=$(cat $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE)

            DCRAB_CHECK_ALIVE_ATTEMPS=0
            DCRAB_CHECK_NO_ALIVE_ATTEMPS=0

            while [ 1 ]; do
                eval $DCRAB_LOG_INFO "Checking alive on the main node \(30 seconds sleep\)"
                sleep 30        
    
                if [ -f $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE ]; then
                    nextCounter=$(cat $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE)
 
                    if [ $counter -eq $nextCounter ]; then
                        DCRAB_CHECK_NO_ALIVE_ATTEMPS=$((DCRAB_CHECK_NO_ALIVE_ATTEMPS + 1))
                        eval $DCRAB_LOG_INFO "Exit \($DCRAB_CHECK_NO_ALIVE_ATTEMPS/3\)"
                        [ $DCRAB_CHECK_NO_ALIVE_ATTEMPS -ge 3 ] && break
                    else
                        DCRAB_CHECK_NO_ALIVE_ATTEMPS=0
                        DCRAB_CHECK_ALIVE_ATTEMPS=$((DCRAB_CHECK_ALIVE_ATTEMPS + 1))
                        eval $DCRAB_LOG_INFO "Continue \($DCRAB_CHECK_ALIVE_ATTEMPS/3\)"
                        [ $DCRAB_CHECK_ALIVE_ATTEMPS -ge 3 ] && break
                    fi
                    counter=$nextCounter
                else    
                    eval $DCRAB_LOG_ERROR "The file $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE does not exist"
                    eval $DCRAB_LOG_ERROR "DCRAB stop"
                    exit 1 
                fi
            done
     
            # If the main node didn't modify the DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE will advice that the processes there have been stopped so 
            # DCRAB will be stopped
            if [ $DCRAB_CHECK_NO_ALIVE_ATTEMPS -ge 3 ]; then
                eval $DCRAB_LOG_ERROR "There is no processes in the main node"
                eval $DCRAB_LOG_ERROR "DCRAB stop"
                exit 1
            else
                eval $DCRAB_LOG_INFO "The main node is still alive so we will wait more"
            fi

        else
            eval $DCRAB_LOG_ERROR "The file $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE can not be read and no control_port file was created"
            eval $DCRAB_LOG_ERROR "DCRAB stop"       
            exit 1
        fi

    else
        eval $DCRAB_LOG_ERROR "There is no $DCRAB_WAIT_MPI_PROCESSES_FILE file so directory has been deleted or moved"
        eval $DCRAB_LOG_ERROR "DCRAB stop"      
        exit 1
    fi
}


#
# Checks exit status in different situations
#
# Arguments:
#    1- Int -->  When '0' checks exit conditions while the script tries to take the lock 
#                When '1' checks exit conditions in the main loop of the monitoring script in the nodes  
#
dcrab_check_exit () {

    case $1 in
    0)
        # To avoid block in the loop when the number of attemps is greater than a certain value 
        if [ "$j" -ge "$DCRAB_LOOP_BEFORE_CRASH" ]; then
            eval $DCRAB_LOG_ERROR "ERROR in $DCRAB_NODE_HOSTNAME: too many attemps to write in the main html report" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            eval $DCRAB_LOG_ERROR "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            exit 1 
        # Finish if the report directory has been removed or moved
        elif [ ! -d "$DCRAB_REPORT_DIR" ]; then
            eval $DCRAB_LOG_ERROR "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            eval $DCRAB_LOG_ERROR "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            exit 1
        fi
        ;;
    1)
        # Finish if the report directory has been removed or moved
        if [ ! -d "$DCRAB_REPORT_DIR" ] && [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
            eval $DCRAB_LOG_ERROR "ERROR in $DCRAB_NODE_HOSTNAME: DCRAB directory has been deleted or moved" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            eval $DCRAB_LOG_ERROR "DCRAB stop" >> $DCRAB_WORKDIR/DCRAB_ERROR_"$DCRAB_NODE_HOSTNAME"_"$DCRAB_JOB_ID"
            exit 1
        fi

        # Finish if all the processes in the current node and in the main node have finished
        if [ -f $DCRAB_USER_PROCESSES_FILE ]; then
            if [ $DCRAB_TOTAL_PROCESSES -eq 0 ]; then
                if [ "$DCRAB_NODE_EXECUTION_NUMBER" -ne 0 ]; then                            
                    eval $DCRAB_LOG_INFO "All the processes have finished. Checking if the main node is still executing the job"                    

                    # Check if the main node is still in execution
                    dcrab_check_alive_main_node
    
                    # If the check_alive_main_node function didn't stop DCRAB means that on the main node are still processes executing 
                    # so it will wait until another MPI job reaches
                    DCRAB_SLEEP_FOR_NEXT_MPI_JOB=1    
                else    
                    eval $DCRAB_LOG_INFO "DCRAB terminated: all the processes of the job have finished"
                    eval $DCRAB_LOG_INFO "DCRAB stop"
                    exit 0
                fi
            fi    
        else
            eval $DCRAB_LOG_ERROR "DCRAB terminated: the file $DCRAB_USER_PROCESSES_FILE can not be read"
            eval $DCRAB_LOG_ERROR "DCRAB stop" 
            exit 1    
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
    
        i=0
        eval $DCRAB_LOG_INFO "DCRAB processes started in compute nodes have these PIDs: "${DCRAB_PIDs[*]}
	
        # Kill remote processes running in background 
        for node in $DCRAB_NODES; do
            eval $DCRAB_LOG_INFO "Killing the DCRAB's process with PID ${DCRAB_PIDs[$i]} in the node $node"
            ssh -f $node "kill ${DCRAB_PIDs[$i]}"
            i=$((i+1))
        done    
    fi
}
