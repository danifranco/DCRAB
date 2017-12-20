#!/bin/bash
# DCRAB SOFTWARE
# Version: 1.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script is the core of the monitorization of the nodes. Is used in 'dcrab_start_data_collection' function 
# inside 'scripts/dcrab_config.sh' file.
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

# Move to the working directory
cd $DCRAB_WORKDIR

# Source modules
source $DCRAB_BIN/scripts/dcrab_node_report_functions.sh

# Initialize variables
init_variables $2

# Write first values in the main html report 
write_initial_values

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
	echo "H: $node_hostname - loop $loopNumber" 

	# Update and collect data
	dcrab_update_data 

	# Insert collected data in the main .html page
	write_data 

	# Sleep to the next data collection
        sleep $DCRAB_COLLECT_TIME
	
	# To avoid block in the loop 
        dcrab_check_exit 1
done
