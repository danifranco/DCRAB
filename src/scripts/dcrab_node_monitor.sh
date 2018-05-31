#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Author: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script is the core of the nodes monitoring
#
# Arguments:
#
#  1- aux/env.txt      <-- Used to store environment
#  2- int              <-- Node number 
#  3- dcrab_$node.log  <-- Log file
# 
# Do NOT execute manually. DCRAB will start it automatically
#
# ===============================================================================================================

# Redirect all the output to DCRAB log file
exec 1>$3 2>&1
echo "--- DCRAB `hostname` log ---" 

# Sets environment
source "$1"

# To ensure the environment has been set up correctly 
if [ "$DCRAB_WORKDIR" == "" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") [JOB: $DCRAB_JOB_ID] ERROR: An error occurred while setting up the environmet sourcing $1 file"    
    echo "$(date "+%Y-%m-%d %H:%M:%S") [JOB: $DCRAB_JOB_ID] ERROR: DCRAB stop"
    exit 1
fi

cd $DCRAB_WORKDIR

source $DCRAB_PATH/src/scripts/dcrab_internal_report_functions.sh
source $DCRAB_PATH/src/scripts/dcrab_node_monitoring_functions.sh
source $DCRAB_PATH/src/scripts/dcrab_finalize.sh
source $DCRAB_PATH/src/scripts/dcrab_report_functions.sh

dcrab_node_monitor_init_variables $2 
dcrab_determine_main_session

sleep $DCRAB_COLLECT_TIME
loopNumber=0
updates=0

###############
## MAIN LOOP ##
###############
while [ 1 ]; do

    loopNumber=$((loopNumber + 1))    
    eval $DCRAB_LOG_INFO "Loop number: $loopNumber" 

    dcrab_collect_data 

    # Insert collected data in the main .html page
    [ $DCRAB_INTERNAL_MODE -eq 0 ] && dcrab_update_report
    # The main node must write some data for the internal report
    [ $DCRAB_NODE_EXECUTION_NUMBER -eq 0 ] && dcrab_write_internal_data

    sleep $DCRAB_COLLECT_TIME
    
    dcrab_check_exit 1

    [ $DCRAB_SLEEP_FOR_NEXT_MPI_JOB -eq 1 ] && dcrab_wait_control_port
done
