#!/bin/bash
# DCRAB SOFTWARE
# Version: 1.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains the necessary functions for the monitorization in the nodes. Used in the core script
# of the nodes 'scripts/dcrab_startDataCollection.sh'.
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================

init_variables () {

	# Host
	DCRAB_NODE_NUMBER=$1
	DCRAB_DCRAB_PID=$$
	node_hostname=`hostname`
	node_hostname_mod=`echo $node_hostname | sed 's|-||g'`

	# Time 
	DCRAB_WAIT_TIME_CONTROL=180 # 3 minutes
	DCRAB_SLEEP_TIME_CONTROL=5
	DCRAB_DIFF_TIMESTAMP=0
	DCRAB_NUMBERS_OF_LOOPS_CONTROL=$(( DCRAB_WAIT_TIME_CONTROL / DCRAB_SLEEP_TIME_CONTROL ))

	# Files and directories	
	DCRAB_USER_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_user_processes_$node_hostname.txt
	DCRAB_JOB_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_job_processes_$node_hostname.txt
	DCRAB_MEM_FILE=$DCRAB_REPORT_DIR/data/$node_hostname/dcrab_mem_$node_hostname.txt
	DCRAB_TOTAL_MEM_FILE=$DCRAB_REPORT_DIR/aux/mem/$node_hostname.txt
	DCRAB_TOTAL_MEM_DIR=$DCRAB_REPORT_DIR/aux/mem/
	if [ -d "/sys/class/infiniband/mlx5_0/ports/1/counters_ext/" ]; then
		DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx5_0/ports/1/counters_ext
	else
		DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx4_0/ports/1/counters_ext
	fi
	DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets_64
	DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data_64
	DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets_64
	DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data_64

	# PIDs
        DCRAB_MAIN_PIDS=0
        DCRAB_FIRST_MAIN_PROCESS_PID=""
        DCRAB_NUMBER_MAIN_PIDS=0
        DCRAB_MAIN_PROCESS_LAST_CHILD_PID=""
	DCRAB_RANGE_PIDs=1

	# MPI
        DCRAB_CONTROL_PORT_MAIN_NODE="none1"
        DCRAB_CONTROL_PORT_OTHER_NODE="none2"

	# Updates
        updates=0
	declare -a upd_proc_name
	
	# Data insert lines
	addRow_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addRow space \*\/" $DCRAB_HTML | cut -f1 -d:`
	addColumn_data_line=`grep -n -m 1 "\/\* $node_hostname_mod addColumn space \*\/" $DCRAB_HTML | cut -f1 -d:`
	
	# CPU
	cpu_data=""
	cpu_addRow_inject_line=$((addRow_data_line + 2))
	cpu_addColumn_inject_line=$((addColumn_data_line + 1))
	cpu_threshold="5.0"
	
	# MEM
	mem_data=""
	node_total_mem=`free -g | grep "Mem" | awk ' {printf $2}'`
	# Area chart
	mem_addRow_inject_line=$((addRow_data_line + 7))
	# Pie chart
	memUsed_addRow_inject_line=$((addRow_data_line + 11))
	memUnUsed_addRow_inject_line=$((addRow_data_line + 12))
	# Total pie chart
	if [ "$DCRAB_NODE_NUMBER" -eq 0 ] && [ "$DCRAB_NNODES" -gt 1 ]; then
	        mem_total_plot_line=$(grep -n -m 1 "var total_mem" $DCRAB_HTML | cut -f1 -d:)
	        memUsed_total_plot_line=$((mem_total_plot_line + 2))
	        memUnUsed_total_plot_line=$((mem_total_plot_line + 3))
	
	        mem_total_plot_text_line=$(grep -n -m 1 "id='plot_total_mem'" $DCRAB_HTML | cut -f1 -d:)
	        mem_total_plot_requested_text_line=$((mem_total_plot_text_line + 4))
	        mem_total_plot_VmRSS_text_line=$((mem_total_plot_text_line + 5))
	        mem_total_plot_VmSize_text_line=$((mem_total_plot_text_line + 6))
	
	        mem_total_options_color_line=$(grep -n -m 1 "var total_mem_options" $DCRAB_HTML | cut -f1 -d:)
	        mem_total_options_color_line=$((mem_total_options_color_line + 4))

		total_max_vmSize=0
	        total_max_vmRSS=0
        	total_vmSize=0
	        total_vmRSS=0
		exceeded=0
	        changed=0

	fi
	# Pie table text
	mem_piePlot1_div_line=$(grep -n -m 1 "id='plot1_mem_$node_hostname_mod" $DCRAB_HTML | cut -f1 -d:)
	mem_piePlot1_nodeMemory_line=$((mem_piePlot1_div_line + 4))
	mem_piePlot1_requestedMemory_line=$((mem_piePlot1_div_line + 5))
	mem_piePlot1_VmRSS_text_line=$((mem_piePlot1_div_line + 6))
	mem_piePlot1_VmSize_text_line=$((mem_piePlot1_div_line + 7))
        max_RSS_size=0
        max_vmSize=0

	# IB
        ib_data=""
        ib_addRow_inject_line=$((addRow_data_line + 16))
	ib_xmit_pck_value=$(cat $DCRAB_IB_XMIT_PACK)
        ib_xmit_data_value=$(cat $DCRAB_IB_XMIT_DATA)
        ib_rcv_pck_value=$(cat $DCRAB_IB_RCV_PACK)
        ib_rcv_data_value=$(cat $DCRAB_IB_RCV_DATA)

}

write_initial_values () {
	
	# Modify pie chart text 
	while [ 1 ]; do
		if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
			sed -i "$mem_piePlot1_nodeMemory_line"'s|\([0-9]\) GB|'"$node_total_mem"' GB|' $DCRAB_HTML 
	                sed -i "$mem_piePlot1_requestedMemory_line"'s|\([0-9]\) GB|'"$DCRAB_REQ_MEM"' GB|' $DCRAB_HTML

		        # Remove lock file
		        rm -f "$DCRAB_LOCK_FILE"
				
			# Exit while
			break
		else
		        echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
		fi
	
		# Sleep a bit to take the lock in the next loop
		echo "Sleeping for the lock ..."
		sleep 0.5
	done

	# Modify total pie chart text
	if [ "$DCRAB_NODE_NUMBER" -eq 0 ] && [ "$DCRAB_NNODES" -gt 1 ]; then
		while [ 1 ]; do
        	        if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
	                        sed -i "$mem_total_plot_requested_text_line"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'"$DCRAB_REQ_MEM"' GB</td></tr>|' $DCRAB_HTML

	                        # Remove lock file
	                        rm -f "$DCRAB_LOCK_FILE"

	                        # Exit while
        	                break
        	        else
                        	echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
                	fi

	                # Sleep a bit to take the lock in the next loop
			echo "Sleeping for the lock ..."
	       	        sleep 0.5
	        done
	fi
}

write_data () {
	### CPU specific change ###
        # Update the plot to insert new processes
        if [ "$updates" -gt 0 ]; then
                for i in $(seq 0 $((updates -1)) ); do
			while [ 1 ]; do
	                        if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
        	                        sed -i "$cpu_addRow_inject_line"'s|\[\([0-9]*\),|\[\1, ,|g' $DCRAB_HTML
					sed -i "$cpu_addColumn_inject_line""s|^|cpu_data_$node_hostname_mod.addColumn('number', '${upd_proc_name[$i]}'); |" $DCRAB_HTML

	                                # Remove lock file
	                                rm -f "$DCRAB_LOCK_FILE"

        	                        # Exit while
	                                break
	                        else
        	                        echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
	                        fi

	                        # Sleep a bit to take the lock in the next loop
				echo "Sleeping for the lock ..."
                        	sleep 0.5
                	done
                done
        fi

	### MEM  specific change ###
	# The main node must make the changes in the total memory plot
	if [ "$DCRAB_NODE_NUMBER" -eq 0 ] && [ "$DCRAB_NNODES" -gt 1 ]; then
		while [ 1 ]; do
	               	if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
        	                sed -i "$memUnUsed_total_plot_line"'s|\([0-9]*[.]*[0-9]*\)\]|'"$total_notUtilizedMem"'\]|' $DCRAB_HTML
                	        sed -i "$memUsed_total_plot_line"'s|\([0-9]*[.]*[0-9]*\)\]|'"$total_utilizedMem"'\]|' $DCRAB_HTML
                        	sed -i "$mem_total_plot_VmRSS_text_line"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'"$total_max_vmRSS"' GB</td></tr>|' $DCRAB_HTML
	                        sed -i "$mem_total_plot_VmSize_text_line"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'"$total_max_vmSize"' GB</td></tr>|' $DCRAB_HTML

                                # Remove lock file
                                rm -f "$DCRAB_LOCK_FILE"

                                # Exit while
                                break
                        else
                                echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
                        fi

                        # Sleep a bit to take the lock in the next loop
			echo "Sleeping for the lock ..."
                        sleep 0.5
                done
	        if [ "$exceeded" -eq 1 ] && [ "$changed" -eq 0 ]; then
			while [ 1 ]; do
                                if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
                                        sed -i "$mem_total_options_color_line"'s/#3366CC/#ff0000/' $DCRAB_HTML

                                        # Remove lock file
                                        rm -f "$DCRAB_LOCK_FILE"

                                        # Exit while
                                        break
                                else
                                        echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
                                fi

                                # Sleep a bit to take the lock in the next loop
				echo "Sleeping for the lock ..."
                                sleep 0.5
                        done
	                exceeded=0
	                changed=1
	        fi
	fi

        # Write data 
	while [ 1 ]; do
                if ( set -o noclobber; echo "$node_hostname" > "$DCRAB_LOCK_FILE") 2> /dev/null; then
			### CPU ###
	                sed -i "$cpu_addRow_inject_line"'s/.*/&'"$cpu_data"'/' $DCRAB_HTML

	                ### MEM ###
	                sed -i "$mem_addRow_inject_line"'s/.*/&'"$mem_data"'/' $DCRAB_HTML
	                sed -i "$memUnUsed_addRow_inject_line"'s|\([0-9]*[.]*[0-9]*\)\]|'"$notUtilizedMem"'\]|' $DCRAB_HTML
	                sed -i "$memUsed_addRow_inject_line"'s|\([0-9]*[.]*[0-9]*\)\]|'"$utilizedMem"'\]|' $DCRAB_HTML
	                sed -i "$mem_piePlot1_VmRSS_text_line"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'"$max_RSS_size"' GB</td></tr>|' $DCRAB_HTML
	                sed -i "$mem_piePlot1_VmSize_text_line"'s|\([0-9]*[.]*[0-9]*\) GB</td></tr>|'"$max_vmSize"' GB</td></tr>|' $DCRAB_HTML

        	        # IB 
	                sed -i "$ib_addRow_inject_line"'s/.*/&'"$ib_data"'/' $DCRAB_HTML

                	# Remove lock file
		        rm -f "$DCRAB_LOCK_FILE"

        	        # Exit while
                	break
                else
        	        echo "Lock Exists: $DCRAB_LOCK_FILE owned by $(cat $DCRAB_LOCK_FILE)"
                fi

                # Sleep a bit to take the lock in the next loop
		echo "Sleeping for the lock ..."
	        sleep 0.5
        done
}

dcrab_collect_mem_data () {

	# Store the data of all the processes 
	:> $DCRAB_MEM_FILE
	for pid in $(cat $DCRAB_JOB_PROCESSES_FILE | awk '{print $1}'); do cat /proc/$pid/status 2> /dev/null 1 >> $DCRAB_MEM_FILE; done

	# Collect memory data of the file
    	vmSize=$(grep VmSize $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}') 
	vmSize=$(printf "%.3f\n" "$vmSize") # 3 decimmals only
	vmRSS=$(grep VmRSS $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}')
	vmRSS=$(printf "%.3f\n" "$vmRSS") # 3 decimmals only
	if [ $(echo "$vmRSS > $max_RSS_size" | bc) -eq 1 ]; then
        	max_RSS_size=$vmRSS
	fi
	if [ $(echo "$vmSize > $max_vmSize" | bc) -eq 1 ]; then
                max_vmSize=$vmSize
        fi

	# Check if exceeds memory requested. The job may be killed by the scheduler.
        if [ $(echo "$max_RSS_size < $DCRAB_REQ_MEM" | bc) -eq 1 ]; then
                utilizedMem=`echo "scale=3; ($max_RSS_size * 100)/$DCRAB_REQ_MEM" | bc `
                notUtilizedMem=`echo "scale=3; 100 - $utilizedMem" | bc `
        else    
                notUtilizedMem=0
                utilizedMem=100
        fi

	if [ "$DCRAB_NNODES" -gt 1 ]; then
		if [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
			total_vmRSS=0
			total_vmSize=0
			
			echo "$vmRSS $vmSize" > $DCRAB_TOTAL_MEM_FILE

			for file in $DCRAB_TOTAL_MEM_DIR/*
			do
				total_vmRSS=$(echo "$total_vmRSS + $(cat $file | awk '{print $1}')" | bc)
				total_vmSize=$(echo "$total_vmSize + $(cat $file | awk '{print $2}')" | bc)
			done
		
			if [ $(echo "$total_vmSize > $total_max_vmSize" | bc) -eq 1 ]; then
		                total_max_vmSize=$total_vmSize
		        fi
			if [ $(echo "$total_vmRSS > $total_max_vmRSS" | bc) -eq 1 ]; then
		                total_max_vmRSS=$total_vmRSS
		        fi	
			
			if [ $(echo "$total_max_vmRSS < $DCRAB_REQ_MEM" | bc) -eq 1 ]; then
				total_utilizedMem=`echo "scale=3; ($total_max_vmRSS * 100)/$DCRAB_REQ_MEM" | bc `
				total_notUtilizedMem=`echo "scale=3; 100 - $total_utilizedMem" | bc `
			else
				total_utilizedMem=100
				total_notUtilizedMem=0
				exceeded=1		
			fi
			
		else
			echo "$vmRSS $vmSize" > $DCRAB_TOTAL_MEM_FILE
		fi
	fi

	# Construct mem data string
	mem_data="$mem_data""$node_total_mem, $DCRAB_REQ_MEM, $max_RSS_size, $vmSize, $vmRSS ],"
}

dcrab_collect_ib_data () {

        new_ib_xmit_pck_value=$(cat $DCRAB_IB_XMIT_PACK)
	new_ib_rcv_pck_value=$(cat $DCRAB_IB_RCV_PACK)	
        new_ib_xmit_data_value=$(cat $DCRAB_IB_XMIT_DATA)
        new_ib_rcv_data_value=$(cat $DCRAB_IB_RCV_DATA)

	local aux1=$( echo "($new_ib_xmit_data_value - $ib_xmit_data_value) / 1024" | bc )
	local aux2=$( echo "($new_ib_rcv_data_value - $ib_rcv_data_value) / 1024" | bc )

	# Construct ib data
	ib_data="$ib_data"" $((new_ib_xmit_pck_value - ib_xmit_pck_value)), $((new_ib_rcv_pck_value - ib_rcv_pck_value)), $aux1, $aux2 ],"
	
	ib_xmit_pck_value=$new_ib_xmit_pck_value
	ib_xmit_data_value=$new_ib_xmit_data_value
	ib_rcv_pck_value=$new_ib_rcv_pck_value
	ib_rcv_data_value=$new_ib_rcv_data_value
}

dcrab_determine_main_process () {

        # CPU
        cpu_data="0,"
	# MEM
	mem_data="[0,"	
	# IB
	ib_data="[0,"

	# MAIN NODE
	echo "$node_hostname , $DCRAB_NODE_NUMBER"
	if [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
	        IFS=$'\n'
		ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm,command | sed 's|\s\s*| |g' | awk '{if ($2 == '"$DCRAB_USER_ID"'){print}}' | grep -v " $DCRAB_DCRAB_PID " > $DCRAB_USER_PROCESSES_FILE
	        for line in $(cat $DCRAB_USER_PROCESSES_FILE)
	        do
			pid=$(echo "$line" | awk '{print $6}')
			echo "$line"  | grep -q "Ss"
			if [ "$?" -eq 0 ]; then
		                pstree $pid | grep -q $DCRAB_JOB_ID
		                if [ "$?" -eq 0 ]; then 
					DCRAB_MAIN_PIDS="$pid"
					DCRAB_FIRST_MAIN_PROCESS_PID=$pid
					DCRAB_FIRST_MAIN_PROCESS_NAME=$(echo "$line" | awk '{print $8}')
	
					# Save last child's pid
					DCRAB_MAIN_PROCESS_LAST_CHILD_PID=$(cat $DCRAB_USER_PROCESSES_FILE | grep $pid | tail -1 | awk '{printf $6}')
				
					break;
				fi
			fi
	        done
	# REST OF NODES
	else
		i=1
		# Wait until the main node creates control port file
		echo "Waiting until control_port.txt has been created"
		while [ ! -f $DCRAB_REPORT_DIR/aux/control_port.txt ]; do 
			echo "Loop number ($i/$DCRAB_NUMBERS_OF_LOOPS_CONTROL). No control_port.txt created yet. Waiting a bit more . . . "
			sleep 5

			# Exit DCRAB if no control_port.txt was created  
			if [ "$i" -eq "$DCRAB_NUMBERS_OF_LOOPS_CONTROL" ]; then
				echo "Waiting much time to control_port. Exiting DCRAB . . ."
				exit 1
			fi
			i=$((i + 1))
		done
		echo "File control_port.txt created!"

		# Wait until the processes of the job start
	        IFS=$'\n'; i=0
		DCRAB_CONTROL_PORT_MAIN_NODE=$(cat $DCRAB_REPORT_DIR/aux/control_port.txt)
		while [ "$DCRAB_CONTROL_PORT_MAIN_NODE" != "$DCRAB_CONTROL_PORT_OTHER_NODE" ]; do
			echo "Waiting until the process in the node $node_hostname start" 
	
	                i=$((i + 1))

	                # Wait if it is not the first loop
	                [[ "$i" -gt 1 ]] && sleep 5
			
			for line in $(ps axo stat,euid,ruid,sess,ppid,pid,pcpu,command | sed 's|\s\s*| |g' | awk '{if ($2 == '"$DCRAB_USER_ID"'){print}}' | grep "Ss")
		        do
				DCRAB_CONTROL_PORT_OTHER_NODE=`echo ${line#*control-port} | awk '{print $1}'`
				if [ "$DCRAB_CONTROL_PORT_OTHER_NODE" == "$DCRAB_CONTROL_PORT_MAIN_NODE" ]; then
					pid=$(echo "$line" | awk '{print $6}')
	                                DCRAB_MAIN_PIDS="$pid"
					DCRAB_FIRST_MAIN_PROCESS_PID=$pid
                                        DCRAB_FIRST_MAIN_PROCESS_NAME=$(echo "$line" | awk '{print $8}')	
					break
				fi
			done
		done
		echo "Processes in node $node_hostname started with '$DCRAB_CONTROL_PORT_OTHER_NODE' control port"
	fi

        # Initialize data file
        for line in $(ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm,command | sed 's|\s\s*| |g' | awk '{if ($2 == '"$DCRAB_USER_ID"'){print}}' | grep -v " $DCRAB_DCRAB_PID " | grep -E "$DCRAB_MAIN_PIDS")
        do
		# Get information of the process
                pid=$(echo "$line" | awk '{print $6}')
                cpu=$(echo "$line" | awk '{print $7}')
                commandName=$(echo "$line" | awk '{print $8}')
		if [ $(echo "$cpu > $cpu_threshold" | bc) -eq 1 ]; then
			# Save in the data file
        	        echo "$pid $commandName" >> $DCRAB_JOB_PROCESSES_FILE

			# If it is the control process the main node must store it. Needed for multinode statistics. 
	                echo $line | grep -q "control-port"
	                if [ "$?" -eq 0 ] && [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
	                        DCRAB_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
	                        echo "$DCRAB_CONTROL_PORT_MAIN_NODE" > $DCRAB_REPORT_DIR/aux/control_port.txt
	                fi

        	        # CPU data
			upd_proc_name[$updates]=$commandName
	                cpu_data="$cpu_data $cpu,"
	
			updates=$((updates + 1))
		fi
        done

	# Initialize file if there is no process 	
	if [ ! -f $DCRAB_JOB_PROCESSES_FILE ]; then
		echo "$DCRAB_FIRST_MAIN_PROCESS_PID $DCRAB_FIRST_MAIN_PROCESS_NAME" > $DCRAB_JOB_PROCESSES_FILE

		# CPU data
                upd_proc_name[$updates]=$commandName
                cpu_data="$cpu_data $cpu,"

		updates=$((updates + 1))
	fi	

        # Get time
        DCRAB_M1_TIMESTAMP=`date +"%s"`

        # CPU data. Remove the last comma
        cpu_data=${cpu_data%,*}
        cpu_data="[$cpu_data ],"

	# MEM data
	dcrab_collect_mem_data

	# IB data
	dcrab_collect_ib_data
	
	write_data 	
}

dcrab_update_data () {
	
        # Init. variables
        updates=0
        IFS=$'\n'
        DCRAB_M2_TIMESTAMP=`date +"%s"`
        DCRAB_DIFF_TIMESTAMP=$((DCRAB_M2_TIMESTAMP - DCRAB_M1_TIMESTAMP))
        # CPU data      
        cpu_data="$DCRAB_DIFF_TIMESTAMP,"
        # MEM data
        mem_data="[$DCRAB_DIFF_TIMESTAMP,"
	# IB data
	ib_data="[$DCRAB_DIFF_TIMESTAMP,"

        # Collect the data
	ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm,command | sed 's|\s\s*| |g' | awk '{if ($2 == '"$DCRAB_USER_ID"'){print}}' | grep -v " $DCRAB_DCRAB_PID " > $DCRAB_USER_PROCESSES_FILE
        cat $DCRAB_USER_PROCESSES_FILE | grep -E "$DCRAB_MAIN_PIDS" > $DCRAB_JOB_PROCESSES_FILE.tmp

	# To check if there is some processes that aren't in the process tree of the main node but belongs the job (this case occurs with mvapich)
	diff -u $DCRAB_JOB_PROCESSES_FILE.tmp $DCRAB_USER_PROCESSES_FILE | grep "^\+" | awk 'NR>1 {print}' | sed 's|+||' > $DCRAB_USER_PROCESSES_FILE.tmp
	if [ $(cat $DCRAB_USER_PROCESSES_FILE.tmp | wc -l) -gt 0 ]; then

		# Renew DCRAB_MAIN_PROCESS_LAST_CHILD_PID variable
                DCRAB_MAIN_PROCESS_LAST_CHILD_PID=$(cat $DCRAB_USER_PROCESSES_FILE | grep $DCRAB_FIRST_MAIN_PROCESS_PID | tail -1 | awk '{printf $6}')
		DCRAB_LAST_CHILD_NEXT_VALID_PID=$((DCRAB_MAIN_PROCESS_LAST_CHILD_PID + 1))
                i=0; found=0
                while [ "$found" -eq 0 ]; do
                	kill -0 $DCRAB_LAST_CHILD_NEXT_VALID_PID >> /dev/null 2>&1
                        [[ $? -eq 0 ]] && found=1 || DCRAB_LAST_CHILD_NEXT_VALID_PID=$((DCRAB_LAST_CHILD_NEXT_VALID_PID + 1))
                done

	        for line in $(cat $DCRAB_USER_PROCESSES_FILE.tmp)
	        do
			pid=$(echo "$line" | awk '{print $6}')
                        if [ "$DCRAB_MAIN_PROCESS_LAST_CHILD_PID" != "" ] && [ "$DCRAB_FIRST_MAIN_PROCESS_PID" != "0" ]; then
                        	# To check that is not child of any of the main processes
                        	pstree -p $DCRAB_FIRST_MAIN_PROCESS_PID | grep -q "$pid"
                                if [ $? -ne 0 ] && 
				   [ "$pid" -le $((DCRAB_MAIN_PROCESS_LAST_CHILD_PID + DCRAB_RANGE_PIDs)) ] && 
				   [ "$pid" -ge $((DCRAB_MAIN_PROCESS_LAST_CHILD_PID - DCRAB_RANGE_PIDs)) ]; then
                               		DCRAB_MAIN_PIDS="$DCRAB_MAIN_PIDS""|""$pid"
                                        DCRAB_NUMBER_MAIN_PIDS=$((DCRAB_NUMBER_MAIN_PIDS + 1))
                                        echo "Another main process confirmed. PID:$pid, COMMAND: $(echo "$line" | awk '{print $8}')"
	
			                # If the new process is the control process. Needed for multinode statistics.
                        		echo $line | grep -q "control-port"
		                        if [ "$?" -eq 0 ] && [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
		                                DCRAB_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
		                                echo "$DCRAB_CONTROL_PORT_MAIN_NODE" > $DCRAB_REPORT_DIR/aux/control_port.txt
                		        fi
				elif [ "$?" -ne "0" ] && [ "$pid" == "$DCRAB_LAST_CHILD_NEXT_VALID_PID" ]; then
					DCRAB_MAIN_PIDS="$DCRAB_MAIN_PIDS""|""$pid"
                                        DCRAB_NUMBER_MAIN_PIDS=$((DCRAB_NUMBER_MAIN_PIDS + 1))
                                        echo "Another main process confirmed. PID:$pid, COMMAND: $(echo "$line" | awk '{print $8}')"

					# If the new process is the control process. Needed for multinode statistics.
                                        echo $line | grep -q "control-port"
                                        if [ "$?" -eq 0 ] && [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
                                                DCRAB_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
                                                echo "$DCRAB_CONTROL_PORT_MAIN_NODE" > $DCRAB_REPORT_DIR/aux/control_port.txt
                                        fi
                                fi
                        fi		                

		done
	fi

        lastEmptyValue=0
        i=1
	# Check first old processes
        for line in $(cat $DCRAB_JOB_PROCESSES_FILE)
        do
                pid=$(echo "$line" | awk '{print $1}')
                commandName=$(echo "$line" | awk '{print $2}')
                auxLine=`cat $DCRAB_JOB_PROCESSES_FILE.tmp | grep -n "$commandName" | awk '{if ($6 == '"$pid"'){print}}'`
                if [ "$auxLine" != "" ]; then
                        lineNumber=$(echo $auxLine | cut -d: -f1)
                        cpu=$(echo "$auxLine" | awk '{print $7}')
                        sed -i "$lineNumber""d" $DCRAB_JOB_PROCESSES_FILE.tmp
                else
                        lastEmptyValue=$i
                        cpu=" "
                fi
                # CPU data
                cpu_data="$cpu_data $cpu,"
                i=$((i + 1))
		auxLine=""
        done

        # Check if there are new processes
        for line in $(cat $DCRAB_JOB_PROCESSES_FILE.tmp)
        do
                pid=$(echo "$line" | awk '{print $6}')
	        cpu=$(echo "$line" | awk '{print $7}')
	        commandName=$(echo "$line" | awk '{print $8}')
	
		
		if [ $(echo "$cpu > $cpu_threshold" | bc) -eq 1 ]; then
	                sed -i '1s|^|'"$pid $commandName"'\n|' $DCRAB_JOB_PROCESSES_FILE
	                upd_proc_name[$updates]=$commandName

			# If the new process is the control process. Needed for multinode statistics.
			echo $line | grep -q "control-port"
			if [ "$?" -eq 0 ] && [ "$DCRAB_NODE_NUMBER" -eq 0 ]; then
				DCRAB_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
				echo "$DCRAB_CONTROL_PORT_MAIN_NODE" > $DCRAB_REPORT_DIR/aux/control_port.txt
			fi

	                # CPU data
	                cpu_data=`echo $cpu_data | sed "s|^$DCRAB_DIFF_TIMESTAMP,|$DCRAB_DIFF_TIMESTAMP, $cpu,|"`

	                updates=$((updates + 1))
		fi
        done

	# CPU data
        # To avoid cpu_data termine like '0, ]', which means that the last process has been terminated, and will cause an error in the plot 
        # So we put a 0 value instead of the ' ' (space) character 
        if [ $((lastEmptyValue + 1)) -eq $i ]; then
                cpu_data=${cpu_data%,*}
                cpu_data="$cpu_data""0,"
        fi
        # Remove the last comma
        cpu_data=${cpu_data%,*}
        cpu_data="[$cpu_data],"
	
        # MEM data
        dcrab_collect_mem_data
	
	# IB data
	dcrab_collect_ib_data
}






