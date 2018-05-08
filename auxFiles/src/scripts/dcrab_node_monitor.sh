#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script is the core of the monitorization of the nodes
#
# Arguments:
#
#  1- aux/env.txt  	<-- Used to store environment
#  2- int	   	<-- Node number 
#  3- dcrab_$node.log	<-- Log file
# 
# Do NOT execute manually. DCRAB will start it automatically
#
# ===============================================================================================================


# Redirect all the output to DCRAB log file
exec >> $3 ; exec 2>&1
echo "--- DCRAB `hostname` log ---" 

# Sets environment
source "$1"

cd $DCRAB_WORKDIR

# Source modules
source $DCRAB_PATH/scripts/dcrab_internal_report_functions.sh
source $DCRAB_PATH/scripts/dcrab_node_monitoring_functions.sh
source $DCRAB_PATH/scripts/dcrab_finalize.sh
source $DCRAB_PATH/scripts/dcrab_report_functions.sh

# Initialize variables
dcrab_node_monitor_init_variables $2 

# Determines the main processes of the job and initializes html file first time 
dcrab_determine_main_process 

sleep $DCRAB_COLLECT_TIME

###############
## MAIN LOOP ##
###############
loopNumber=0
updates=0
while [ 1 ]; do

	loopNumber=$((loopNumber + 1))	
	echo "H: $DCRAB_NODE_MONITOR - loop $loopNumber" 

	# Update and collect data
	dcrab_update_data 

	# Insert collected data in the main .html page
	[ $DCRAB_INTERNAL_MODE -eq 0 ] && dcrab_update_report
	
	# The main node must write some data for the internal report
	[ $DCRAB_NODE_NUMBER -eq 0 ] && dcrab_write_internal_data

	# Sleep to the next data collection
	sleep $DCRAB_COLLECT_TIME
	
	# To avoid block in the loop 
	dcrab_check_exit 1
done
