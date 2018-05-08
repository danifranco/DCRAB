#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# In the same way the main .html report is being completed for the user, DCRAB is going to store periodically 
# some collected data to make after an internal report with statistics.  
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================


#
# Initializes needed variables dor the internal report 
#
dcrab_internal_report_init_variables () {
	
	# File
	DCRAB_IREPORT_DATA_FILE="/scratch/administracion/admin/dcrab/data/$DCRAB_JOB_ID"

	# IB
        DCRAB_IREPORT_IB_TOTAL_DATA=0
	
	# DISK
	DCRAB_IREPORT_DISK_TOTAL_DATA=0
}



#
# Writes the data for the internal report
#
dcrab_write_internal_data () {

	DCRAB_IREPORT_IB_TOTAL_DATA=0
        DCRAB_IREPORT_DISK_TOTAL_DATA=0

	# Collect IB data 
        for file in $DCRAB_TOTAL_IB_DIR/*
        do
 	        local value=$(cat $file)
                DCRAB_IREPORT_IB_TOTAL_DATA=$(( DCRAB_IREPORT_IB_TOTAL_DATA + value ))
        done		

	# Collect DISK data 
        for file in $DCRAB_TOTAL_DISK_DIR/*
        do
 	        local value=$(cat $file)
                DCRAB_IREPORT_DISK_TOTAL_DATA=$(( DCRAB_IREPORT_DISK_TOTAL_DATA + value ))
        done		

	if [ "$DCRAB_FIRST_WRITE" -eq 1 -a $DCRAB_INTERNAL_MODE -eq 0 ] || [ "$DCRAB_FIRST_WRITE" -eq 0 -a $DCRAB_INTERNAL_MODE -eq 1 ]; then
		echo "$DCRAB_DIFF_TIMESTAMP $DCRAB_NNODES $DCRAB_IREPORT_IB_TOTAL_DATA $DCRAB_IREPORT_DISK_TOTAL_DATA" >> $DCRAB_IREPORT_DATA_FILE
		DCRAB_FIRST_WRITE=$((DCRAB_FIRST_WRITE + 1))
	else
		sed -i 's|.*|'"$DCRAB_DIFF_TIMESTAMP $DCRAB_NNODES $DCRAB_IREPORT_IB_TOTAL_DATA $DCRAB_IREPORT_DISK_TOTAL_DATA"'|' $DCRAB_IREPORT_DATA_FILE		
	fi
}
