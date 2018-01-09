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

	# Empty file
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
	printf "%s \n" "<head><title>DCRAB REPORT</title>" >> $DCRAB_HTML
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
		printf "%s \n" "['Execution Time (s)', 'Node Memory', 'Requested Memory', 'Consumed Memory Peak (of VmRSS)', 'Consumed Memory  (VmSize)', 'Resident Memory  (VmRSS)']," >> $DCRAB_HTML
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
	printf "%s \n" "width: '$plot_width'," >> $DCRAB_HTML
	printf "%s \n" "height: '$plot_height'," >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Execution Time (s)'}," >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'CPU used (%)'}," >> $DCRAB_HTML
	printf "%s \n" "chartArea: {  width: \"70%\", height: \"80%\" }," >> $DCRAB_HTML
	printf "%s \n" "};" >> $DCRAB_HTML

	# MEM
	printf "%s \n" "var mem1_options = {  " >> $DCRAB_HTML
	printf "%s \n" "title : 'Memory Utilization', " >> $DCRAB_HTML
	printf "%s \n" "vAxis: {title: 'GB'}, " >> $DCRAB_HTML
	printf "%s \n" "hAxis: {title: 'Time (s)'}, " >> $DCRAB_HTML
	printf "%s \n" "width: $plot_width,  " >> $DCRAB_HTML
	printf "%s \n" "height: $plot_height,  " >> $DCRAB_HTML
	printf "%s \n" "axes: {  " >> $DCRAB_HTML
	printf "%s \n" "x: {  " >> $DCRAB_HTML
	printf "%s \n" "0: {side: 'top'}  " >> $DCRAB_HTML
	printf "%s \n" "}  " >> $DCRAB_HTML
	printf "%s \n" "},  " >> $DCRAB_HTML
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
	printf "%s \n" "vAxis: {title: 'MB/s'}, " >> $DCRAB_HTML
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
		printf "%s \n" "var mem2_chart_$node = new google.visualization.PieChart(document.getElementById('plot2_mem_$node'));"  >> $DCRAB_HTML

		printf "%s \n" "mem1_chart_$node.draw(mem1_$node, mem1_options);  " >> $DCRAB_HTML
		printf "%s \n" "mem2_chart_$node.draw(mem2_$node, mem2_options);  " >> $DCRAB_HTML

		# IB
		printf "%s \n" "var ib_chart_$node = new google.visualization.LineChart(document.getElementById('plot_ib_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "ib_chart_$node.draw(ib_data_$node, ib_options);  " >> $DCRAB_HTML

		# PROCESSESIO
		printf "%s \n" "var processesIO_chart_$node = new google.visualization.AreaChart(document.getElementById('plot_processesIO_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "processesIO_chart_$node.draw(processesIO_data_$node, processesIO_options);  " >> $DCRAB_HTML

		# NFS
		printf "%s \n" "var nfs_chart_$node = new google.visualization.AreaChart(document.getElementById('plot_nfs_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "nfs_chart_$node.draw(nfs_data_$node, nfs_options);  " >> $DCRAB_HTML

		# DISK
		printf "%s \n" "var disk_chart_$node = new google.visualization.ColumnChart(document.getElementById('plot_disk_$node'));"  >> $DCRAB_HTML
		printf "%s \n" "disk_chart_$node.draw(disk_data_$node, disk_options);  " >> $DCRAB_HTML
	done

	if [ "$DCRAB_NNODES" -gt 1 ]; then
		printf "%s \n" "var total_mem_chart = new google.visualization.PieChart(document.getElementById('plot_total_mem'));" >> $DCRAB_HTML
		printf "%s \n" "total_mem_chart.draw(total_mem, total_mem_options);" >> $DCRAB_HTML
	fi

	printf "%s \n" "}" >> $DCRAB_HTML
	################# END plot function #################
	printf "%s \n" "</script>" >> $DCRAB_HTML

	################# Style #################
	printf "%s \n" "<style>" >> $DCRAB_HTML
	printf "%s \n" "body {" >> $DCRAB_HTML
	printf "%s \n" "background: #25c481; /* Old browsers */" >> $DCRAB_HTML
	printf "%s \n" "background: url(data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiA/Pgo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgdmlld0JveD0iMCAwIDEgMSIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+CiAgPGxpbmVhckdyYWRpZW50IGlkPSJncmFkLXVjZ2ctZ2VuZXJhdGVkIiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMCUiPgogICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzI1YzQ4MSIgc3RvcC1vcGFjaXR5PSIxIi8+CiAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMyNWI3YzQiIHN0b3Atb3BhY2l0eT0iMSIvPgogIDwvbGluZWFyR3JhZGllbnQ+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjEiIGhlaWdodD0iMSIgZmlsbD0idXJsKCNncmFkLXVjZ2ctZ2VuZXJhdGVkKSIgLz4KPC9zdmc+);" >> $DCRAB_HTML
	printf "%s \n" "background: -moz-linear-gradient(left,  #25c481 0%, #25b7c4 100%); /* FF3.6-15 */" >> $DCRAB_HTML
	printf "%s \n" "background: -webkit-linear-gradient(left,  #25c481 0%,#25b7c4 100%); /* Chrome10-25,Safari5.1-6 */" >> $DCRAB_HTML
	printf "%s \n" "background: linear-gradient(to right,  #25c481 0%,#25b7c4 100%); /* W3C, IE10+, FF16+, Chrome26+, Opera12+, Safari7+ */" >> $DCRAB_HTML
	printf "%s \n" "filter: progid:DXImageTransform.Microsoft.gradient( startColorstr='#25c481', endColorstr='#25b7c4',GradientType=1 ); /* IE6-8 */" >> $DCRAB_HTML
	printf "%s \n" "margin: 0px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".inline {" >> $DCRAB_HTML
	printf "%s \n" "display:inline-block;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".text {" >> $DCRAB_HTML
	printf "%s \n" "font-family: Consolas,monospace;" >> $DCRAB_HTML
	printf "%s \n" "font-size: 18px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".vl {" >> $DCRAB_HTML
	printf "%s \n" "display: inline; " >> $DCRAB_HTML
	printf "%s \n" "border-left: 2px solid black;" >> $DCRAB_HTML
	printf "%s \n" "height: 10px;" >> $DCRAB_HTML
	printf "%s \n" "padding-right:5em;" >> $DCRAB_HTML
	printf "%s \n" "margin-left:5em;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "table {" >> $DCRAB_HTML
	printf "%s \n" "border-collapse: collapse;" >> $DCRAB_HTML
	printf "%s \n" "margin: 15px;" >> $DCRAB_HTML
	printf "%s \n" "margin-top: 2px;" >> $DCRAB_HTML
	printf "%s \n" "margin-bottom: 2px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "tr {" >> $DCRAB_HTML
	printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".overflowDivs {" >> $DCRAB_HTML
	printf "%s \n" "overflow:auto;" >> $DCRAB_HTML
	printf "%s \n" "white-space: nowrap;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".header {" >> $DCRAB_HTML
	printf "%s%s \n" "width: $plot_width" "px;" >> $DCRAB_HTML
	printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
	printf "%s \n" "float: left;" >> $DCRAB_HTML
	printf "%s \n" "text-align: center;" >> $DCRAB_HTML
	printf "%s \n" "font-family: 'Roboto', sans-serif;" >> $DCRAB_HTML
	printf "%s \n" "font-size: 16px;" >> $DCRAB_HTML
	printf "%s \n" "color: #fff;" >> $DCRAB_HTML
	printf "%s \n" "text-transform: uppercase;" >> $DCRAB_HTML
	printf "%s \n" "vertical-align: middle;" >> $DCRAB_HTML
	printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".plot{" >> $DCRAB_HTML
	printf "%s \n" "vertical-align:middle;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "#foot {" >> $DCRAB_HTML
	printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
	printf "%s \n" "margin-top: 180px;" >> $DCRAB_HTML
	printf "%s \n" "display: table;" >> $DCRAB_HTML
	printf "%s \n" "width:100%;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "#textmem2 {" >> $DCRAB_HTML
	printf "%s \n" "border-spacing: 5px;" >> $DCRAB_HTML
	printf "%s \n" "border-collapse: separate;" >> $DCRAB_HTML
	printf "%s \n" "margin: 0 auto;" >> $DCRAB_HTML
	printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3); " >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" "#detailedText {" >> $DCRAB_HTML
	printf "%s \n" "vertical-align: top;" >> $DCRAB_HTML
	printf "%s \n" "padding-top: 230px;" >> $DCRAB_HTML
	printf "%s \n" "font-family: 'Roboto', sans-serif;" >> $DCRAB_HTML
	printf "%s \n" "font-size: 56px;" >> $DCRAB_HTML
	printf "%s \n" "color: #fff;" >> $DCRAB_HTML
	printf "%s \n" "text-transform: uppercase;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" ".rcorners {" >> $DCRAB_HTML
	printf "%s \n" "border: 1px solid rgba(254, 254, 254, 0.3);" >> $DCRAB_HTML
	printf "%s \n" "background-color: rgba(255,255,255,0.3);" >> $DCRAB_HTML
	printf "%s \n" "border-radius: 25px;" >> $DCRAB_HTML
	printf "%s \n" "margin : 40px;" >> $DCRAB_HTML
	printf "%s \n" "padding-left: 15px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "" >> $DCRAB_HTML
	printf "%s \n" ".textbox {" >> $DCRAB_HTML
	printf "%s \n" "width:49%;" >> $DCRAB_HTML
	printf "%s \n" "height: 300px;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" ".warningText {" >> $DCRAB_HTML
	printf "%s \n" "height: 200px;" >> $DCRAB_HTML
	printf "%s \n" "vertical-align: top;" >> $DCRAB_HTML
	printf "%s \n" "margin-top: 230px;" >> $DCRAB_HTML
	printf "%s \n" "color: #ff8000;" >> $DCRAB_HTML
	printf "%s \n" "}" >> $DCRAB_HTML
	printf "%s \n" "</style>" >> $DCRAB_HTML
	################# END Style #################

	################# BODY #################
	printf "%s \n" "<body>" >> $DCRAB_HTML
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

	# CPU plots 
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
	printf "%s \n" "<br><br><br>" >> $DCRAB_HTML

	# MEM plots 
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
	printf "%s \n" "<br><br><br>" >> $DCRAB_HTML

	# PROCESSESIO plots
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
	printf "%s \n" "<br><br><br>" >> $DCRAB_HTML

	# DISK plots
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
	printf "%s \n" "<br><br><br>" >> $DCRAB_HTML

	# IB plots
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
	# NFS plots
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
	printf "%s \n" "<br><br><br>" >> $DCRAB_HTML

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
	printf "%s \n" "<a href=\"http://dipc.ehu.es/cc/computing_resources/index.html\" target=\"_blank\"  style=\"text-decoration: none; color: black;\"><b>Technical Documentation</b></a>" >> $DCRAB_HTML
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

