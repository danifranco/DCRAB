#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains the necessary functions for the monitorization in the nodes
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================


#
# Initializes necessary variables 
# Arguments:
#	1- Int --> The number of the node (0 is the main node, the rest of the numbers are considered as 'slave' nodes)
#
dcrab_node_monitor_init_variables () {
	
	# Execution control
	DCRAB_ACTIVE_JOB_IN_MAIN_NODE=1
	DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER=0
	DCRAB_NUMBER_OF_MPI_COMMANDS=0
	DCRAB_SLEEP_FOR_NEXT_MPI_JOB=0
	
	# Host
	DCRAB_NODE_EXECUTION_NUMBER=$1
        DCRAB_DCRAB_SESSION=$(ps axo sess,pid,comm | grep "dcrab" | awk '{if ($2 == '"$$"'){print}}' | awk '{print $1}')
        DCRAB_NODE_HOSTNAME=$(hostname)
	DCRAB_NODE_NUMBER=${DCRAB_NODE_HOSTNAME#*-}
	DCRAB_NODE_NUMBER=$(echo "$DCRAB_NODE_NUMBER +1 -1" | bc) # To ommit tthe zeros in the name
        DCRAB_NODE_HOSTNAME_MOD=`echo $DCRAB_NODE_HOSTNAME | sed 's|-||g'`
        DCRAB_NODE_TOTAL_MEM=`free -g | grep "Mem" | awk ' {printf $2}'`
        [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ] && DCRAB_PREVIOUS_NODE=$((DCRAB_NNODES - 1)) || DCRAB_PREVIOUS_NODE=$((DCRAB_NODE_EXECUTION_NUMBER - 1))
	
        # Time control
        DCRAB_WAIT_TIME_CONTROL=1200
        DCRAB_DIFF_TIMESTAMP=0
        DCRAB_NUMBERS_OF_LOOPS_CONTROL=$(( DCRAB_WAIT_TIME_CONTROL / DCRAB_SLEEP_TIME_CONTROL ))
        DCRAB_LOOP_BEFORE_CRASH=180
        DCRAB_FIRST_WRITE=0

	# Files and directories 
        DCRAB_USER_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/user_processes
        DCRAB_JOB_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/job_processes
        DCRAB_JOB_CANDIDATE_PROCESSES_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/job_candidate_processes
	DCRAB_MPI_PROCESSES_FILE=$DCRAB_REPORT_DIR/aux/mpi
	DCRAB_WAIT_MPI_PROCESSES_FILE=$DCRAB_WAIT_MPI_PROCESSES_DIR/$DCRAB_NODE_HOSTNAME
	[ "$DCRAB_NODE_EXECUTION_NUMBER" -ne 0 ] && echo "1" > $DCRAB_WAIT_MPI_PROCESSES_FILE
	DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE=$DCRAB_REPORT_DIR/aux/activeJobMainNode
	DCRAB_CONTROL_PORT_FILE_PREFIX=$DCRAB_REPORT_DIR/aux/control_port
        DCRAB_CONTROL_PORT_FILE=""

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		# Files and directories	
		DCRAB_COMMAND_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/commandFile
		touch $DCRAB_COMMAND_FILE
		chmod 755 $DCRAB_COMMAND_FILE
		DCRAB_MEM_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/mem
		DCRAB_TOTAL_MEM_DIR=$DCRAB_REPORT_DIR/aux/mem
		DCRAB_TOTAL_MEM_FILE=$DCRAB_TOTAL_MEM_DIR/$DCRAB_NODE_HOSTNAME.txt
		if [ -d "/sys/class/infiniband/mlx5_0/ports/1/counters_ext/" ]; then
			DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx5_0/ports/1/counters_ext
			DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets_64
			DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data_64
			DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets_64
			DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data_64
		elif [ -d "/sys/class/infiniband/mlx5_0/ports/1/counters/" ]; then
			DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx5_0/ports/1/counters
			DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets
			DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data
			DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets
			DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data
		elif [ -d "/sys/class/infiniband/mlx4_0/ports/1/counters/" ]; then
			DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx4_0/ports/1/counters
			DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets
			DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data
			DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets
			DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data
		else
			DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx4_0/ports/1/counters_ext
			DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets_64
			DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data_64
			DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets_64
			DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data_64
		fi
		DCRAB_TOTAL_IB_DIR=$DCRAB_REPORT_DIR/aux/ib
	        DCRAB_TOTAL_IB_FILE=$DCRAB_TOTAL_IB_DIR/$DCRAB_NODE_HOSTNAME.txt
		echo "" > $DCRAB_TOTAL_IB_FILE
		DCRAB_PROCESSES_IO_FILE=$DCRAB_REPORT_DIR/data/$DCRAB_NODE_HOSTNAME/processesIO
		DCRAB_TOTAL_DISK_DIR=$DCRAB_REPORT_DIR/aux/ldisk
	        DCRAB_TOTAL_DISK_FILE=$DCRAB_TOTAL_DISK_DIR/$DCRAB_NODE_HOSTNAME.txt
		echo "" > $DCRAB_TOTAL_DISK_FILE

		# Main session and PIDs
		DCRAB_MAIN_SESSION=0
		DCRAB_TOTAL_PROCESSES=1
		DCRAB_FIRST_MAIN_PROCESS_PID=""
		DCRAB_FIRST_MAIN_PROCESS_NAME=""
		#DCRAB_NUMBER_MAIN_PIDS=0
		#DCRAB_MAIN_PROCESS_LAST_CHILD_PID=""
		#DCRAB_RANGE_PIDs=1
	
		# MPI
		DCRAB_MPI_CONTROL_PORT_MAIN_NODE=""
		DCRAB_MPI_CONTROL_PORT_OTHER_NODE=""
		DCRAB_MPI_CONTROL_WRITED=0
		
		# CPU
		DCRAB_CPU_DATA=""
		DCRAB_CPU_BASELINE=$(grep -n -m 1 "var cpu_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)		
		DCRAB_CPU_L1=$((DCRAB_CPU_BASELINE + 1))
		DCRAB_CPU_L2=$((DCRAB_CPU_BASELINE + 2))
		DCRAB_CPU_THRESHOLD="5.0"
		DCRAB_CPU_UPDATES=0
		DCRAB_CPU_UPDATE_STRING1=""
		DCRAB_CPU_UPDATE_STRING2=""
	
		# MEM
		DCRAB_MEM_DATA=""
		DCRAB_MEM_VMRSS=0
		DCRAB_MEM_VMSIZE=0
		DCRAB_MEM_MAX_VMRSS=0
		DCRAB_MEM_MAX_VMSIZE=0
		DCRAB_MEM1_BASELINE=$(grep -n -m 1 "var mem1_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_MEM1_L1=$((DCRAB_MEM1_BASELINE + 2))
		DCRAB_MEM2_BASELINE=$(grep -n -m 1 "var mem2_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_MEM2_L1=$((DCRAB_MEM2_BASELINE + 2))
		DCRAB_MEM2_L2=$((DCRAB_MEM2_BASELINE + 3))
		DCRAB_MEM2_UNUSED=0
		DCRAB_MEM2_USED=0
		# Total pie chart
		if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ] && [ "$DCRAB_NNODES" -gt 1 ]; then
			DCRAB_MEM_TOTAL_BASELINE=$(grep -n -m 1 "var total_mem" $DCRAB_HTML | cut -f1 -d:)
			DCRAB_MEM_TOTAL_L1=$((DCRAB_MEM_TOTAL_BASELINE + 2))
			DCRAB_MEM_TOTAL_L2=$((DCRAB_MEM_TOTAL_BASELINE + 3))
		
			DCRAB_MEM_TOTAL_TEXT_BASELINE=$(grep -n -m 1 "id='plot_total_mem'" $DCRAB_HTML | cut -f1 -d:)
			DCRAB_MEM_TOTAL_TEXT_L1=$((DCRAB_MEM_TOTAL_TEXT_BASELINE + 4))
			DCRAB_MEM_TOTAL_TEXT_L2=$((DCRAB_MEM_TOTAL_TEXT_BASELINE + 5))
			DCRAB_MEM_TOTAL_TEXT_L3=$((DCRAB_MEM_TOTAL_TEXT_BASELINE + 6))
		
			DCRAB_MEM_TOTAL_COLOR_BASELINE=$(grep -n -m 1 "var total_mem_options" $DCRAB_HTML | cut -f1 -d:)
			DCRAB_MEM_TOTAL_COLOR_BASELINE=$((DCRAB_MEM_TOTAL_COLOR_BASELINE + 4))
	
			DCRAB_MEM_TOTAL_MAX_VMSIZE=0
			DCRAB_MEM_TOTAL_MAX_VMRSS=0
			DCRAB_MEM_TOTAL_VMSIZE=0
			DCRAB_MEM_TOTAL_VMRSS=0
			DCRAB_MEM_TOTAL_EXCEEDED=0
			DCRAB_MEM_TOTAL_CHANGED=0
			DCRAB_MEM_TOTAL_UNUSED=0
			DCRAB_MEM_TOTAL_USED=0
		fi
		# Pie table text
		DCRAB_MEM3_BASELINE=$(grep -n -m 1 "id='plot1_mem_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_MEM3_L1=$((DCRAB_MEM3_BASELINE + 4))
		DCRAB_MEM3_L2=$((DCRAB_MEM3_BASELINE + 5))
		DCRAB_MEM3_L3=$((DCRAB_MEM3_BASELINE + 6))
		DCRAB_MEM3_L4=$((DCRAB_MEM3_BASELINE + 7))
	
		# IB
		DCRAB_IB_DATA=""
		DCRAB_IB_BASELINE=$(grep -n -m 1 "var ib_data_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_IB_L1=$((DCRAB_IB_BASELINE + 2))
		DCRAB_IB_FIRST_XMIT_DATA_VALUE=$(cat $DCRAB_IB_XMIT_DATA)
		DCRAB_IB_FIRST_RCV_DATA_VALUE=$(cat $DCRAB_IB_RCV_DATA)
		DCRAB_IB_XMIT_PCK_VALUE=$(cat $DCRAB_IB_XMIT_PACK)
		DCRAB_IB_XMIT_DATA_VALUE=$DCRAB_IB_FIRST_XMIT_DATA_VALUE
		DCRAB_IB_RCV_PCK_VALUE=$(cat $DCRAB_IB_RCV_PACK)
		DCRAB_IB_RCV_DATA_VALUE=$DCRAB_IB_FIRST_RCV_DATA_VALUE
		[ $(echo "${DCRAB_IB_FIRST_XMIT_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_FIRST_XMIT_DATA_VALUE=$((DCRAB_IB_FIRST_XMIT_DATA_VALUE + 1)) && DCRAB_IB_XMIT_DATA_VALUE=$((DCRAB_IB_XMIT_DATA_VALUE + 1))
	        [ $(echo "${DCRAB_IB_FIRST_RCV_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_FIRST_RCV_DATA_VALUE=$((DCRAB_IB_FIRST_RCV_DATA_VALUE + 1)) && DCRAB_IB_RCV_DATA_VALUE=$((DCRAB_IB_RCV_DATA_VALUE + 1))
		DCRAB_IB_NEW_XMIT_PCK_VALUE=0
		DCRAB_IB_NEW_XMIT_DATA_VALUE=0
		DCRAB_IB_NEW_RCV_PCK_VALUE=0
		DCRAB_IB_NEW_RCV_DATA_VALUE=0
	
		# TIME
		DCRAB_TIME_BASELINE=$(grep -n -m 1 "var time_data" $DCRAB_HTML | cut -d':' -f1)
		DCRAB_TIME_L1=$((DCRAB_TIME_BASELINE + 2))
		DCRAB_TIME_L2=$((DCRAB_TIME_BASELINE + 3))
		DCRAB_TIME_TEXT_BASELINE=$(grep -n -m 1 "Elapsed Time (DD:HH:MM:SS)" $DCRAB_HTML | cut -d':' -f1)
		DCRAB_TIME_TEXT_L1=$((DCRAB_TIME_TEXT_BASELINE + 1))
		DCRAB_TIME_TEXT_L2=$((DCRAB_TIME_TEXT_BASELINE + 3)) 
		DCRAB_ELAPSED_TIME_TEXT="00:00:00:00"	
		# Time format 	
		local h=$(echo "$DCRAB_REQ_CPUT" | cut -d':' -f1)
		local m=$(echo "$DCRAB_REQ_CPUT" | cut -d':' -f2)
		local s=$(echo "$DCRAB_REQ_CPUT" | cut -d':' -f3)
		DCRAB_TIME_REQ_SECONDS=$(((h * 3600) + (m * 60) + s))
		DCRAB_REQ_TIME_PER_NODE=$(echo "$DCRAB_TIME_REQ_SECONDS / ($DCRAB_REQ_PPN * $DCRAB_NNODES)" | bc)
		local time_req_per_node=$DCRAB_REQ_TIME_PER_NODE
		time_req_per_node=${time_req_per_node%.*}
		local d=$((time_req_per_node / 86400 ))
		[[ "$d" -gt 9 ]] && DCRAB_REQ_TIME="$d" || DCRAB_REQ_TIME="0$d"
		time_req_per_node=$((time_req_per_node - (d * 86400) ))
		local h=$((time_req_per_node / 3600))
		[[ "$h" -gt 9 ]] && DCRAB_REQ_TIME="$DCRAB_REQ_TIME:$h" || DCRAB_REQ_TIME="$DCRAB_REQ_TIME:0$h"
		time_req_per_node=$((time_req_per_node - (h * 3600) ))
		local m=$((time_req_per_node / 60))
		[[ "$m" -gt 9 ]] && DCRAB_REQ_TIME="$DCRAB_REQ_TIME:$m" || DCRAB_REQ_TIME="$DCRAB_REQ_TIME:0$m"
		time_req_per_node=$((time_req_per_node - (m * 60) ))
		[[ "$time_req_per_node" -gt 9 ]] && DCRAB_REQ_TIME="$DCRAB_REQ_TIME:$time_req_per_node" || DCRAB_REQ_TIME="$DCRAB_REQ_TIME:0$time_req_per_node"

		# PROCESSES_IO
		DCRAB_PROCESSESIO_DATA=""
		DCRAB_PROCESSESIO_TOTAL_READ=0
		DCRAB_PROCESSESIO_TOTAL_WRITE=0
		DCRAB_PROCESSESIO_PARTIAL_READ=0
		DCRAB_PROCESSESIO_PARTIAL_WRITE=0
		DCRAB_PROCESSESIO_TOTAL_READ_REDUCED=0
		DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED=0
		DCRAB_PROCESSESIO_TOTAL_READ_STRING="MB"
		DCRAB_PROCESSESIO_TOTAL_WRITE_STRING="MB"
		DCRAB_PROCESSESIO_TOTAL_LAST_READ_STRING="MB"
		DCRAB_PROCESSESIO_TOTAL_LAST_WRITE_STRING="MB"
		DCRAB_PROCESSESIO_BASELINE=$(grep -n -m 1 "var processesIO_data_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_PROCESSESIO_L1=$((DCRAB_PROCESSESIO_BASELINE + 2))
		DCRAB_PROCESSESIO_TEXT_BASELINE=$(grep -n -m 1 "id='plot_processesIO_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_PROCESSESIO_TEXT_L1=$((DCRAB_PROCESSESIO_TEXT_BASELINE + 5))
		DCRAB_PROCESSESIO_TEXT_L2=$((DCRAB_PROCESSESIO_TEXT_BASELINE + 7))

		# NFS
		DCRAB_NFS_DATA=""
		DCRAB_NFS_MOUNT_PATH="/home"
		DCRAB_NFS_BASELINE=$(grep -n -m 1 "var nfs_data_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_NFS_L1=$((DCRAB_NFS_BASELINE + 2))
		DCRAB_NFS_TEXT_BASELINE=$(grep -n -m 1 "id='plot_nfs_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_NFS_TEXT_L1=$((DCRAB_NFS_TEXT_BASELINE + 5))
		DCRAB_NFS_TEXT_L2=$((DCRAB_NFS_TEXT_BASELINE + 7))
		DCRAB_NFS_READ=$(/usr/sbin/mountstats --nfs $DCRAB_NFS_MOUNT_PATH | grep "applications read" | grep "via read(2)" | awk '{print $3}')
		DCRAB_NFS_WRITE=$(/usr/sbin/mountstats --nfs $DCRAB_NFS_MOUNT_PATH | grep "applications wrote" | grep "via write(2)" | awk '{print $3}')
		DCRAB_NFS_NEW_READ=0
		DCRAB_NFS_NEW_WRITE=0
		DCRAB_NFS_TOTAL_READ=0	
		DCRAB_NFS_TOTAL_WRITE=0	
		DCRAB_NFS_TOTAL_READ_REDUCED=0
		DCRAB_NFS_TOTAL_WRITE_REDUCED=0
		DCRAB_NFS_TOTAL_READ_STRING="MB"
		DCRAB_NFS_TOTAL_WRITE_STRING="MB"
		DCRAB_NFS_TOTAL_LAST_READ_STRING="MB"
		DCRAB_NFS_TOTAL_LAST_WRITE_STRING="MB"

		# DISK
		IFS=$'\n'
		DCRAB_DISK_DATA=""
		DCRAB_DISK_CONT=0
		DCRAB_DISK_BASELINE=$(grep -n -m 1 "var disk_data_$DCRAB_NODE_HOSTNAME_MOD" $DCRAB_HTML | cut -f1 -d:)
		DCRAB_DISK_L1=$((DCRAB_DISK_BASELINE + 2))
		# Obtain disk devices
		for line in $(lsblk | grep -v "─" | grep "sd"); do
			DCRAB_DISK_CONT=$((DCRAB_DISK_CONT + 1))
			DCRAB_DISK_NAMES[$DCRAB_DISK_CONT]=$(echo "$line" | awk '{print $1}')
		done
		# Initialize the first values of the disk
		for line in $(cat /proc/diskstats); do
			local aux_device=$(echo "$line" | awk '{print $3}')
			found=0
			i=0
			while [ "$i" -le "$DCRAB_DISK_CONT" ]; do
				i=$((i+1))
				if [ "${DCRAB_DISK_NAMES[$i]}" == "$aux_device" ]; then
					found=1
					break
				fi
			done
			if [ "$found" -eq 1 ];then
				# The information obtained are the sectors read so we must multiply it by 512 to obtain the bytes
				DCRAB_DISK_FIRST_READ_VALUE[$i]=$(echo "$line" | awk '{print $6}')
				DCRAB_DISK_FIRST_WRITE_VALUE[$i]=$(echo "$line" | awk '{print $10}')
			fi
		done


		#####################
                ## NEW MODULE CODE ##
                #####################
			
	else	
		# Files and directories
		if [ -d "/sys/class/infiniband/mlx5_0/ports/1/counters_ext/" ]; then
                        DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx5_0/ports/1/counters_ext
                        DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets_64
                        DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data_64
                        DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets_64
                        DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data_64
                elif [ -d "/sys/class/infiniband/mlx5_0/ports/1/counters/" ]; then
                        DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx5_0/ports/1/counters
                        DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets
                        DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data
                        DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets
                        DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data
                elif [ -d "/sys/class/infiniband/mlx4_0/ports/1/counters/" ]; then
                        DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx4_0/ports/1/counters
                        DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets
                        DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data
                        DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets
                        DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data
                else
                        DCRAB_IB_BASE_DIR=/sys/class/infiniband/mlx4_0/ports/1/counters_ext
                        DCRAB_IB_XMIT_PACK=$DCRAB_IB_BASE_DIR/port_xmit_packets_64
                        DCRAB_IB_XMIT_DATA=$DCRAB_IB_BASE_DIR/port_xmit_data_64
                        DCRAB_IB_RCV_PACK=$DCRAB_IB_BASE_DIR/port_rcv_packets_64
                        DCRAB_IB_RCV_DATA=$DCRAB_IB_BASE_DIR/port_rcv_data_64
                fi
		DCRAB_TOTAL_IB_DIR=$DCRAB_REPORT_DIR/aux/ib
                DCRAB_TOTAL_IB_FILE=$DCRAB_TOTAL_IB_DIR/$DCRAB_NODE_HOSTNAME.txt
                echo "" > $DCRAB_TOTAL_IB_FILE
		DCRAB_TOTAL_DISK_DIR=$DCRAB_REPORT_DIR/aux/ldisk
                DCRAB_TOTAL_DISK_FILE=$DCRAB_TOTAL_DISK_DIR/$DCRAB_NODE_HOSTNAME.txt
                echo "" > $DCRAB_TOTAL_DISK_FILE
	
		# CPU
		DCRAB_CPU_THRESHOLD="5.0"

		# IB
                DCRAB_IB_FIRST_XMIT_DATA_VALUE=$(cat $DCRAB_IB_XMIT_DATA)
                DCRAB_IB_FIRST_RCV_DATA_VALUE=$(cat $DCRAB_IB_RCV_DATA)
		[ $(echo "${DCRAB_IB_FIRST_XMIT_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_FIRST_XMIT_DATA_VALUE=$((DCRAB_IB_FIRST_XMIT_DATA_VALUE + 1))
	        [ $(echo "${DCRAB_IB_FIRST_RCV_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_FIRST_RCV_DATA_VALUE=$((DCRAB_IB_FIRST_RCV_DATA_VALUE + 1))
                DCRAB_IB_NEW_XMIT_PCK_VALUE=0
                DCRAB_IB_NEW_XMIT_DATA_VALUE=0
                DCRAB_IB_NEW_RCV_PCK_VALUE=0
                DCRAB_IB_NEW_RCV_DATA_VALUE=0

		# DISK
                IFS=$'\n'
                DCRAB_DISK_CONT=0
                # Obtain disk devices
                for line in $(lsblk | grep -v "─" | grep "sd"); do
                        DCRAB_DISK_CONT=$((DCRAB_DISK_CONT + 1))
                        DCRAB_DISK_NAMES[$DCRAB_DISK_CONT]=$(echo "$line" | awk '{print $1}')
                done
                # Initialize the first values of the disk
                for line in $(cat /proc/diskstats); do
                        local aux_device=$(echo "$line" | awk '{print $3}')
                        found=0
                        i=0
                        while [ "$i" -le "$DCRAB_DISK_CONT" ]; do
                                i=$((i+1))
                                if [ "${DCRAB_DISK_NAMES[$i]}" == "$aux_device" ]; then
                                        found=1
                                        break
                                fi
                        done
                        if [ "$found" -eq 1 ];then
                                # The information obtained are the sectors read so we must multiply it by 512 to obtain the bytes
                                DCRAB_DISK_FIRST_READ_VALUE[$i]=$(echo "$line" | awk '{print $6}')
                                DCRAB_DISK_FIRST_WRITE_VALUE[$i]=$(echo "$line" | awk '{print $10}')
                        fi
                done
	fi

	# Initializes variables for the internal report 
        dcrab_internal_report_init_variables
}


#
# Collects memory data 
#
dcrab_collect_mem_data () {

	# Store the data of all the processes 
	:> $DCRAB_MEM_FILE
	for pid in $(cat $DCRAB_JOB_PROCESSES_FILE | awk '{print $1}'); do cat /proc/$pid/status 2> /dev/null 1 >> $DCRAB_MEM_FILE; done

	# Collect memory data of the file
   	DCRAB_MEM_VMSIZE=$(grep VmSize $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}') 
	DCRAB_MEM_VMSIZE=$(printf "%.3f\n" "$DCRAB_MEM_VMSIZE") # 3 decimals only
	DCRAB_MEM_VMRSS=$(grep VmRSS $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}')
	DCRAB_MEM_VMRSS=$(printf "%.3f\n" "$DCRAB_MEM_VMRSS") # 3 decimals only
	if [ $(echo "$DCRAB_MEM_VMRSS > $DCRAB_MEM_MAX_VMRSS" | bc) -eq 1 ]; then
		DCRAB_MEM_MAX_VMRSS=$DCRAB_MEM_VMRSS
	fi
	if [ $(echo "$DCRAB_MEM_VMSIZE > $DCRAB_MEM_MAX_VMSIZE" | bc) -eq 1 ]; then
		DCRAB_MEM_MAX_VMSIZE=$DCRAB_MEM_VMSIZE
	fi

	# Check if exceeds memory requested. The job may be killed by the scheduler.
	if [ $(echo "$DCRAB_MEM_MAX_VMRSS < $DCRAB_REQ_MEM" | bc) -eq 1 ]; then
		DCRAB_MEM2_USED=`echo "scale=3; ($DCRAB_MEM_MAX_VMRSS * 100)/$DCRAB_REQ_MEM" | bc `
		DCRAB_MEM2_UNUSED=`echo "scale=3; 100 - $DCRAB_MEM2_USED" | bc `
	else    
		DCRAB_MEM2_UNUSED=0
		DCRAB_MEM2_USED=100
	fi

	if [ "$DCRAB_NNODES" -gt 1 ]; then
		if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
			DCRAB_MEM_TOTAL_VMRSS=0
			DCRAB_MEM_TOTAL_VMSIZE=0
			
			echo "$DCRAB_MEM_MAX_VMRSS $DCRAB_MEM_MAX_VMSIZE" > $DCRAB_TOTAL_MEM_FILE
			
			for file in $DCRAB_TOTAL_MEM_DIR/*
			do
				DCRAB_MEM_TOTAL_VMRSS=$(echo "$DCRAB_MEM_TOTAL_VMRSS + $(cat $file | awk '{print $1}')" | bc)
				DCRAB_MEM_TOTAL_VMSIZE=$(echo "$DCRAB_MEM_TOTAL_VMSIZE + $(cat $file | awk '{print $2}')" | bc)
			done
			# DCRAB_MEM_TOTAL_VMRSS=$(cat $DCRAB_TOTAL_MEM_FILE | awk '{print $1}')
			# DCRAB_MEM_TOTAL_VMSIZE=$(cat $DCRAB_TOTAL_MEM_FILE | awk '{print $2}')
		
			if [ $(echo "$DCRAB_MEM_TOTAL_VMSIZE > $DCRAB_MEM_TOTAL_MAX_VMSIZE" | bc) -eq 1 ]; then
				DCRAB_MEM_TOTAL_MAX_VMSIZE=$DCRAB_MEM_TOTAL_VMSIZE
			fi
			if [ $(echo "$DCRAB_MEM_TOTAL_VMRSS > $DCRAB_MEM_TOTAL_MAX_VMRSS" | bc) -eq 1 ]; then
				DCRAB_MEM_TOTAL_MAX_VMRSS=$DCRAB_MEM_TOTAL_VMRSS
			fi	
			
			if [ $(echo "$DCRAB_MEM_TOTAL_MAX_VMRSS < $DCRAB_REQ_MEM" | bc) -eq 1 ]; then
				DCRAB_MEM_TOTAL_USED=`echo "scale=3; ($DCRAB_MEM_TOTAL_MAX_VMRSS * 100)/$DCRAB_REQ_MEM" | bc `
				DCRAB_MEM_TOTAL_UNUSED=`echo "scale=3; 100 - $DCRAB_MEM_TOTAL_USED" | bc `
			else
				DCRAB_MEM_TOTAL_USED=100
				DCRAB_MEM_TOTAL_UNUSED=0
				DCRAB_MEM_TOTAL_EXCEEDED=1		
			fi
			
		else
			echo "$DCRAB_MEM_MAX_VMRSS $DCRAB_MEM_MAX_VMSIZE" > $DCRAB_TOTAL_MEM_FILE
		fi
	fi

	# Construct mem data string
	DCRAB_MEM_DATA="$DCRAB_MEM_DATA""$DCRAB_NODE_TOTAL_MEM, $DCRAB_REQ_MEM, $DCRAB_MEM_MAX_VMRSS, $DCRAB_MEM_VMSIZE, $DCRAB_MEM_VMRSS ],"
}


#
# Collects Infiniband statistics of the node 
#
dcrab_collect_ib_data () {

	DCRAB_IB_NEW_XMIT_PCK_VALUE=$(cat $DCRAB_IB_XMIT_PACK)
	DCRAB_IB_NEW_RCV_PCK_VALUE=$(cat $DCRAB_IB_RCV_PACK)	
	DCRAB_IB_NEW_XMIT_DATA_VALUE=$(cat $DCRAB_IB_XMIT_DATA)
	DCRAB_IB_NEW_RCV_DATA_VALUE=$(cat $DCRAB_IB_RCV_DATA)
	[ $(echo "${DCRAB_IB_NEW_XMIT_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_NEW_XMIT_DATA_VALUE=$((DCRAB_IB_NEW_XMIT_DATA_VALUE + 1))
	[ $(echo "${DCRAB_IB_NEW_RCV_DATA_VALUE: -1} % 2" | bc) -eq 1 ] && DCRAB_IB_NEW_RCV_DATA_VALUE=$((DCRAB_IB_NEW_RCV_DATA_VALUE + 1))

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		local aux1=$( echo "($DCRAB_IB_NEW_XMIT_DATA_VALUE - $DCRAB_IB_XMIT_DATA_VALUE) / 1024" | bc )
		local aux2=$( echo "($DCRAB_IB_NEW_RCV_DATA_VALUE - $DCRAB_IB_RCV_DATA_VALUE) / 1024" | bc )
	
		# Construct ib data
		DCRAB_IB_DATA="$DCRAB_IB_DATA"" $((DCRAB_IB_NEW_XMIT_PCK_VALUE - DCRAB_IB_XMIT_PCK_VALUE)), $((DCRAB_IB_NEW_RCV_PCK_VALUE - DCRAB_IB_RCV_PCK_VALUE)), $aux1, $aux2 ],"
	
		DCRAB_IB_XMIT_PCK_VALUE=$DCRAB_IB_NEW_XMIT_PCK_VALUE
		DCRAB_IB_XMIT_DATA_VALUE=$DCRAB_IB_NEW_XMIT_DATA_VALUE
		DCRAB_IB_RCV_PCK_VALUE=$DCRAB_IB_NEW_RCV_PCK_VALUE
		DCRAB_IB_RCV_DATA_VALUE=$DCRAB_IB_NEW_RCV_DATA_VALUE
	fi

	# Internal report
	local aux3=$(( (DCRAB_IB_NEW_XMIT_DATA_VALUE - DCRAB_IB_FIRST_XMIT_DATA_VALUE) + (DCRAB_IB_NEW_RCV_DATA_VALUE - DCRAB_IB_FIRST_RCV_DATA_VALUE) ))	
	sed -i 1's|.*|'"$aux3"'|' $DCRAB_TOTAL_IB_FILE
}


#
# Collects the time elapsed of the job and formats it 
#
dcrab_format_time () {
	
	DCRAB_ELAPSED_TIME_TEXT=""
	local timeStamp=$DCRAB_DIFF_TIMESTAMP
	local d=$((timeStamp / 86400))
	[[ "$d" -gt 9 ]] && DCRAB_ELAPSED_TIME_TEXT="$d" || DCRAB_ELAPSED_TIME_TEXT="0$d"
	timeStamp=$((timeStamp - (d * 86400) ))
	local h=$((timeStamp / 3600))
	[[ "$h" -gt 9 ]] && DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:$h" || DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:0$h"
	timeStamp=$((timeStamp - (h * 3600) ))
	local m=$((timeStamp / 60))
	[[ "$m" -gt 9 ]] && DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:$m" || DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:0$m"
	timeStamp=$((timeStamp - (m * 60) ))
	[[ "$timeStamp" -gt 9 ]] && DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:$timeStamp" || DCRAB_ELAPSED_TIME_TEXT="$DCRAB_ELAPSED_TIME_TEXT:0$timeStamp"

	if [ $(echo "$DCRAB_DIFF_TIMESTAMP < $DCRAB_REQ_TIME_PER_NODE" | bc) -eq 1 ]; then
		DCRAB_ELAPSED_TIME_VALUE=$(echo "scale=3; ($DCRAB_DIFF_TIMESTAMP * 100 ) / $DCRAB_REQ_TIME_PER_NODE " | bc)	
		DCRAB_REMAINING_TIME_VALUE=$(echo "scale=3; 100 - $DCRAB_ELAPSED_TIME_VALUE" | bc)
	else
		DCRAB_ELAPSED_TIME_VALUE=100
		DCRAB_REMAINING_TIME_VALUE=0
	fi
}


#
# Collects the IO made by the processes involved in the execution
#
dcrab_collect_processesIO_data () {

	#
	# 0 - The firts loop ; 1 - Other loops
	#	
	case $1 in 
	0)
		# Store the data of all the processes	 
		for line in $(cat $DCRAB_JOB_PROCESSES_FILE); do

			pid=$(echo "$line" | awk '{print $1}')
			
			# Collect processesIO actual data
			if [ -r /proc/$pid/io ]; then
				new_rchar=$(cat /proc/$pid/io | grep rchar | awk '{print $2}')
				new_wchar=$(cat /proc/$pid/io | grep wchar | awk '{print $2}')
				[[ "$new_rchar" == "" ]] && new_rchar=0
				[[ "$new_wchar" == "" ]] && new_wchar=0	
	
				DCRAB_PROCESSESIO_TOTAL_READ=$new_rchar
				DCRAB_PROCESSESIO_TOTAL_WRITE=$new_wchar
			fi
		done
	
		if [ ! -f $DCRAB_PROCESSES_IO_FILE ]; then
			:> $DCRAB_PROCESSES_IO_FILE
		fi		
	
		# Construct data fot the plot
		DCRAB_PROCESSESIO_DATA="$DCRAB_PROCESSESIO_DATA""0, 0],"
	;;
	1)
		DCRAB_PROCESSESIO_PARTIAL_READ=0
		DCRAB_PROCESSESIO_PARTIAL_WRITE=0
		last_rchar=""
		last_wchar=""
		for line in $(cat $DCRAB_JOB_PROCESSES_FILE); do
	
			pid=$(echo "$line" | awk '{print $1}')	
			
			# Collect processesIO last data
			last_rchar=$(cat $DCRAB_PROCESSES_IO_FILE | grep "^$pid " | awk '{print $2}')
			last_wchar=$(cat $DCRAB_PROCESSES_IO_FILE | grep "^$pid " | awk '{print $3}')

			# Collect processesIO actual data
			if [ -r /proc/$pid/io ]; then
				new_rchar=$(cat /proc/$pid/io | grep rchar | awk '{print $2}')
				new_wchar=$(cat /proc/$pid/io | grep wchar | awk '{print $2}')
				[[ "$new_rchar" == "" ]] && new_rchar=0
				[[ "$new_wchar" == "" ]] && new_wchar=0

				if [ "$last_rchar" == "" ]; then
					echo "$pid $new_rchar $new_wchar" >> $DCRAB_PROCESSES_IO_FILE 
				
					DCRAB_PROCESSESIO_TOTAL_READ=$(echo "$DCRAB_PROCESSESIO_TOTAL_READ + $new_rchar" | bc)
					DCRAB_PROCESSESIO_PARTIAL_READ=$(echo "$DCRAB_PROCESSESIO_PARTIAL_READ + $new_rchar" | bc)
	
					DCRAB_PROCESSESIO_TOTAL_WRITE=$(echo "$DCRAB_PROCESSESIO_TOTAL_WRITE + $new_wchar" | bc )
					DCRAB_PROCESSESIO_PARTIAL_WRITE=$(echo "$DCRAB_PROCESSESIO_PARTIAL_WRITE + $new_wchar" | bc )				
				else
					lineNumber=$(cat $DCRAB_PROCESSES_IO_FILE | grep -n "^$pid " | awk '{print $1}' | cut -d':' -f1)
					sed -i "$lineNumber"'s/'"$pid $last_rchar $last_wchar"'/'"$pid $new_rchar $new_wchar"'/' $DCRAB_PROCESSES_IO_FILE
	
					DCRAB_PROCESSESIO_TOTAL_READ=$(echo "$DCRAB_PROCESSESIO_TOTAL_READ + $new_rchar - $last_rchar"  | bc)
					DCRAB_PROCESSESIO_PARTIAL_READ=$(echo "$DCRAB_PROCESSESIO_PARTIAL_READ + $new_rchar - $last_rchar" | bc)
	
					DCRAB_PROCESSESIO_TOTAL_WRITE=$(echo "$DCRAB_PROCESSESIO_TOTAL_WRITE + $new_wchar - $last_wchar" | bc)
					DCRAB_PROCESSESIO_PARTIAL_WRITE=$(echo "$DCRAB_PROCESSESIO_PARTIAL_WRITE + $new_wchar - $last_wchar" | bc)
				fi
			fi
		done

		local aux1=$( echo "scale=3; (($DCRAB_PROCESSESIO_PARTIAL_READ / 1024) / 1024) / $DCRAB_DIFF_PARTIAL"  | bc )
		local aux2=$( echo "scale=3; (($DCRAB_PROCESSESIO_PARTIAL_WRITE / 1024) / 1024) / $DCRAB_DIFF_PARTIAL"  | bc )
	
		# Construct data for the plot
		DCRAB_PROCESSESIO_DATA="$DCRAB_PROCESSESIO_DATA"" $aux1, $aux2 ],"
	
		# Construct data for the read text value
		DCRAB_PROCESSESIO_TOTAL_LAST_READ_STRING=$DCRAB_PROCESSESIO_TOTAL_READ_STRING
		case $DCRAB_PROCESSESIO_TOTAL_READ_STRING in 
		"MB")
			DCRAB_PROCESSESIO_TOTAL_READ_REDUCED=$(echo "scale=4; ($DCRAB_PROCESSESIO_TOTAL_READ /1024) /1024" | bc)
			if [ $(echo "$DCRAB_PROCESSESIO_TOTAL_READ_REDUCED >= 1024" | bc)  -eq 1 ]; then
				DCRAB_PROCESSESIO_TOTAL_READ_REDUCED=$(echo "scale=4; $DCRAB_PROCESSESIO_TOTAL_READ_REDUCED / 1024 " | bc )
				DCRAB_PROCESSESIO_TOTAL_READ_STRING="GB"
			fi
			[[ "${DCRAB_PROCESSESIO_TOTAL_READ_REDUCED:0:1}" == "." ]] && DCRAB_PROCESSESIO_TOTAL_READ_REDUCED="0""$DCRAB_PROCESSESIO_TOTAL_READ_REDUCED"
		;;
		"GB")
			DCRAB_PROCESSESIO_TOTAL_READ_REDUCED=$(echo "scale=4; (($DCRAB_PROCESSESIO_TOTAL_READ /1024) /1024 ) /1024" | bc)
		;;
		esac
		# Construct data for the write text value
		DCRAB_PROCESSESIO_TOTAL_LAST_WRITE_STRING=$DCRAB_PROCESSESIO_TOTAL_WRITE_STRING
		case $DCRAB_PROCESSESIO_TOTAL_WRITE_STRING in
		"MB")
			DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED=$(echo "scale=4; ($DCRAB_PROCESSESIO_TOTAL_WRITE /1024) /1024" | bc)
			if [ $(echo "$DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED >= 1024" | bc)  -eq 1 ]; then
				DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED=$(echo "scale=4; $DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED / 1024 " | bc )
				DCRAB_PROCESSESIO_TOTAL_WRITE_STRING="GB"
			fi
			[[ "${DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED:0:1}" == "." ]] && DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED="0""$DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED"
		;;
		"GB")
			DCRAB_PROCESSESIO_TOTAL_WRITE_REDUCED=$(echo "scale=4; (($DCRAB_PROCESSESIO_TOTAL_WRITE /1024) /1024 ) /1024" | bc)
		;;
		esac
	;;
	esac
}


#
# Collects the NFS IO made by the node 
#
dcrab_collect_nfs_data () {

	DCRAB_NFS_NEW_READ=$(/usr/sbin/mountstats --nfs $DCRAB_NFS_MOUNT_PATH | grep "applications read" | grep "via read(2)" | awk '{print $3}' )
	DCRAB_NFS_NEW_WRITE=$(/usr/sbin/mountstats --nfs $DCRAB_NFS_MOUNT_PATH | grep "applications wrote" | grep "via write(2)" | awk '{print $3}' )
	DCRAB_NFS_TOTAL_READ=$((DCRAB_NFS_TOTAL_READ + DCRAB_NFS_NEW_READ - DCRAB_NFS_READ))
	DCRAB_NFS_TOTAL_WRITE=$((DCRAB_NFS_TOTAL_WRITE + DCRAB_NFS_NEW_WRITE - DCRAB_NFS_WRITE))

	# Construct data for the read text value
	DCRAB_NFS_TOTAL_LAST_READ_STRING=$DCRAB_NFS_TOTAL_READ_STRING
	case $DCRAB_NFS_TOTAL_READ_STRING in
	"MB")
		DCRAB_NFS_TOTAL_READ_REDUCED=$(echo "scale=4; ($DCRAB_NFS_TOTAL_READ / 1024) / 1024" | bc)
		if [ $(echo "$DCRAB_NFS_TOTAL_READ_REDUCED >= 1024" | bc)  -eq 1 ]; then
			DCRAB_NFS_TOTAL_READ_REDUCED=$(echo "scale=4; $DCRAB_NFS_TOTAL_READ_REDUCED / 1024 " | bc )
			DCRAB_NFS_TOTAL_READ_STRING="GB"
		fi
	;;
	"GB")
		DCRAB_NFS_TOTAL_READ_REDUCED=$(echo "scale=4; (($DCRAB_NFS_TOTAL_READ /1024) /1024 ) /1024" | bc)
	;;
	esac

	# Construct data for the write text value
	DCRAB_NFS_TOTAL_LAST_WRITE_STRING=$DCRAB_NFS_TOTAL_WRITE_STRING
	case $DCRAB_NFS_TOTAL_WRITE_STRING in
	"MB")
		DCRAB_NFS_TOTAL_WRITE_REDUCED=$(echo "scale=4; ($DCRAB_NFS_TOTAL_WRITE /1024) /1024" | bc)
		if [ $(echo "$DCRAB_NFS_TOTAL_WRITE_REDUCED >= 1024" | bc)  -eq 1 ]; then
			DCRAB_NFS_TOTAL_WRITE_REDUCED=$(echo "scale=4; $DCRAB_NFS_TOTAL_WRITE_REDUCED / 1024 " | bc )
			DCRAB_NFS_TOTAL_WRITE_STRING="GB"
		fi
	;;
	"GB")
		DCRAB_NFS_TOTAL_WRITE_REDUCED=$(echo "scale=4; (($DCRAB_NFS_TOTAL_WRITE /1024) /1024 ) /1024" | bc)
	;;
	esac

	local aux1=$(echo "scale=4; ((($DCRAB_NFS_NEW_READ - $DCRAB_NFS_READ) / 1024 ) / 1024 ) / $DCRAB_DIFF_PARTIAL" | bc)
	local aux2=$(echo "scale=4; ((($DCRAB_NFS_NEW_WRITE - $DCRAB_NFS_WRITE) / 1024 ) / 1024 ) / $DCRAB_DIFF_PARTIAL" | bc)

	# Construct NFS data
	DCRAB_NFS_DATA="$DCRAB_NFS_DATA""$aux1, $aux2],"
		
	DCRAB_NFS_READ=$DCRAB_NFS_NEW_READ
	DCRAB_NFS_WRITE=$DCRAB_NFS_NEW_WRITE
}


#
# Collects IO made in the node disks
#
dcrab_collect_disk_data () {

	local aux3=0
	# Collect IO disk stats
	while read line; do
		aux_device=$(echo "$line" | awk '{print $3}')	
		found=0
		i=0
		while [ "$i" -le "$DCRAB_DISK_CONT" ]; do
			i=$((i+1))
			if [ "${DCRAB_DISK_NAMES[$i]}" == "$aux_device" ]; then
				found=1
				break
			fi
		done
		if [ "$found" -eq 1 ]; then
			DCRAB_DISK_READ_VALUE[$i]=$(echo " $(echo "$line" | awk '{print $6}') - ${DCRAB_DISK_FIRST_READ_VALUE[$i]}" | bc)
			DCRAB_DISK_WRITE_VALUE[$i]=$(echo "$(echo "$line" | awk '{print $10}') - ${DCRAB_DISK_FIRST_WRITE_VALUE[$i]}" | bc)
		
			if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then	
				local aux1=$(echo "((${DCRAB_DISK_READ_VALUE[$i]} * 512 )/1024 )/1024" | bc)
				local aux2=$(echo "((${DCRAB_DISK_WRITE_VALUE[$i]} * 512 )/1024 )/1024" | bc)	
				DCRAB_DISK_DATA="$DCRAB_DISK_DATA ['${DCRAB_DISK_NAMES[$i]}', $aux1, $aux2],"
			fi

			# Internal report 
			aux3=$(echo "$aux3 + (${DCRAB_DISK_WRITE_VALUE[$i]} * 512)  + (${DCRAB_DISK_READ_VALUE[$i]} * 512)" | bc)
		fi	
	done < <(cat /proc/diskstats)
		
	sed -i 1's|.*|'"$aux3"'|' $DCRAB_TOTAL_DISK_FILE
}


#
# Collects Beegfs statistics (no created yet)
#
dcrab_collect_beegfs_data () {
	echo " "
}


####################################
## ADD NEW MODULE'S FUNCTION HERE ##
####################################


#
# This function will maintain the processes waiting until the control_port file is generated
#
dcrab_wait_control_port () {

	source $DCRAB_PATH/scripts/dcrab_finalize.sh

	DCRAB_NUMBER_OF_MPI_COMMANDS=$((DCRAB_NUMBER_OF_MPI_COMMANDS + 1))
	DCRAB_CONTROL_PORT_FILE="${DCRAB_CONTROL_PORT_FILE_PREFIX}${DCRAB_NUMBER_OF_MPI_COMMANDS}"
	
        i=1
        # Wait until the main node creates control port file
        eval $DCRAB_LOG_INFO "Waiting until control_port$DCRAB_NUMBER_OF_MPI_COMMANDS file has been created"
        while [ ! -f $DCRAB_CONTROL_PORT_FILE ]; do
        	eval $DCRAB_LOG_INFO "Loop number \($i/$DCRAB_NUMBERS_OF_LOOPS_CONTROL\). No control_port$DCRAB_NUMBER_OF_MPI_COMMANDS file created yet. Waiting a bit more . . . "
                sleep $DCRAB_SLEEP_TIME_CONTROL

                # Exit DCRAB if no control_port file was created and the main node processes have been stopped
                if [ "$i" -eq "$DCRAB_NUMBERS_OF_LOOPS_CONTROL" ]; then
			dcrab_check_alive_main_node			
			
			# If the previous function didn't stop DCRAB we reset the counters to wait more for the next MPI process
			i=0
                fi
                i=$((i + 1))
        done
        eval $DCRAB_LOG_INFO "File control_port$DCRAB_NUMBER_OF_MPI_COMMANDS file created!"

        # Wait until the processes of the job start
        IFS=$'\n'; i=0
        DCRAB_MPI_CONTROL_PORT_MAIN_NODE=$(cat $DCRAB_CONTROL_PORT_FILE)
        while [ "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" != "$DCRAB_MPI_CONTROL_PORT_OTHER_NODE" ]; do
        	eval $DCRAB_LOG_INFO "Waiting until the process in the node $DCRAB_NODE_HOSTNAME starts" 

                i=$((i + 1))

                # Exit DCRAB if no control_port file was created  
                if [ "$i" -eq "$DCRAB_NUMBERS_OF_LOOPS_CONTROL" ]; then
                	eval $DCRAB_LOG_INFO "The process does not start"
			eval $DCRAB_LOG_INFO "DCRAB stop \(3\)"
                	exit 3
                fi

                # Wait if it is not the first loop
                [[ "$i" -gt 1 ]] && sleep $DCRAB_SLEEP_TIME_CONTROL

                for line in $(ps axo stat,euid,sess,pid,comm,command | awk '{if ($2 == '"$DCRAB_USER_ID"'){print}}' | grep "Ss")
                do
	                DCRAB_MPI_CONTROL_PORT_OTHER_NODE=`echo ${line#*control-port} | awk '{print $1}'`

                        # Intel MPI
                        if [ "$DCRAB_MPI_CONTROL_PORT_OTHER_NODE" == "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" ]; then
	                        DCRAB_MAIN_SESSION=$(echo "$line" | awk '{print $3}')
                                DCRAB_FIRST_MAIN_PROCESS_PID=$(echo "$line" | awk '{print $4}')
                                DCRAB_FIRST_MAIN_PROCESS_NAME=$(echo "$line" | awk '{print $5}')
                                break
                        fi

                        # Open MPI
                        echo $line |  awk '{if ($5 == "orted"){print}}' | grep "orted" | grep -q "$(cat $DCRAB_CONTROL_PORT_FILE)"
                        if [ $? -eq 0 ]; then
         	               DCRAB_MPI_CONTROL_PORT_OTHER_NODE=$(cat $DCRAB_CONTROL_PORT_FILE)
                               DCRAB_MAIN_SESSION=$(echo "$line" | awk '{print $3}')
                               DCRAB_FIRST_MAIN_PROCESS_PID=$(echo "$line" | awk '{print $4}')
                               DCRAB_FIRST_MAIN_PROCESS_NAME=$(echo "$line" | awk '{print $5}')
                               break
                        fi
                        done
                done
                eval $DCRAB_LOG_INFO "Processes in node $DCRAB_NODE_HOSTNAME started with '$DCRAB_MPI_CONTROL_PORT_OTHER_NODE' control port"
		
		DCRAB_SLEEP_FOR_NEXT_MPI_JOB=0
		# Indicate the main node that this node has started to monitor the MPI job
	        echo "0" > $DCRAB_WAIT_MPI_PROCESSES_FILE

}


#
# Determines the main processes of the job which will be used to find the rest of the processes involved in the execution (because they will be main processes childs).
# Also initializes the first time the html report.
#
dcrab_determine_main_process () {

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		# CPU
		DCRAB_CPU_DATA="0,"
		# MEM
		DCRAB_MEM_DATA="[0,"	
		# IB
		DCRAB_IB_DATA="[0,"
		# PROCESSES_IO
		DCRAB_PROCESSESIO_DATA="[0,"
		# NFS
		DCRAB_NFS_DATA="[0, 0, 0],"
	
		####################################################
		## ADD INITIALIZATION OF NEW MODULE VARIABLE HERE ##
		####################################################
	fi

	# MAIN NODE
	if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
		IFS=$'\n'
		ps axo euid,sess,pid,comm,command | awk '{if ($1 == '"$DCRAB_USER_ID"'){print}}' | awk '{if ($2 != '"$DCRAB_DCRAB_SESSION"'){print}}' > $DCRAB_USER_PROCESSES_FILE
		for line in $(cat $DCRAB_USER_PROCESSES_FILE)
		do
			echo "$line"  | grep -q "$DCRAB_FULL_JOB_ID"
			if [ "$?" -eq 0 ]; then
				DCRAB_FIRST_MAIN_PROCESS_PID=$(echo "$line" | awk '{print $3}')
				DCRAB_FIRST_MAIN_PROCESS_NAME=$(echo "$line" | awk '{print $4}')
				DCRAB_MAIN_SESSION=$(echo "$line" | awk '{print $2}')				
				break
			fi
		done

	# REST OF NODES
	else
		dcrab_wait_control_port
	fi

	# Initialize data file
	for line in $(ps axo euid,sess,pid,pcpu,comm,command | awk '{if ($1 == '"$DCRAB_USER_ID"'){print}}' | awk '{if ($2 == '"$DCRAB_MAIN_SESSION"'){print}}' | awk '{if ($2 != '"$DCRAB_DCRAB_SESSION"'){print}}')
	do
		pid=$(echo "$line" | awk '{print $3}')
		cpu=$(echo "$line" | awk '{print $4}')
		commandName=$(echo "$line" | awk '{print $5}')

		if [ $(echo "$cpu > $DCRAB_CPU_THRESHOLD" | bc) -eq 1 ]; then

			# Save in the data file
			echo "$pid $commandName" >> $DCRAB_JOB_PROCESSES_FILE
	
			if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then 	
				# CPU data
				DCRAB_CPU_UPD_PROC_NAME[$DCRAB_CPU_UPDATES]=$commandName
				DCRAB_CPU_DATA="$DCRAB_CPU_DATA $cpu,"
	
				DCRAB_CPU_UPDATES=$((DCRAB_CPU_UPDATES + 1))
			fi
		fi

		# If it is the control process the main node must store it. Needed for multinode statistics
		if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
			
			# Intel MPI
			echo $line | grep -q "control-port"
			if [ "$?" -eq 0 ]; then
				DCRAB_NUMBER_OF_MPI_COMMANDS=$((DCRAB_NUMBER_OF_MPI_COMMANDS + 1))
		                DCRAB_CONTROL_PORT_FILE="${DCRAB_CONTROL_PORT_FILE_PREFIX}${DCRAB_NUMBER_OF_MPI_COMMANDS}"
				
		       		DCRAB_MPI_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
				echo "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" > $DCRAB_CONTROL_PORT_FILE
	
				DCRAB_MPI_CONTROL_WRITED=1
				
				echo "$pid" >> $DCRAB_MPI_PROCESSES_FILE	
				
			fi
	
			# Open MPI
			echo $line | grep "mpirun" | grep "\--map-by" | grep -q 'ppr:.*:node' 
			if [ "$?" -eq 0 ]; then
				DCRAB_NUMBER_OF_MPI_COMMANDS=$((DCRAB_NUMBER_OF_MPI_COMMANDS + 1))
		                DCRAB_CONTROL_PORT_FILE="${DCRAB_CONTROL_PORT_FILE_PREFIX}${DCRAB_NUMBER_OF_MPI_COMMANDS}"

				while [ "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" == "" ]; do
                                        DCRAB_MPI_CONTROL_PORT_MAIN_NODE=$(/usr/sbin/lsof -Pan -p $(echo $line | awk '{print $3}') -i | grep "LISTEN" | awk '{print $9}')
                                        DCRAB_MPI_CONTROL_PORT_MAIN_NODE=${DCRAB_MPI_CONTROL_PORT_MAIN_NODE##*:}

	                                [ "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" == "" ] && eval $DCRAB_LOG_INFO "Wait to control port conections to be active" && sleep 1
                                done
				
				echo "tcp://192.168.10.$DCRAB_NODE_NUMBER,10.10.1.$DCRAB_NODE_NUMBER:$DCRAB_MPI_CONTROL_PORT_MAIN_NODE;" > $DCRAB_CONTROL_PORT_FILE 

				DCRAB_MPI_CONTROL_WRITED=1
				DCRAB_MPI_CONTROL_PORT_MAIN_NODE=""
				
				echo "$pid" >> $DCRAB_MPI_PROCESSES_FILE
			fi
		fi
		
	done

	# If the file is empty is because all the processes generated are not still relevant (they are not greater than the threshold value).
	# So we initialize it with a first value 
	if [ ! -f $DCRAB_JOB_PROCESSES_FILE ]; then
		eval $DCRAB_LOG_INFO "Initializing file $DCRAB_JOB_PROCESSES_FILE" 
		echo "$DCRAB_FIRST_MAIN_PROCESS_PID $DCRAB_FIRST_MAIN_PROCESS_NAME" > $DCRAB_JOB_PROCESSES_FILE

		if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
			# CPU data
			DCRAB_CPU_UPD_PROC_NAME[$DCRAB_CPU_UPDATES]=$commandName
			DCRAB_CPU_DATA="$DCRAB_CPU_DATA $cpu,"
	
			DCRAB_CPU_UPDATES=$((DCRAB_CPU_UPDATES + 1))
		fi
	fi	

        DCRAB_M1_TIMESTAMP=`date +"%s"`
	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		DCRAB_M3_TIMESTAMP=$DCRAB_M1_TIMESTAMP
	
		# CPU data. Remove last comma
		DCRAB_CPU_DATA=${DCRAB_CPU_DATA%,*}
		DCRAB_CPU_DATA="[$DCRAB_CPU_DATA ],"
	
		# MEM data
		dcrab_collect_mem_data
	
		# IB data
		dcrab_collect_ib_data
		
		# PROCESSES_IO data
		dcrab_collect_processesIO_data 0
	
		# DISK data
		dcrab_collect_disk_data
	
		###########################################
                ## ADD THE CALL TO THE NEW FUNCTION HERE ##
                ###########################################
	
		# Update the report with the first values 
	        dcrab_update_report
	fi

	# IB data
        dcrab_collect_ib_data
		
	# DISK data
        dcrab_collect_disk_data
	

	# To notice other nodes that the main node is still executing processes
	if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
		DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER=$((DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER + 1))
	        echo "$DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER" > $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE
	fi
}


#
# The main funtion to collect data every loop. Collect different information per process and sometimes of the entire node.
# Also checks if there are new processes involved in the calculation and adds them onto the charts. 
#
dcrab_collect_data () {

	eval $DCRAB_LOG_INFO "Starting data collection"
	
	# Init. variables
	IFS=$'\n'
	DCRAB_M2_TIMESTAMP=`date +"%s"`
        DCRAB_DIFF_TIMESTAMP=$((DCRAB_M2_TIMESTAMP - DCRAB_M1_TIMESTAMP))

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		DCRAB_CPU_UPDATES=0
		DCRAB_DIFF_PARTIAL=$((DCRAB_M2_TIMESTAMP - DCRAB_M3_TIMESTAMP))
		DCRAB_M3_TIMESTAMP=$DCRAB_M2_TIMESTAMP

		# CPU data      
		DCRAB_CPU_DATA="$DCRAB_DIFF_TIMESTAMP,"
		# MEM data
		DCRAB_MEM_DATA="[$DCRAB_DIFF_TIMESTAMP,"
		# IB data
		DCRAB_IB_DATA="[$DCRAB_DIFF_TIMESTAMP,"
		# PROCESSES_IO data
		DCRAB_PROCESSESIO_DATA="[$DCRAB_DIFF_TIMESTAMP,"
		# NFS data
		DCRAB_NFS_DATA="[$DCRAB_DIFF_TIMESTAMP,"
		# DISK data
		DCRAB_DISK_DATA=""

		####################################################
                ## ADD INITIALIZATION OF NEW MODULE VARIABLE HERE ##
                ####################################################
	fi

	# Store user's processes 
	ps axo euid,sess,pid,pcpu,comm,command | awk '{if ($1 == '"$DCRAB_USER_ID"'){print}}' | awk '{if ($2 == '"$DCRAB_MAIN_SESSION"'){print}}' | awk '{if ($2 != '"$DCRAB_DCRAB_SESSION"'){print}}' > $DCRAB_USER_PROCESSES_FILE

	# Get the number of processes 	
	DCRAB_TOTAL_PROCESSES=$(cat $DCRAB_USER_PROCESSES_FILE | wc -l)		

	lastEmptyValue=0
	i=1
	# Check first old processes
	for line in $(cat $DCRAB_JOB_PROCESSES_FILE)
	do
		pid=$(echo "$line" | awk '{print $1}')
		commandName=$(echo "$line" | awk '{print $2}')
		auxLine=`cat $DCRAB_USER_PROCESSES_FILE | grep -n "$commandName" | awk '{if ($4 == '"$pid"'){print}}'`
		if [ "$auxLine" != "" ]; then
                	lineNumber=$(echo $auxLine | cut -d':' -f1)
			cpu=$(echo "$auxLine" | awk '{print $5}')
			sed -i "$lineNumber""d" $DCRAB_USER_PROCESSES_FILE
		else
			lastEmptyValue=$i
			cpu=" "
		fi
		
		if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
			# CPU data
			DCRAB_CPU_DATA="$DCRAB_CPU_DATA $cpu,"
		fi			

		i=$((i + 1))
		auxLine=""
	done

	# Add new processes
	for line in $(cat $DCRAB_USER_PROCESSES_FILE)
	do
		pid=$(echo "$line" | awk '{print $3}')
		cpu=$(echo "$line" | awk '{print $4}')
		commandName=$(echo "$line" | awk '{print $5}')
	
		if [ $(echo "$cpu > $DCRAB_CPU_THRESHOLD" | bc) -eq 1 ]; then
			sed -i '1s|^|'"$pid $commandName"'\n|' $DCRAB_JOB_PROCESSES_FILE
		
			if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
				# CPU data
				DCRAB_CPU_UPD_PROC_NAME[$DCRAB_CPU_UPDATES]=$commandName
				DCRAB_CPU_DATA=`echo $DCRAB_CPU_DATA | sed "s|^$DCRAB_DIFF_TIMESTAMP,|$DCRAB_DIFF_TIMESTAMP, $cpu,|"`
				DCRAB_CPU_UPDATES=$((DCRAB_CPU_UPDATES + 1))
			fi
		fi

		# If the new process is the control process. Needed for multinode statistics.
		if  [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
			
			# Intel MPI
			echo $line | grep -q "control-port"
			if [ "$?" -eq 0 ]; then
			
				# Check if is a new MPI job
				cat $DCRAB_MPI_PROCESSES_FILE | grep -q "^${pid}$" 2> /dev/null
				if [ "$?" -ne 0 ]; then
					DCRAB_NUMBER_OF_MPI_COMMANDS=$((DCRAB_NUMBER_OF_MPI_COMMANDS + 1))
			                DCRAB_CONTROL_PORT_FILE="${DCRAB_CONTROL_PORT_FILE_PREFIX}${DCRAB_NUMBER_OF_MPI_COMMANDS}"
	
					DCRAB_MPI_CONTROL_PORT_MAIN_NODE=$(echo ${line#*control-port} | awk '{print $1}')
					echo "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" > $DCRAB_CONTROL_PORT_FILE
	
					DCRAB_MPI_CONTROL_WRITED=1
			
					echo "$pid" >> $DCRAB_MPI_PROCESSES_FILE
				fi
			fi
		
			# Open MPI
	                echo $line | grep "mpirun" | grep "\--map-by" | grep -q 'ppr:.*:node'
	                if [ "$?" -eq 0 ]; then
				
				# Check if is a new MPI job
                                cat $DCRAB_MPI_PROCESSES_FILE 2> /dev/null | grep -q "^${pid}$"
                                if [ "$?" -ne 0 ]; then
					DCRAB_NUMBER_OF_MPI_COMMANDS=$((DCRAB_NUMBER_OF_MPI_COMMANDS + 1))
		                	DCRAB_CONTROL_PORT_FILE="${DCRAB_CONTROL_PORT_FILE_PREFIX}${DCRAB_NUMBER_OF_MPI_COMMANDS}"
				
					while [ "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" == "" ]; do
	                                        DCRAB_MPI_CONTROL_PORT_MAIN_NODE=$(/usr/sbin/lsof -Pan -p $(echo $line | awk '{print $3}') -i | grep "LISTEN" | awk '{print $9}')
	                                        DCRAB_MPI_CONTROL_PORT_MAIN_NODE=${DCRAB_MPI_CONTROL_PORT_MAIN_NODE##*:}
	
	                                        [ "$DCRAB_MPI_CONTROL_PORT_MAIN_NODE" == "" ] && eval $DCRAB_LOG_INFO "Wait to control port conections to be active" && sleep 1
	                                done

		                        echo "tcp://192.168.10.$DCRAB_NODE_NUMBER,10.10.1.$DCRAB_NODE_NUMBER:$DCRAB_MPI_CONTROL_PORT_MAIN_NODE;" > $DCRAB_CONTROL_PORT_FILE
	
					DCRAB_MPI_CONTROL_WRITED=1
					DCRAB_MPI_CONTROL_PORT_MAIN_NODE=""
					
					echo "$pid" >> $DCRAB_MPI_PROCESSES_FILE
				fi
	                fi
		fi
	done

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
		# CPU data
		# To avoid DCRAB_CPU_DATA termine like '0, ]', which means that the last process has been terminated, and will cause an error in the plot 
		# So we put a 0 value instead of the ' ' (space) character 
		if [ $((lastEmptyValue + 1)) -eq $i ]; then
			DCRAB_CPU_DATA=${DCRAB_CPU_DATA%,*}
			DCRAB_CPU_DATA="$DCRAB_CPU_DATA""0,"
		fi
		# Remove last comma
		DCRAB_CPU_DATA=${DCRAB_CPU_DATA%,*}
		DCRAB_CPU_DATA="[$DCRAB_CPU_DATA],"
		
		# MEM data
		dcrab_collect_mem_data
		
		# TIME data (only the main node)
		if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
			dcrab_format_time
		fi
		
		# PROCESSES_IO data
		dcrab_collect_processesIO_data 1
		
		# NFS data
		dcrab_collect_nfs_data

	        ###########################################
                ## ADD THE CALL TO THE NEW FUNCTION HERE ##
                ###########################################
	fi


	# IB data
        dcrab_collect_ib_data

	# DISK data
        dcrab_collect_disk_data

	# To notice other nodes that the main node is still executing processes
        if [ "$DCRAB_NODE_EXECUTION_NUMBER" -eq 0 ]; then
                DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER=$((DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER + 1))
                echo "$DCRAB_ACTIVE_JOB_IN_MAIN_NODE_COUNTER" > $DCRAB_ACTIVE_JOB_IN_MAIN_NODE_FILE
        fi
}

