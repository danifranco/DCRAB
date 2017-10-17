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
#  3- int   	   	<-- Time of desynchronization. To try not overlapping the writes on the .html file.
#  4- dcrab_$node.log	<-- Log file
# 
# Do NOT execute manually. DCRAB will start it automatically
#
# ===============================================================================================================


# Redirect all the output to DCRAB log file
exec >> $4 ; exec 2>&1
echo "--- DCRAB `hostname` log ---" 

# Sets environment
source "$1"

# Move to the working directory
cd $DCRAB_WORKDIR

# Source modules
source $DCRAB_BIN/scripts/dcrab_node_report_functions.sh

# Necessary variables
DCRAB_NODE_NUMBER=$2
node_hostname=`hostname`
node_hostname_mod=`echo $node_hostname | sed 's|-||g'`
DCRAB_PROCESS_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_process_$node_hostname.txt
DCRAB_MEM_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_mem_$node_hostname.txt

# Save the line to inject CPU data
addRow_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addRow space \*\/" $DCRAB_HTML | cut -f1 -d:`
addColumn_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addColumn space \*\/" $DCRAB_HTML | cut -f1 -d:`

# CPU
cpu_addRow_inject_line=$((addRow_data_line + 2))
cpu_addColumn_inject_line=$((addColumn_data_line + 1))

# MEM
mem_addRow_inject_line=$((addRow_data_line + 6))
memUsed_addRow_inject_line=$((addRow_data_line + 10))
memUnUsed_addRow_inject_line=$((addRow_data_line + 11))
node_total_mem=`free -g | grep "Mem" | awk ' {printf $2}'`

# Sleep first time to desynchronize with other nodes
sleep "$3"
dcrab_determine_main_process 


###############
## MAIN LOOP ##
###############
loopNumber=1
updates=0
while [ 1 ]; do
	# Sleep to the next data collection
	sleep $DCRAB_COLLECT_TIME
	
	echo "H: $node_hostname - loop $loopNumber" 

	# Update and collect data
	dcrab_update_data 

	# Insert CPU data in the main .html page
	write_data 0

	# Insert MEM data in the main .html page
	write_data 1

	loopNumber=$((loopNumber + 1))
done



