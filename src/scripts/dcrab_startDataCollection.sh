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

# Necessary variables
DCRAB_NODE_NUMBER=$2
DCRAB_DCRAB_PID=$$
node_hostname=`hostname`
node_hostname_mod=`echo $node_hostname | sed 's|-||g'`
DCRAB_WAIT_TIME_CONTROL=180 # 3 minutes
DCRAB_SLEEP_TIME_CONTROL=5
DCRAB_NUMBERS_OF_LOOPS_CONTROL=$(( DCRAB_WAIT_TIME_CONTROL / DCRAB_SLEEP_TIME_CONTROL ))
DCRAB_USER_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_user_processes_$node_hostname.txt
DCRAB_JOB_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_job_processes_$node_hostname.txt
DCRAB_MEM_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_mem_$node_hostname.txt

# Save the line to inject CPU data
addRow_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addRow space \*\/" $DCRAB_HTML | cut -f1 -d:`
addColumn_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addColumn space \*\/" $DCRAB_HTML | cut -f1 -d:`

# CPU
cpu_addRow_inject_line=$((addRow_data_line + 2))
cpu_addColumn_inject_line=$((addColumn_data_line + 1))
cpu_threshold="5.0"

# MEM
mem_addRow_inject_line=$((addRow_data_line + 6))
memUsed_addRow_inject_line=$((addRow_data_line + 10))
memUnUsed_addRow_inject_line=$((addRow_data_line + 11))
node_total_mem=`free -g | grep "Mem" | awk ' {printf $2}'`
mem_piePlot_color_line=$(grep -n -m 1 "var mem2_options =" | cut -f1 -d:)
mem_piePlot_color_line=$((mem_piePlot_color_line + 4))
mem_piePlot1_div_line=$(grep -n -m 1 "id='plot1_mem_$node_hostname_mod" $DCRAB_HTML | cut -f1 -d:)
mem_piePlot1_nodeMemory_line=$((mem_piePlot1_div_line + 4))
mem_piePlot1_requestedMemory_line=$((mem_piePlot1_div_line + 5))
mem_piePlot1_VmRSS_text_line=$((mem_piePlot1_div_line + 6))
mem_piePlot1_VmSize_text_line=$((mem_piePlot1_div_line + 7))
write_initial_values

# Determines the main processes of the job and initializes html file first time 
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

	# Insert collected data in the main .html page
	write_data 

	# To finish DCRAB if the main process has finished. This avoids DCRAB continues running if
	# the scheduler kills the job before the execution of 'dcrab finish'
	kill -0 $DCRAB_FIRST_MAIN_PROCESS_PID >> /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "DCRAB terminated. First main process '$DCRAB_FIRST_MAIN_PROCESS_NAME, PID: $DCRAB_FIRST_MAIN_PROCESS_PID' has been killed"
		break;
	fi

	loopNumber=$((loopNumber + 1))
done

