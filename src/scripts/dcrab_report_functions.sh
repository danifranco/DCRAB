#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains the necessary functions to manipulate the reporting html file
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================


#
# This function makes the necessary wait time to allow a node to write in the report. Each node waits the previous one
# and the master node (DCRAB_NODE_NUMBER=0) waits for the last node. It ensures the write will be secuential and atomic,
# resolving any problem related to the updating delay present in parallel filesystems like Beegfs, Lustre etc. 
#
dcrab_wait_and_write () {
	
	j=0
	while [ 1 ]; do
		# Take the first line of the report 
		local n=$(head -1 $DCRAB_HTML | cut -d'-' -f3)

		# Break the loop when is the turn of the node
		if [ "$n" -eq "$DCRAB_PREVIOUS_NODE" ]; then
			break
		else		
			j=$((j+1))
			echo "Node $DCRAB_NODE_NUMBER : not my turn to write (turn of 'Node $n'). Making a sort sleep... ($j times asleep)"
			
			# Check exit
			dcrab_check_exit 0
			
			sleep 1
		fi
	done
	
	echo "My turn has reached! Write second: $(date +"%s")"

	# Execute all the commands
	$DCRAB_COMMAND_FILE
}


#
# Writes collected data in the html reporting file. This function is made in each loop after collect all the data.
#
dcrab_write_data () {

	# Empty command file
	:> $DCRAB_COMMAND_FILE

	case "$DCRAB_NODE_NUMBER" in

	### MAIN NODE ###
	0)	
		# GLOBAL TIME
		printf "%s \n" "sed -i \"$DCRAB_TIME_TEXT_L1\"'s|\([0-9]*:[0-9]*:[0-9]*:[0-9]*\)|'\"$DCRAB_ELAPSED_TIME_TEXT\"'|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		printf "%s \n" "sed -i \"$DCRAB_TIME_L1\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_ELAPSED_TIME_VALUE\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		printf "%s \n" "sed -i \"$DCRAB_TIME_L2\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_REMAINING_TIME_VALUE\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
	
		# More than one node
		if [ "$DCRAB_NNODES" -gt 1 ]; then
			# MEM TOTAL
			printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_L2\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_MEM_TOTAL_UNUSED\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		        printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_L1\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_MEM_TOTAL_USED\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		        printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_TEXT_L2\"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'\"$DCRAB_MEM_TOTAL_MAX_VMRSS\"' GB</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		        printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_TEXT_L3\"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'\"$DCRAB_MEM_TOTAL_VMSIZE\"' GB</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

			if [ "$DCRAB_MEM_TOTAL_EXCEEDED" -eq 1 ] && [ "$DCRAB_MEM_TOTAL_CHANGED" -eq 0 ]; then
                		printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_COLOR_BASELINE\"'s/#3366CC/#ff0000/' $DCRAB_HTML; "
		                DCRAB_MEM_TOTAL_EXCEEDED=0
		                DCRAB_MEM_TOTAL_CHANGED=1
		        fi
		fi 

		# When new processes are created
		if [ "$DCRAB_CPU_UPDATES" -gt 0 ]; then
			# Construct the string to insert
	            	DCRAB_CPU_UPDATE_STRING1=""
            		DCRAB_CPU_UPDATE_STRING2=""

            		for i in $( seq 0 $((DCRAB_CPU_UPDATES -1)) ); do
   	        		DCRAB_CPU_UPDATE_STRING1=$DCRAB_CPU_UPDATE_STRING1", '${DCRAB_CPU_UPD_PROC_NAME[$i]}'"
	   	             	DCRAB_CPU_UPDATE_STRING2=$DCRAB_CPU_UPDATE_STRING2", "
	            	done	
			
			# CPU				
			printf "%s \n" "sed -i \"$DCRAB_CPU_L1\"\"s|\['Execution Time (s)'|\['Execution Time (s)'$DCRAB_CPU_UPDATE_STRING1|\" $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
			printf "%s \n" "sed -i \"$DCRAB_CPU_L2\"'s|\[\([0-9]*\),|\[\1, '\"$DCRAB_CPU_UPDATE_STRING2\"'|g' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		fi	
	
		# The first write
        	if [ "$DCRAB_FIRST_WRITE" -eq 0 ]; then
			# TOTAL PIE CHART TEXT
			[ "$DCRAB_NNODES" -gt 1 ] && printf "%s \n" "sed -i \"$DCRAB_MEM_TOTAL_TEXT_L1\"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'\"$DCRAB_REQ_MEM\"' GB</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		
			# GLOBAL TIME
			printf "%s \n" "sed -i \"$DCRAB_TIME_TEXT_L2\"'s|00:00:00:00|'\"$DCRAB_REQ_TIME\"'|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
		fi
	;;
	*)
		# When new processes are created
        	if [ "$DCRAB_CPU_UPDATES" -gt 0 ]; then
            		# Construct the string to insert
           		DCRAB_CPU_UPDATE_STRING1=""
            		DCRAB_CPU_UPDATE_STRING2=""

            		for i in $( seq 0 $((DCRAB_CPU_UPDATES -1)) ); do
                		DCRAB_CPU_UPDATE_STRING1=$DCRAB_CPU_UPDATE_STRING1", '${DCRAB_CPU_UPD_PROC_NAME[$i]}'"
                		DCRAB_CPU_UPDATE_STRING2=$DCRAB_CPU_UPDATE_STRING2", "
           	 	done

            		printf "%s \n" "sed -i \"$DCRAB_CPU_L1\"\"s|\['Execution Time (s)'|\['Execution Time (s)'$DCRAB_CPU_UPDATE_STRING1|\" $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
            		printf "%s \n" "sed -i \"$DCRAB_CPU_L2\"'s|\[\([0-9]*\),|\[\1, '\"$DCRAB_CPU_UPDATE_STRING2\"'|g' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
        	fi
	;;
	esac

	# The first write
	if [ "$DCRAB_FIRST_WRITE" -eq 0 ]; then
	    	# MEM
	        printf "%s \n" "sed -i \"$DCRAB_MEM3_L1\"'s|\([0-9]\) GB|'\"$DCRAB_NODE_TOTAL_MEM\"' GB|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
	        printf "%s \n" "sed -i \"$DCRAB_MEM3_L2\"'s|\([0-9]\) GB|'\"$DCRAB_REQ_MEM\"' GB|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

        	DCRAB_FIRST_WRITE=$((DCRAB_FIRST_WRITE + 1))
	fi

	# CPU
	printf "%s \n" "sed -i \"$DCRAB_CPU_L2\"'s/.*/&'\"$DCRAB_CPU_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

  	# MEM 
	printf "%s \n" "sed -i \"$DCRAB_MEM1_L1\"'s/.*/&'\"$DCRAB_MEM_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_MEM2_L2\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_MEM2_UNUSED\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_MEM2_L1\"'s|\([0-9]*[.]*[0-9]*\)\]|'\"$DCRAB_MEM2_USED\"'\]|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_MEM3_L3\"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'\"$DCRAB_MEM_MAX_VMRSS\"' GB</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_MEM3_L4\"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'\"$DCRAB_MEM_MAX_VMSIZE\"' GB</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

    	# IB 
    	printf "%s \n" "sed -i \"$DCRAB_IB_L1\"'s/.*/&'\"$DCRAB_IB_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

    	# PROCESSES_IO
    	printf "%s \n" "sed -i \"$DCRAB_PROCESSESIO_L1\"'s/.*/&'\"$DCRAB_PROCESSESIO_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_PROCESSESIO_TEXT_L1\"'s|\([0-9]*[.]*[0-9]*\) '\"$DCRAB_PROCESSESIO_TOTAL_LAST_READ_STRING\"'</td></tr>|'\"$DCRAB_PROCESSESIO_TOTAL_READ_REDUCED $DCRAB_PROCESSESIO_TOTAL_READ_STRING\"'</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_PROCESSESIO_TEXT_L2\"'s|\([0-9]*[.]*[0-9]*\) '\"$DCRAB_PROCESSESIO_TOTAL_LAST_WRITE_STRING\"'</td></tr>|'\"$DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED $DCRAB_PROCESSESIO_TOTAL_WRITE_STRING\"'</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

    	# NFS
    	printf "%s \n" "sed -i \"$DCRAB_NFS_L1\"'s/.*/&'\"$DCRAB_NFS_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_NFS_TEXT_L1\"'s|\([0-9]*[.]*[0-9]*\) '\"$DCRAB_NFS_TOTAL_LAST_READ_STRING\"'</td></tr>|'\"$DCRAB_NFS_TOTAL_READ_REDUCED $DCRAB_NFS_TOTAL_READ_STRING\"'</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE
    	printf "%s \n" "sed -i \"$DCRAB_NFS_TEXT_L2\"'s|\([0-9]*[.]*[0-9]*\) '\"$DCRAB_NFS_TOTAL_LAST_WRITE_STRING\"'</td></tr>|'\"$DCRAB_NFS_TOTAL_WRITE_REDUCED $DCRAB_NFS_TOTAL_WRITE_STRING\"'</td></tr>|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

    	# DISK
    	printf "%s \n" "sed -i \"$DCRAB_DISK_L1\"'s/.*/'\"$DCRAB_DISK_DATA\"'/' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

	# Mark the report to inform the next node that is waiting that all changes has been made
	printf "%s \n" "sed -i 1's|<!--$DCRAB_PREVIOUS_NODE-->|<!--$DCRAB_NODE_NUMBER-->|' $DCRAB_HTML" >> $DCRAB_COMMAND_FILE

	# Execute commands
	dcrab_wait_and_write
}


#
# Creates the html file
#
dcrab_generate_html () {

	plot_width=800
	plot_height=600
	addedBorder=7

	# This first line is very important to serialize the writes of the nodes 
	printf "%s \n" "<!--$((DCRAB_NNODES - 1))-->" >> $DCRAB_HTML
	printf "%s \n" "<html>" >> $DCRAB_HTML
	printf "%s \n" "<head><title>DCRAB Report</title>" >> $DCRAB_HTML
	printf "%s \n" "<script type=\"text/javascript\" src=\"https://www.gstatic.com/charts/loader.js\"></script> " >> $DCRAB_HTML
	printf "%s \n" "<script type=\"text/javascript\"> " >> $DCRAB_HTML

	# Load packages and callbacks for plot functions
	printf "%s \n" "google.charts.load('current', {'packages':['corechart', 'bar']}); " >> $DCRAB_HTML
	printf "%s \n" "google.charts.setOnLoadCallback(plot_all); " >> $DCRAB_HTML

	################# Plot function #################
	printf "%s \n" "function plot_all() { " >> $DCRAB_HTML

	# Data of each nodes
	for node in $DCRAB_NODES_MOD
	do
		# CPU
		printf "%s \n" "var cpu_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Execution Time (s)'],">> $DCRAB_HTML	
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML

		# MEM
		printf "%s \n" "var mem1_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Execution Time (s)', 'Node Memory', 'Requested Mem.', 'Consumed Mem. Peak (of VmRSS)', 'Consumed Mem. (VmSize)', 'Resident Mem. (VmRSS)']," >> $DCRAB_HTML
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML
		printf "%s \n" "var mem2_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Mem class', 'Percentage']," >> $DCRAB_HTML
		printf "%s \n" "['Used memory', 0]," >> $DCRAB_HTML
		printf "%s \n" "['Not utilized memory', 100]," >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML

		# IB
		printf "%s \n" "var ib_data_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Execution Time (s)', 'Transmitted Packets', 'Received Packets', 'Transmitted Bytes (KB)', 'Received Bytes (KB)']," >> $DCRAB_HTML
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML

		# PROCESSES-IO
		printf "%s \n" "var processesIO_data_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Execution Time (s)', 'Read', 'Write']," >> $DCRAB_HTML
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML

		# NFS   
		printf "%s \n" "var nfs_data_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Execution Time (s)', 'Read', 'Write']," >> $DCRAB_HTML
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML

		# DISK
		printf "%s \n" "var disk_data_$node = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Devices', 'Read', 'Write']," >> $DCRAB_HTML
		printf "\n"  >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML
	done

	# TIME
	printf "%s \n" "var time_data = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
	printf "%s \n" "['Consumed Time', 'Percentage']," >> $DCRAB_HTML
	printf "%s \n" "['Elapsed Time', 0]," >> $DCRAB_HTML
	printf "%s \n" "['Remaining Time', 100]," >> $DCRAB_HTML
	printf "%s \n" "]);" >> $DCRAB_HTML

	if [ "$DCRAB_NNODES" -gt 1 ]; then
		printf "%s \n" "var total_mem = google.visualization.arrayToDataTable([" >> $DCRAB_HTML
		printf "%s \n" "['Mem class', 'Percentage']," >> $DCRAB_HTML
		printf "%s \n" "['Used memory', 0]," >> $DCRAB_HTML
		printf "%s \n" "['Not utilized memory', 100]," >> $DCRAB_HTML
		printf "%s \n" "]);" >> $DCRAB_HTML
	fi

	# TIME 
	printf "%s \n" "var time_options = {" >> $DCRAB_HTML
	printf "%s \n" "width: 310," >> $DCRAB_HTML
	printf "%s \n" "height: 200," >> $DCRAB_HTML
	printf "%s \n" "chartArea: {  width: \"90%\", height: \"90%\" }," >> $DCRAB_HTML
	printf "%s \n" "colors: ['#3366CC', '#109618']," >> $DCRAB_HTML
	printf "%s \n" "is3D: true" >> $DCRAB_HTML
	printf "%s \n" "};" >> $DCRAB_HTML

	# CPU
	printf "%s \n" "var cpu_options = {" >> $DCRAB_HTML
	printf "%s \n" "title: 'CPU Utilization'," >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "width: '$plot_width'," >> $DCRAB_HTML
	printf "%s \n" "height: '$plot_height'," >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Execution Time (s)'}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'CPU used (%)'}," >> $DCRAB_HTML
	printf "%s \n" "chartArea: {  width: \"70%\", height: \"80%\" }," >> $DCRAB_HTML
	printf "%s \n" "};" >> $DCRAB_HTML

	# MEM
	printf "%s \n" "var mem1_options = {  " >> $DCRAB_HTML
	printf "%s \n" "title : 'Memory Utilization', " >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'GB'}, " >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Time (s)'}, " >> $DCRAB_HTML
	printf "%s \n" "width: $plot_width,  " >> $DCRAB_HTML
	printf "%s \n" "height: $plot_height,  " >> $DCRAB_HTML
	printf "%s \n" "axes: {  " >> $DCRAB_HTML
	printf "%s \n" "x: {  " >> $DCRAB_HTML
	printf "%s \n" "0: {side: 'top'}  " >> $DCRAB_HTML
	printf "%s \n" "}  " >> $DCRAB_HTML
	printf "%s \n" "},  " >> $DCRAB_HTML
        printf "%s \n" "legend: {textStyle: {fontSize: 13}}," >> $DCRAB_HTML
	printf "%s \n" "};  " >> $DCRAB_HTML
	printf "%s \n" "var mem2_options = {" >> $DCRAB_HTML
	printf "%s \n" "title: 'Requested memory usage'," >> $DCRAB_HTML
	printf "%s \n" "width: $((plot_width / 2))," >> $DCRAB_HTML
	printf "%s \n" "height: $((plot_height / 2))," >> $DCRAB_HTML
	printf "%s \n" "colors: ['#3366CC', '#109618']," >> $DCRAB_HTML
	printf "%s \n" "is3D: true" >> $DCRAB_HTML
	printf "%s \n" "};" >> $DCRAB_HTML

	# IB
	printf "%s \n" "var ib_options = {" >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "title: 'Infiniband Stats'," >> $DCRAB_HTML
	printf "%s \n" "width: '$plot_width'," >> $DCRAB_HTML
	printf "%s \n" "height: '$plot_height'," >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Execution Time (s)'}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'Values'}," >> $DCRAB_HTML
	printf "%s \n" "chartArea: {  width: \"70%\", height: \"80%\" }," >> $DCRAB_HTML
	printf "%s \n" "};" >> $DCRAB_HTML

	# PROCESSES-IO
	printf "%s \n" "var processesIO_options = {  " >> $DCRAB_HTML
	printf "%s \n" "title : 'Processes I/O Stats', " >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'MB/s'}, " >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Time (s)'}, " >> $DCRAB_HTML
	printf "%s \n" "width: $plot_width,  " >> $DCRAB_HTML
	printf "%s \n" "height: $plot_height,  " >> $DCRAB_HTML
	printf "%s \n" "axes: {  " >> $DCRAB_HTML
	printf "%s \n" "x: {  " >> $DCRAB_HTML
	printf "%s \n" "0: {side: 'top'}  " >> $DCRAB_HTML
	printf "%s \n" "}  " >> $DCRAB_HTML
	printf "%s \n" "},  " >> $DCRAB_HTML
	printf "%s \n" "};  " >> $DCRAB_HTML

	# NFS
	printf "%s \n" "var nfs_options = {  " >> $DCRAB_HTML
	printf "%s \n" "title : 'NFS I/O Stats (scicomp)', " >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'MB/s'}, " >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Time (s)'}, " >> $DCRAB_HTML
	printf "%s \n" "width: $plot_width,  " >> $DCRAB_HTML
	printf "%s \n" "height: $plot_height,  " >> $DCRAB_HTML
	printf "%s \n" "axes: {  " >> $DCRAB_HTML
	printf "%s \n" "x: {  " >> $DCRAB_HTML
	printf "%s \n" "0: {side: 'top'}  " >> $DCRAB_HTML
	printf "%s \n" "}  " >> $DCRAB_HTML
	printf "%s \n" "},  " >> $DCRAB_HTML
	printf "%s \n" "};  " >> $DCRAB_HTML

	# DISK
	printf "%s \n" "var disk_options = {  " >> $DCRAB_HTML
	printf "%s \n" "title : 'Local disks I/O Stats (lscratch)', " >> $DCRAB_HTML
        printf "%s \n" "titleTextStyle: {" >> $DCRAB_HTML
        printf "%s \n" "fontName: 'Roboto'," >> $DCRAB_HTML
        printf "%s \n" "fontSize: 16," >> $DCRAB_HTML
        printf "%s \n" "bold: false," >> $DCRAB_HTML
        printf "%s \n" "color: '#757575'," >> $DCRAB_HTML
        printf "%s \n" "}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'MB'}, " >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Devices'}, " >> $DCRAB_HTML
	printf "%s \n" "chartArea: {  width: \"70%\", height: \"80%\" }," >> $DCRAB_HTML
	printf "%s \n" "width: $plot_width,  " >> $DCRAB_HTML
	printf "%s \n" "height: $plot_height,  " >> $DCRAB_HTML
	printf "%s \n" "axes: {  " >> $DCRAB_HTML
	printf "%s \n" "x: {  " >> $DCRAB_HTML
	printf "%s \n" "0: {side: 'bottom'}  " >> $DCRAB_HTML
	printf "%s \n" "}  " >> $DCRAB_HTML
	printf "%s \n" "},  " >> $DCRAB_HTML
	printf "%s \n" "};  " >> $DCRAB_HTML


	if [ "$DCRAB_NNODES" -gt 1 ]; then
		printf "%s \n" "var total_mem_options = {" >> $DCRAB_HTML
		printf "%s \n" " title: 'Requested memory usage'," >> $DCRAB_HTML
		printf "%s \n" " width: 650," >> $DCRAB_HTML
		printf "%s \n" " height: 450," >> $DCRAB_HTML
		printf "%s \n" " colors: ['#3366CC', '#109618']," >> $DCRAB_HTML
		printf "%s \n" " is3D: true" >> $DCRAB_HTML
		printf "%s \n" "};" >> $DCRAB_HTML
	fi
	
	i=1
	for node in $DCRAB_NODES_MOD
	do
		# TIME
		printf "%s \n" "var time_chart = new google.visualization.PieChart(document.getElementById('plot_time'));"  >> $DCRAB_HTML
		printf "%s \n" "time_chart.draw(time_data, time_options);  " >> $DCRAB_HTML

		# CPU
		printf "%s \n" "var cpu_chart_$node = new google.visualization.LineChart(document.getElementById('plot_cpu_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "cpu_chart_$node.draw(cpu_$node, cpu_options);  " >> $DCRAB_HTML

		# MEM
		printf "%s \n" "var mem1_chart_$node = new google.visualization.AreaChart(document.getElementById('plot1_mem_$node'));"  >> $DCRAB_HTML
		if [ "$DCRAB_NNODES" -eq 1 ] && [ $i -eq 1 ]; then
                        printf "%s \n" "google.visualization.events.addListener(mem1_chart_$node, 'ready', function () {" >> $DCRAB_HTML
                        printf "%s \n" "document.getElementById(\"memChart\").style.display = \"none\";" >> $DCRAB_HTML
                        printf "%s \n" "});" >> $DCRAB_HTML
                fi
		printf "%s \n" "var mem2_chart_$node = new google.visualization.PieChart(document.getElementById('plot2_mem_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "mem1_chart_$node.draw(mem1_$node, mem1_options);  " >> $DCRAB_HTML
		printf "%s \n" "mem2_chart_$node.draw(mem2_$node, mem2_options);  " >> $DCRAB_HTML

		# IB
		printf "%s \n" "var ib_chart_$node = new google.visualization.LineChart(document.getElementById('plot_ib_$node'));"  >> $DCRAB_HTML
		if [ $i -eq 1 ]; then
			printf "%s \n" "google.visualization.events.addListener(ib_chart_$node, 'ready', function () {" >> $DCRAB_HTML
	                printf "%s \n" "document.getElementById(\"ibChart\").style.display = \"none\";" >> $DCRAB_HTML
	                printf "%s \n" "});" >> $DCRAB_HTML
		fi
		printf "%s \n" "ib_chart_$node.draw(ib_data_$node, ib_options);  " >> $DCRAB_HTML

		# PROCESSESIO
		printf "%s \n" "var processesIO_chart_$node = new google.visualization.AreaChart(document.getElementById('plot_processesIO_$node'));"  >> $DCRAB_HTML
		if [ $i -eq 1 ]; then
			printf "%s \n" "google.visualization.events.addListener(processesIO_chart_$node, 'ready', function () {" >> $DCRAB_HTML
	                printf "%s \n" "document.getElementById(\"processesIOChart\").style.display = \"none\";" >> $DCRAB_HTML
	                printf "%s \n" "});" >> $DCRAB_HTML	
		fi
		printf "%s \n" "processesIO_chart_$node.draw(processesIO_data_$node, processesIO_options);  " >> $DCRAB_HTML

		# NFS
		printf "%s \n" "var nfs_chart_$node = new google.visualization.AreaChart(document.getElementById('plot_nfs_$node'));"  >> $DCRAB_HTML
		if [ $i -eq 1 ]; then
			printf "%s \n" "google.visualization.events.addListener(nfs_chart_$node, 'ready', function () {" >> $DCRAB_HTML
	                printf "%s \n" "document.getElementById(\"nfsChart\").style.display = \"none\";" >> $DCRAB_HTML
	                printf "%s \n" "});" >> $DCRAB_HTML
		fi
		printf "%s \n" "nfs_chart_$node.draw(nfs_data_$node, nfs_options);  " >> $DCRAB_HTML

		# DISK
		printf "%s \n" "var disk_chart_$node = new google.visualization.ColumnChart(document.getElementById('plot_disk_$node'));"  >> $DCRAB_HTML
		if [ $i -eq 1 ]; then
			printf "%s \n" "google.visualization.events.addListener(disk_chart_$node, 'ready', function () {" >> $DCRAB_HTML
	                printf "%s \n" "document.getElementById(\"diskChart\").style.display = \"none\";" >> $DCRAB_HTML
	                printf "%s \n" "});" >> $DCRAB_HTML
		fi
		printf "%s \n" "disk_chart_$node.draw(disk_data_$node, disk_options);  " >> $DCRAB_HTML
	done

	if [ "$DCRAB_NNODES" -gt 1 ]; then
		printf "%s \n" "var total_mem_chart = new google.visualization.PieChart(document.getElementById('plot_total_mem'));" >> $DCRAB_HTML
		printf "%s \n" "google.visualization.events.addListener(total_mem_chart, 'ready', function () {" >> $DCRAB_HTML
                printf "%s \n" "document.getElementById(\"memChart\").style.display = \"none\";" >> $DCRAB_HTML
                printf "%s \n" "});" >> $DCRAB_HTML
		printf "%s \n" "total_mem_chart.draw(total_mem, total_mem_options);" >> $DCRAB_HTML
	fi
	printf "%s \n" "}" >> $DCRAB_HTML

	
        printf "%s \n" "function tabChanges(evt, chartType, idTab) {" >> $DCRAB_HTML
        printf "%s \n" "    var i, tabcontent, tablinks, buttons;" >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" "    tablinks = document.getElementsByClassName(\"tablinks\");" >> $DCRAB_HTML
        printf "%s \n" "    for (i = 0; i < tablinks.length; i++) {" >> $DCRAB_HTML
        printf "%s \n" "        tablinks[i].className = tablinks[i].className.replace(\" selected\", \"\");" >> $DCRAB_HTML
        printf "%s \n" "    }" >> $DCRAB_HTML
        printf "%s \n" "    document.getElementById(idTab).className += \" selected\";" >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" "    tabcontent = document.getElementsByClassName(\"chart\");" >> $DCRAB_HTML
        printf "%s \n" "    for (i = 0; i < tabcontent.length; i++) {" >> $DCRAB_HTML
        printf "%s \n" "        tabcontent[i].style.display = \"none\";" >> $DCRAB_HTML
        printf "%s \n" "    }" >> $DCRAB_HTML
        printf "%s \n" "    document.getElementById(chartType).style.display = \"block\";" >> $DCRAB_HTML
        printf "%s \n" "buttons = document.querySelectorAll(\"input[type=button]\"); " >> $DCRAB_HTML
        printf "%s \n" "    for (i = 0; i < buttons.length; i++) { " >> $DCRAB_HTML
        printf "%s \n" "        buttons[i].style.color = \"#505050\"; " >> $DCRAB_HTML
        printf "%s \n" "    }" >> $DCRAB_HTML
        printf "%s \n" "   document.getElementById(idTab.slice(0,-3) + \"Button\").style.color = \"black\";" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML

	################# END plot function #################
	printf "%s \n" "</script>" >> $DCRAB_HTML

	################# Style #################
	printf "%s \n" "<style>" >> $DCRAB_HTML
        printf "%s \n" "body { " >> $DCRAB_HTML
        printf "%s \n" "background: #25c481; /* Old browsers */ " >> $DCRAB_HTML
        printf "%s \n" "background: url(data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiA/Pgo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgdmlld0JveD0iMCAwIDEgMSIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+CiAgPGxpbmVhckdyYWRpZW50IGlkPSJncmFkLXVjZ2ctZ2VuZXJhdGVkIiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMCUiPgogICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzI1YzQ4MSIgc3RvcC1vcGFjaXR5PSIxIi8+CiAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMyNWI3YzQiIHN0b3Atb3BhY2l0eT0iMSIvPgogIDwvbGluZWFyR3JhZGllbnQ+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjEiIGhlaWdodD0iMSIgZmlsbD0idXJsKCNncmFkLXVjZ2ctZ2VuZXJhdGVkKSIgLz4KPC9zdmc+); " >> $DCRAB_HTML
        printf "%s \n" "background: -moz-linear-gradient(left,  #25c481 0%, #25b7c4 100%); /* FF3.6-15 */ " >> $DCRAB_HTML
        printf "%s \n" "background: -webkit-linear-gradient(left,  #25c481 0%,#25b7c4 100%); /* Chrome10-25,Safari5.1-6 */ " >> $DCRAB_HTML
        printf "%s \n" "background: linear-gradient(to right,  #25c481 0%,#25b7c4 100%); /* W3C, IE10+, FF16+, Chrome26+, Opera12+, Safari7+ */ " >> $DCRAB_HTML
        printf "%s \n" "filter: progid:DXImageTransform.Microsoft.gradient( startColorstr='#25c481', endColorstr='#25b7c4',GradientType=1 ); /* IE6-8 */ " >> $DCRAB_HTML
        printf "%s \n" "margin:0px;" >> $DCRAB_HTML
        printf "%s \n" "font-family: Verdana, Geneva, sans-serif;" >> $DCRAB_HTML
	printf "%s \n" "font-size: 18px;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" ".inline {" >> $DCRAB_HTML
        printf "%s \n" "display:inline-block;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "#foot { " >> $DCRAB_HTML
        printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
        printf "%s \n" "margin-top: 180px;" >> $DCRAB_HTML
        printf "%s \n" "display: table;" >> $DCRAB_HTML
        printf "%s \n" "width:100%;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".vl {" >> $DCRAB_HTML
        printf "%s \n" "display: inline;" >> $DCRAB_HTML
        printf "%s \n" "border-left: 2px solid black;" >> $DCRAB_HTML
        printf "%s \n" "height: 10px;" >> $DCRAB_HTML
        printf "%s \n" "padding-right:5em;" >> $DCRAB_HTML
        printf "%s \n" "margin-left:5em;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "table { " >> $DCRAB_HTML
        printf "%s \n" "border-collapse: collapse;" >> $DCRAB_HTML
        printf "%s \n" "margin: 15px;" >> $DCRAB_HTML
        printf "%s \n" "margin-top: 2px;" >> $DCRAB_HTML
        printf "%s \n" "margin-bottom: 2px;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" "tr { " >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" ".overflowDivs { " >> $DCRAB_HTML
        printf "%s \n" "overflow:auto;" >> $DCRAB_HTML
        printf "%s \n" "white-space: nowrap;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" ".header { " >> $DCRAB_HTML
        printf "%s \n" "width: 800px;" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
        printf "%s \n" "float: left;" >> $DCRAB_HTML
        printf "%s \n" "text-align: center;" >> $DCRAB_HTML
        printf "%s \n" "font-family: Verdana, Geneva, sans-serif;" >> $DCRAB_HTML
        printf "%s \n" "font-size: 16px;" >> $DCRAB_HTML
        printf "%s \n" "color: black;" >> $DCRAB_HTML
        printf "%s \n" "text-transform: uppercase;" >> $DCRAB_HTML
        printf "%s \n" "vertical-align: middle;" >> $DCRAB_HTML
        printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" ".plot{ " >> $DCRAB_HTML
        printf "%s \n" "vertical-align:middle;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "#textmem2 { " >> $DCRAB_HTML
        printf "%s \n" "border-spacing: 5px;" >> $DCRAB_HTML
        printf "%s \n" "border-collapse: separate;" >> $DCRAB_HTML
        printf "%s \n" "margin: 0 auto;" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" "#detailedText { " >> $DCRAB_HTML
        printf "%s \n" "vertical-align: top;" >> $DCRAB_HTML
        printf "%s \n" "padding-top: 230px;" >> $DCRAB_HTML
        printf "%s \n" "font-family: 'Roboto', sans-serif;" >> $DCRAB_HTML
        printf "%s \n" "font-size: 56px;" >> $DCRAB_HTML
        printf "%s \n" "color: #fff;" >> $DCRAB_HTML
        printf "%s \n" "text-transform: uppercase;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" ".rcorners { " >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
        printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
        printf "%s \n" "border-radius: 25px;" >> $DCRAB_HTML
        printf "%s \n" "margin : 40px;" >> $DCRAB_HTML
        printf "%s \n" "padding-left: 15px;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" ".textbox { " >> $DCRAB_HTML
        printf "%s \n" "width:49%;" >> $DCRAB_HTML
        printf "%s \n" "height: 300px;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" ".warningText { " >> $DCRAB_HTML
        printf "%s \n" "height: 200px;" >> $DCRAB_HTML
        printf "%s \n" "vertical-align: top;" >> $DCRAB_HTML
        printf "%s \n" "margin-top: 230px;" >> $DCRAB_HTML
        printf "%s \n" "color: #ff8000;" >> $DCRAB_HTML
        printf "%s \n" "} " >> $DCRAB_HTML
        printf "%s \n" ".chart {" >> $DCRAB_HTML
	printf "%s \n" "text-align: center;" >> $DCRAB_HTML
	printf "%s \n" "display: none;" >> $DCRAB_HTML
	printf "%s \n" "padding-top: 45px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow {" >> $DCRAB_HTML
        printf "%s \n" "height: 42px;" >> $DCRAB_HTML
        printf "%s \n" "text-align: left;" >> $DCRAB_HTML
        printf "%s \n" "list-style: none;" >> $DCRAB_HTML
        printf "%s \n" "padding-left: 13px;" >> $DCRAB_HTML
        printf "%s \n" "line-height: 24px;" >> $DCRAB_HTML
        printf "%s \n" "height: 26px;" >> $DCRAB_HTML
        printf "%s \n" "overflow: hidden;" >> $DCRAB_HTML
        printf "%s \n" "position: relative;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow:before {" >> $DCRAB_HTML
        printf "%s \n" "position: absolute;" >> $DCRAB_HTML
        printf "%s \n" "content: \" \";" >> $DCRAB_HTML
        printf "%s \n" "width: 100%;" >> $DCRAB_HTML
        printf "%s \n" "bottom: 0;" >> $DCRAB_HTML
        printf "%s \n" "left: 0;" >> $DCRAB_HTML
        printf "%s \n" "border-bottom: 1px solid #BCFFF6;" >> $DCRAB_HTML
        printf "%s \n" "z-index: 1;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li {" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid #FFF;" >> $DCRAB_HTML
        printf "%s \n" "background-color: #D1D1D1;" >> $DCRAB_HTML
        printf "%s \n" "background: -o-linear-gradient(top, #dbdbdb 50%, #aeaeae 100%);" >> $DCRAB_HTML
        printf "%s \n" "background: -ms-linear-gradient(top, #dbdbdb 50%, #aeaeae 100%);" >> $DCRAB_HTML
        printf "%s \n" "background: -moz-linear-gradient(top, #dbdbdb 50%, #aeaeae 100%);" >> $DCRAB_HTML
        printf "%s \n" "background: -webkit-linear-gradient(top, #dbdbdb 50%, #aeaeae 100%);" >> $DCRAB_HTML
        printf "%s \n" "background: linear-gradient(top, #dbdbdb 50%, #aeaeae 100%);" >> $DCRAB_HTML
        printf "%s \n" "background: linear-gradient(#dbdbdb , #aeaeae);" >> $DCRAB_HTML
        printf "%s \n" "display: inline-block;" >> $DCRAB_HTML
        printf "%s \n" "position: relative;" >> $DCRAB_HTML
        printf "%s \n" "z-index: 0;" >> $DCRAB_HTML
        printf "%s \n" "border-top-left-radius: 12px;" >> $DCRAB_HTML
        printf "%s \n" "border-top-right-radius: 12px;" >> $DCRAB_HTML
        printf "%s \n" "box-shadow: 0 6px 6px rgb(0, 0, 0);" >> $DCRAB_HTML
        printf "%s \n" "margin: 0 -5px;" >> $DCRAB_HTML
        printf "%s \n" "padding: 0 20px;" >> $DCRAB_HTML
        printf "%s \n" "height: inherit;" >> $DCRAB_HTML
        printf "%s \n" "min-width: 100px;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li.selected {" >> $DCRAB_HTML
        printf "%s \n" "background: #7CDABE;" >> $DCRAB_HTML
        printf "%s \n" "background-color: #7CDABE;" >> $DCRAB_HTML
        printf "%s \n" "z-index: 2;" >> $DCRAB_HTML
        printf "%s \n" "border-bottom-color: #BCFFF6;" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid #BCFFF6;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li:before," >> $DCRAB_HTML
        printf "%s \n" ".tabrow li:after {" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid #FFF;" >> $DCRAB_HTML
        printf "%s \n" "position: absolute;" >> $DCRAB_HTML
        printf "%s \n" "bottom: -1px;" >> $DCRAB_HTML
        printf "%s \n" "width: 15px;" >> $DCRAB_HTML
        printf "%s \n" "height: 12px;" >> $DCRAB_HTML
        printf "%s \n" "content: \" \";" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li:before {" >> $DCRAB_HTML
        printf "%s \n" "left: -16px;" >> $DCRAB_HTML
        printf "%s \n" "border-bottom-right-radius: 16px;" >> $DCRAB_HTML
        printf "%s \n" "border-width: 0 1px 1px 0;" >> $DCRAB_HTML
        printf "%s \n" "box-shadow: 6px 2px 0 #b4b4b4;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li:after {" >> $DCRAB_HTML
        printf "%s \n" "right: -16px;" >> $DCRAB_HTML
        printf "%s \n" "border-bottom-left-radius: 16px;" >> $DCRAB_HTML
        printf "%s \n" "border-width: 0 0 1px 1px;" >> $DCRAB_HTML
        printf "%s \n" "box-shadow: -6px 2px 0 #b4b4b4;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li.selected:before {" >> $DCRAB_HTML
        printf "%s \n" "border-width: 0 1px 1px 0;" >> $DCRAB_HTML
        printf "%s \n" "box-shadow: 6px 2px 0 #7CDABE;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "" >> $DCRAB_HTML
        printf "%s \n" ".tabrow li.selected:after {" >> $DCRAB_HTML
        printf "%s \n" "border-width: 0px 0px 1px 1px;" >> $DCRAB_HTML
        printf "%s \n" "box-shadow: -6px 2px 0 #7CDABE;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "#tabDiv {" >> $DCRAB_HTML
        printf "%s \n" "width:90%;" >> $DCRAB_HTML
        printf "%s \n" "margin-left:15px;" >> $DCRAB_HTML
        printf "%s \n" "margin: 100px 0px 0px 100px;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "#chartDiv {" >> $DCRAB_HTML
        printf "%s \n" "width:90%;" >> $DCRAB_HTML
        printf "%s \n" "margin-left:15px;" >> $DCRAB_HTML
        printf "%s \n" "height: 700px;" >> $DCRAB_HTML
        printf "%s \n" "border: 1px solid #BCFFF6;" >> $DCRAB_HTML
        printf "%s \n" "border-top: none;" >> $DCRAB_HTML
        printf "%s \n" "margin-left: 100px;" >> $DCRAB_HTML
        printf "%s \n" "margin-top: -18px;" >> $DCRAB_HTML
        printf "%s \n" "background: rgba(255,255,255,0.4);" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
        printf "%s \n" "input[type=\"button\"] {" >> $DCRAB_HTML
        printf "%s \n" "background-color: inherit;" >> $DCRAB_HTML
        printf "%s \n" "cursor: pointer;" >> $DCRAB_HTML
        printf "%s \n" "border:none;" >> $DCRAB_HTML
        printf "%s \n" "min-width: inherit;" >> $DCRAB_HTML
        printf "%s \n" "height: inherit;" >> $DCRAB_HTML
        printf "%s \n" "font-family:Verdana, Geneva, sans-serif;" >> $DCRAB_HTML
        printf "%s \n" "color: #505050;" >> $DCRAB_HTML
        printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "</style>" >> $DCRAB_HTML
	printf "%s \n" "</head>" >> $DCRAB_HTML
	################# END Style #################

	################# BODY #################
	printf "%s \n" "<body>" >> $DCRAB_HTML
	printf "%s \n" "<svg style=\"display: block;margin: 50px auto 100px;\" version=\"1.1\" id=\"Layer_1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" x=\"0px\" y=\"0px\" width=\"606px\" height=\"159px\" viewBox=\"0 0 606 159\" enable-background=\"new 0 0 606 159\" xml:space=\"preserve\">  <image id=\"image0\" width=\"606\" height=\"159\" x=\"0\" y=\"0\" xlink:href=\"data:image/png;base64,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 YII=\"/> </svg>" >> $DCRAB_HTML

	printf "%s \n" "<center><h1>DCRAB REPORT - JOB $DCRAB_JOB_ID </h1></center>" >> $DCRAB_HTML

	# Job summary
	printf "%s \n" "<div style=\"float: left;\" class=\"inline textbox\">" >> $DCRAB_HTML
	printf "%s \n" "<div style=\"margin-left: 70px; height: 75%;\" class=\"text rcorners\">" >> $DCRAB_HTML
	printf "%s \n" "<p style=\"padding :38px;\">" >> $DCRAB_HTML
	printf "%s \n" "<b><u>Name of the job</u></b>: $DCRAB_JOBNAME<br>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>JOBID</u></b>: $DCRAB_JOB_ID <br>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>User</u></b>: $USER <br>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>Working directory</u></b>: $DCRAB_WORKDIR <br>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>Node list</u></b>: $DCRAB_NODES" >> $DCRAB_HTML
	printf "%s \n" "</p>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"inline textbox\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"text rcorners\" style=\"height: 75%;\">" >> $DCRAB_HTML
	printf "%s \n" "<div id='plot_time' style=\"padding: 15px; float: left;\" ></div>" >> $DCRAB_HTML
	printf "%s \n" "<div style=\"float: left; padding-top: 55px; padding-left: 55px;\">" >> $DCRAB_HTML
	printf "%s \n" "<center>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>Elapsed Time (DD:HH:MM:SS)</u></b><br>" >> $DCRAB_HTML
	printf "%s \n" "00:00:00:00 <br><br>" >> $DCRAB_HTML
	printf "%s \n" "<b><u>Cput requested</u></b><br>" >> $DCRAB_HTML
	printf "%s \n" "00:00:00:00 <br>" >> $DCRAB_HTML
	printf "%s \n" "</center>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
        printf "%s \n" "<div id=\"tabDiv\">" >> $DCRAB_HTML
        printf "%s \n" "<ul class=\"tabrow\" style=\"height: 35px;\">" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"cpuTab\" class=\"tablinks selected\"><input id=\"cpuButton\" type=\"button\" value=\"CPU\" style=\"color: black\" onclick=\"tabChanges(event, 'cpuChart', 'cpuTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"memTab\" class=\"tablinks\"><input id=\"memButton\" type=\"button\" value=\"Memory\" onclick=\"tabChanges(event, 'memChart', 'memTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"processesIOTab\" class=\"tablinks\"><input id=\"processesIOButton\" type=\"button\" value=\"Processes I/O\" onclick=\"tabChanges(event, 'processesIOChart', 'processesIOTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"diskTab\" class=\"tablinks\"><input id=\"diskButton\" type=\"button\" value=\"Disk I/O\" onclick=\"tabChanges(event, 'diskChart', 'diskTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"ibTab\" class=\"tablinks\"><input id=\"ibButton\" type=\"button\" value=\"Infiniband\" onclick=\"tabChanges(event, 'ibChart', 'ibTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "<li id=\"nfsTab\" class=\"tablinks\"><input id=\"nfsButton\" type=\"button\" value=\"NFS\" onclick=\"tabChanges(event, 'nfsChart', 'nfsTab')\"></input></li>" >> $DCRAB_HTML
        printf "%s \n" "</ul>" >> $DCRAB_HTML
        printf "%s \n" "</div>" >> $DCRAB_HTML
        printf "%s \n" "<div id=\"chartDiv\">" >> $DCRAB_HTML

	# CPU plots 
        printf "%s \n" "<div id=\"cpuChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot\" id='plot_cpu_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# MEM plots 
	printf "%s \n" "<div id=\"memChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	if [ "$DCRAB_NNODES" -gt 1 ]; then
		printf "%s \n" "<div class=\"inline\" style=\"margin-right: 50px;\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"width: 1019px;\" class=\"header\">TOTAL MEMORY USED FOR THE SCHEDULER</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"padding-top: 75px;padding-bottom: 75px;padding-left: 15px;padding-right: 15px;\" class=\"plot inline\" id='plot_total_mem'></div>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"border: 0px;padding-right: 15px;\" class=\"plot inline\">" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"text\">" >> $DCRAB_HTML
		printf "%s \n" "<table id=\"textmem2\">" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Requested memory</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>VmRSS (peak)</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>VmSize (peak)</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "<br><br><br>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"inline\" id=\"detailedText\">" >> $DCRAB_HTML
		printf "%s \n" "<pre style=\"margin: 0px;\">MORE DETAILED " >> $DCRAB_HTML
		printf "%s \n" "    DATA </pre>" >> $DCRAB_HTML
		printf "%s \n" "<p style=\"margin: 0px; font-size: 115px;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#8594;</p>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
	fi
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"width: 1207px;\" class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot inline\" id='plot1_mem_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"border: 0px;\" class=\"plot inline\">" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"text\">" >> $DCRAB_HTML
		printf "%s \n" "<table id=\"textmem2\">" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Node memory</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Requested memory</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>VmRSS (peak)</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>VmSize (peak)</u></b>:&nbsp;&nbsp;&nbsp;&nbsp;</td><td>0 GB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "<br><br><br>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot inline\" id='plot2_mem_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# PROCESSESIO plots
	printf "%s \n" "<div id=\"processesIOChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"width: 1100px;\" class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot inline\" id='plot_processesIO_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"border: 0px; margin-left: 75px;\" class=\"plot inline\">" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"text\">" >> $DCRAB_HTML
		printf "%s \n" "<table id=\"textmem2\">" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Total Read</u></b>:</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td>0 MB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Total Write</u></b>:</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td>0 MB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# DISK plots
	printf "%s \n" "<div id=\"diskChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"text rcorners inline warningText\" >" >> $DCRAB_HTML
	printf "%s \n" "<center><b>" >> $DCRAB_HTML
	printf "%s \n" "-- WARNING --<br>" >> $DCRAB_HTML
	printf "%s \n" "Disk charts are generated<br>" >> $DCRAB_HTML
	printf "%s \n" "with general statistics of the disk<br>" >> $DCRAB_HTML
	printf "%s \n" "usage during the execution. This <br>" >> $DCRAB_HTML
	printf "%s \n" "means that is not considering only<br>" >> $DCRAB_HTML
	printf "%s \n" "your job disk usage but the whole node.<br>" >> $DCRAB_HTML
	printf "%s \n" "So keep in mind when analizing the<br>" >> $DCRAB_HTML
	printf "%s \n" "chart because maybe can be another<br>" >> $DCRAB_HTML
	printf "%s \n" "job using the lscratch <br>" >> $DCRAB_HTML
	printf "%s \n" "</b></center>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot\" id='plot_disk_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# IB plots
	printf "%s \n" "<div id=\"ibChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"text rcorners inline warningText\" >" >> $DCRAB_HTML
	printf "%s \n" "<center><b>" >> $DCRAB_HTML
	printf "%s \n" "-- WARNING --<br>" >> $DCRAB_HTML
	printf "%s \n" "Infiniband charts are generated<br>" >> $DCRAB_HTML
	printf "%s \n" "with general statistics of the IB<br>" >> $DCRAB_HTML
	printf "%s \n" "port during the execution. This <br>" >> $DCRAB_HTML
	printf "%s \n" "means that is not considering only<br>" >> $DCRAB_HTML
	printf "%s \n" "your job IB usage but the whole node.<br>" >> $DCRAB_HTML
	printf "%s \n" "So keep in mind when analizing the<br>" >> $DCRAB_HTML
	printf "%s \n" "chart because maybe can be another<br>" >> $DCRAB_HTML
	printf "%s \n" "job using IB device <br>" >> $DCRAB_HTML
	printf "%s \n" "</b></center>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot\" id='plot_ib_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# NFS plots
	printf "%s \n" "<div id=\"nfsChart\" class=\"chart\" style=\"display:block;\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"overflowDivs\">" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"text rcorners inline warningText\" >" >> $DCRAB_HTML
	printf "%s \n" "<center><b>" >> $DCRAB_HTML
	printf "%s \n" "-- WARNING --<br>" >> $DCRAB_HTML
	printf "%s \n" "NFS charts are generated<br>" >> $DCRAB_HTML
	printf "%s \n" "with general statistics of NFS of<br>" >> $DCRAB_HTML
	printf "%s \n" "the node during the execution. This <br>" >> $DCRAB_HTML
	printf "%s \n" "means that is not considering only<br>" >> $DCRAB_HTML
	printf "%s \n" "your job NFS usage but the whole node.<br>" >> $DCRAB_HTML
	printf "%s \n" "So keep in mind when analizing the<br>" >> $DCRAB_HTML
	printf "%s \n" "chart because maybe can be another<br>" >> $DCRAB_HTML
	printf "%s \n" "job using scicomp mount point <br>" >> $DCRAB_HTML
	printf "%s \n" "</b></center>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	i=1
	while [ $i -le $DCRAB_NNODES ]; do
		printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
		printf "%s \n" "<table><tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"width: 1100px;\" class=\"header\">$(echo $DCRAB_NODES | cut -d' ' -f $i)</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr><td>" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"plot inline\" id='plot_nfs_$(echo $DCRAB_NODES_MOD | cut -d' ' -f$i)'></div>" >> $DCRAB_HTML
		printf "%s \n" "<div style=\"border: 0px; margin-left: 75px;\" class=\"plot inline\">" >> $DCRAB_HTML
		printf "%s \n" "<div class=\"text\">" >> $DCRAB_HTML
		printf "%s \n" "<table id=\"textmem2\">" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Total Read</u></b>:</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td>0 MB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td><b><u>Total Write</u></b>:</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "<tr style=\"border: 0px;\"><td>0 MB</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		printf "%s \n" "</td></tr>" >> $DCRAB_HTML
		printf "%s \n" "</table>" >> $DCRAB_HTML
		printf "%s \n" "</div>" >> $DCRAB_HTML
		i=$((i+1))
	done
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML

	# Foot
	printf "%s \n" "<div id='foot'>" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"inline\">&nbsp;&nbsp;&nbsp;</div>" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"inline\">" >> $DCRAB_HTML
	printf "%s \n" "<a href=\"http://dipc.ehu.es/\" target=\"_blank\">" >> $DCRAB_HTML
	printf "%s \n" "<svg version=\"1.1\" x=\"0px\" y=\"0px\" width=\"90px\" height=\"45px\" viewBox=\"0 0 90 45\" enable-background=\"new 0 0 90 45\" xml:space=\"preserve\" style=\"margin-top: 10px;\"><image width=\"90\" height=\"45\" x=\"0\" y=\"0\"" >> $DCRAB_HTML
	printf "%s \n" "xlink:href=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHgAAABFCAMAAAC2XtKTAAAABGdBTUEAALGPC/xhBQAAACBjSFJN" >> $DCRAB_HTML
	printf "%s \n" "AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAACvlBMVEUAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAkt0ClN4ClN0ClN0Ak+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlN0Cld0ClN4AkdoAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAClN4ClN0AAAAAAAAAAAAAAAAAAAAAAAAAkdoC" >> $DCRAB_HTML
	printf "%s \n" "ld0Ck90ClN0Ak+QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >> $DCRAB_HTML
	printf "%s \n" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD" >> $DCRAB_HTML
	printf "%s \n" "ld7///8fboK2AAAA53RSTlMAudnOlm9AGAE20d/OMjLf0TYvydjMtJFoORNu/vHPThE88/A4OPDz" >> $DCRAB_HTML
	printf "%s \n" "PDTu/e3Gh0MLEPQXrVwNuPy7Xwf4rlGbiyIz98dYtkfk1F564WP2+XbiYOxivy6Yr97y/ntlqPXb" >> $DCRAB_HTML
	printf "%s \n" "OhVqcmkTEm3Xw6cEnZMFHamx5QlbwCEcjCyebI2BGycmGQyVVNYequsIKcKOP9px+n6lZBUoK9wW" >> $DCRAB_HTML
	printf "%s \n" "f0YCnOhF8iB4N/t5hiMOyGqIZ4l86n01aVNJTzDFMUS1BqEDg0zjLc2j4KRZ7+k+VySFwVrLptNC" >> $DCRAB_HTML
	printf "%s \n" "cpSA1TusVp9IVZdN0pK9ilAPa8oM3lJWAAAAAWJLR0TpUdNHlAAAAAlwSFlzAAALEwAACxMBAJqc" >> $DCRAB_HTML
	printf "%s \n" "GAAAAAd0SU1FB+ELBwcDCNtyplsAAAVgSURBVGje7djrW1RFGADwl10RuslmIGjLxQq5LHKnFljU" >> $DCRAB_HTML
	printf "%s \n" "AgkQRFnStiKgGwi7LggEZIi6EJlQbIiUUEKSEJKEhDfUwgpKpAxL7SJZWtOf0VluO3POnN1zOE/f" >> $DCRAB_HTML
	printf "%s \n" "eD/xvPPO/M5lds4M4CCTOyxyXOzkDJS46+57rHHvfQBL5C7WUNwPsPQBV7dl7h7LV4CwcHZa/OAi" >> $DCRAB_HTML
	printf "%s \n" "B7nMAVwQE0pPL3dvH27Zyof+tcbDjwD4rkLW8PMHCAi0/KUKWh0cEmqfDfN29/JUWnq4TMOWCHfw" >> $DCRAB_HTML
	printf "%s \n" "iJgvbInAyKhHbbMRHo+Fz1ZjMELq6JjY+cMIaeLWOPOzsTHRamstATNd1wZIgJm7Xvc4n/vE2ni8" >> $DCRAB_HTML
	printf "%s \n" "kgUjlLBeCoxQ4pN0d30CWceBUZKjJBglp9BcxyRkD0bxGyTBKDWN627YiOzDKH2TJBhtzmC7m9KR" >> $DCRAB_HTML
	printf "%s \n" "EBhpMyXBSOZNuplaJAxGySGSYPTUFtwNSUZCYRQXIQlGW7H1IOJpRIV1tLRyZoKtfOZZa4iANdgE" >> $DCRAB_HTML
	printf "%s \n" "e05Jq9BBVvDzimxOPid3qtMLL75kjZdfocB5+esit3HnTsHcQpKbw2nMVhQGZzFNeqc1hiB243b6" >> $DCRAB_HTML
	printf "%s \n" "4seBmTAWRRWHs7rPPjJw3s4eOciwxkk/O57eeweruWS5YJiJ0rJXWf3l5TM3XMJq2OGtJ0asqGS9" >> $DCRAB_HTML
	printf "%s \n" "imAxMMBrO8nuqten88GsJ1FVxB5Sv4uUvaot2d1Y7LEFw96tJLHMZMlWe5HuLj33ZkpriBpNrcWR" >> $DCRAB_HTML
	printf "%s \n" "lVjjjQBbMNS9SfTf52tJ1mqIZM1btMe4v54oamBS/n5YYpWvTRjefoe4uUZLroEYsn4/9f1Blhmv" >> $DCRAB_HTML
	printf "%s \n" "KggTCcO7xMtqYp5qWAGeMR+gu9BMlCUdFAu3vIf3V7wPcJD4GtY388BwCL/k7FaxcNsHOPNhC0Ar" >> $DCRAB_HTML
	printf "%s \n" "vjQpD/G5cLgdq1OliYUhDdtUoWzmS5OmwhLth3nhDnzhVn4kGj6CL9ydzCbqY/wR6jp44RVy/Fkd" >> $DCRAB_HTML
	printf "%s \n" "FQ13bcafGLMcH8XHk+fxwt2f4IWVouEifHYpewAq8fESunlhHze88JhouBz/uKt6AT7Fx3ML44Wr" >> $DCRAB_HTML
	printf "%s \n" "ZfgVHxcNL+3DWtVRAJ/h71hWzQv345sj5QnR8AD+YY7/HKAHh7X9vHAPPvvTB0XDxKdIuwRgEL8S" >> $DCRAB_HTML
	printf "%s \n" "VQ+fG1uMd+w7KRZuPoX3l1UAnN6HZ4pjeeAz+CtCigixcArxKTpbymz0FMStnKG7Qwa8Cp07LxJu" >> $DCRAB_HTML
	printf "%s \n" "Pkv0v8Ckzp8jUoYhKtxLHOdUzNwSBx8nPk7ZX1hyJ/BZg+J7ae6gK3F1Xw6LhDOJ94ku7rUkt5CH" >> $DCRAB_HTML
	printf "%s \n" "tW2DXLf2IlGCvjKKgw98TfY/NpU1fkNm5bUstruRtbGPHwExcMWFUbL/t99NN4zEk3ldI75w+lyK" >> $DCRAB_HTML
	printf "%s \n" "VJHtKNFHBByRFs0+LhiMM0MnshpUkZemhoaxgIHL45zjqyYGBMK7fb+v+sHM7t/XOntTGRp228b6" >> $DCRAB_HTML
	printf "%s \n" "ywMBYzAeyD2AIHTFJBA++eOomdK/au4gYrpCaU4PHKefFnMmQCBMP7SdarG+x4kcWgX9mKq6CpLg" >> $DCRAB_HTML
	printf "%s \n" "0TJ84l5VUUrocE2sJJi1q4v9SShcOLc5mh9cYyJ/qx2FwuC4YZAEGyrYi9NwnBC4CZsY84CVNZSN" >> $DCRAB_HTML
	printf "%s \n" "RkuTXbjTvQ6kwKM/m4ASde6dtuFr+UaQAq+OAnoY86/ZgP12XifLRcLahmHgjesGPx64/cYv7L2J" >> $DCRAB_HTML
	printf "%s \n" "KFj76282/mvM/Kx+v9HOhc05NydDObXCYc0fVRNDYCdCJ2/mmGdhndrsmVpwq6yrjVLp3660Bh0O" >> $DCRAB_HTML
	printf "%s \n" "UmtGdX/+NVBhT52Ktq6yWwWpnma1DkYybueO3eF5Rnlpf1sjM4wCd6ekTB4pNwlSp8P5zlju7YwR" >> $DCRAB_HTML
	printf "%s \n" "ET0sYXtf/T/GArwAL8AL8AK8APPG6QRXa/zTL2Gk/wAZVizK4pjBSAAAACV0RVh0ZGF0ZTpjcmVh" >> $DCRAB_HTML
	printf "%s \n" "dGUAMjAxNy0xMS0wN1QwNzowMzowOC0wNzowML75CnwAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMTct" >> $DCRAB_HTML
	printf "%s \n" "MTEtMDdUMDc6MDM6MDgtMDc6MDDPpLLAAAAAAElFTkSuQmCC\"/>" >> $DCRAB_HTML
	printf "%s \n" "</a>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "<div style=\"font-size: 12px; display: table-cell; vertical-align: middle;\" class=\"text inline\">" >> $DCRAB_HTML
	printf "%s \n" "Copyright &copy; 2018 DIPC (Donostia International Physics Center)" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"vl\"></div>" >> $DCRAB_HTML
	printf "%s \n" "<a href=\"http://dipc.ehu.es/cc/computing_resources/index.html\" target=\"_blank\" style=\"text-decoration: none; color: black;\"><b>Technical Documentation</b></a>" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"vl\"></div>" >> $DCRAB_HTML
	printf "%s \n" "<a href=\"http://dipc.ehu.es/\" target=\"_blank\"  style=\"text-decoration: none; color: black;\"><b>DIPC Home Page</b></a>" >> $DCRAB_HTML
	printf "%s \n" "<div class=\"vl\"></div>" >> $DCRAB_HTML
	printf "%s \n" "</div>" >> $DCRAB_HTML
	printf "%s \n" "</body> " >> $DCRAB_HTML
	################# END BODY #################

	printf "%s \n" "</html> " >> $DCRAB_HTML

	# Change permissions to the main html report
	chmod 755 $DCRAB_HTML
}

