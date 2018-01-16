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
	
	# Files
	DCRAB_IREPORT_DISK_FILE="/dipc/administracion/admin/dcrab/datos/ldisk/$DCRAB_DATE"
        DCRAB_IREPORT_IB_FILE="/dipc/administracion/admin/dcrab/datos/ib/$DCRAB_DATE"

	# IB
        DCRAB_IREPORT_IB_TOTAL_DATA=0
	
	# DISK
	DCRAB_IREPORT_DISK_TOTAL_DATA=0
}



#
# Writes the data for the internal report
#
dcrab_write_internal_data () {

	# Collect IB data 
        for file in $DCRAB_TOTAL_IB_DIR/*
        do
 	        local value=$(cat $file)
		echo "$file - IB : $value"
                DCRAB_IREPORT_IB_TOTAL_DATA=$(( DCRAB_IREPORT_IB_TOTAL_DATA + value ))
        done		

	# Collect DISK data 
        for file in $DCRAB_TOTAL_DISK_DIR/*
        do
 	        local value=$(cat $file)
                DCRAB_IREPORT_DISK_TOTAL_DATA=$(( DCRAB_IREPORT_DISK_TOTAL_DATA + value ))
        done		

	# Here will insert in the database these values 
	# Example: ssh acNode "INSERT $DCRAB_IREPORT_IB_TOTAL_DATA $DCRAB_IREPORT_DISK_TOTAL_DATA INTO DB"
	# Or maybe store them for a posterior use in "DCRAB_IREPORT_*_FILE" files
}

