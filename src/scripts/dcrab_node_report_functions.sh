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


#
# Args:
#
#  1- int     <-- Operation number. (0-CPU,1-MEM)
#
write_data () {

        echo "WRITE: $1"
        echo "cpu_data $cpu_data"
        echo "mem_data $mem_data"

case $1 in
	0) ## CPU ##
        # Update the plot to insert new process
        if [ "$updates" -gt 0 ]; then
                for i in $(seq 0 $((updates -1)) ); do
                        echo "write, loop $i"
                        # Creates a lock to write the data
                        (
                        flock -e 200

                        # Add new process entry in the plot. Specifically in the second position of the every data array
                        sed -i "$cpu_addRow_inject_line"'s|\[\([0-9]*\),|\[\1, ,|g' $DCRAB_HTML
                        # Add new process column
                        sed -i "$cpu_addColumn_inject_line""s|^|cpu_data_$node_hostname_mod.addColumn('number', '${upd_proc_name[$i]}'); |" $DCRAB_HTML

                        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab_$node_hostname_mod.lockfile
                done
        fi

        # Creates a lock to write the data
        (
        flock -e 200

        sed -i "$cpu_addRow_inject_line"'s/.*/&'"$cpu_data"'/' $DCRAB_HTML

        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab_$node_hostname_mod.lockfile
	;;

	1) ## MEM ##

        # Creates a lock to write the data
        (
        flock -e 200

        sed -i "$mem_addRow_inject_line"'s/.*/&'"$mem_data"'/' $DCRAB_HTML
	sed -i "$memUnUsed_addRow_inject_line"'s|\([0-9]*\)\]|'"$notUtilizedMem"'\]|g' $DCRAB_HTML
	sed -i "$memUsed_addRow_inject_line"'s|\([0-9]*\)\]|'"$utilizedMem"'\]|g' $DCRAB_HTML

        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab_$node_hostname_mod.lockfile
	
	;;
esac
}

dcrab_collect_mem_data () {

	# Store the data
	:> $DCRAB_MEM_FILE
	for pid in ${proc_pids[@]}; do cat /proc/$pid/status 2> /dev/null 1>> $DCRAB_MEM_FILE; done
	
	# Collect mem data
    	vmSize=$(grep VmSize $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}')
	vmRSS=$(grep VmRSS $DCRAB_MEM_FILE | awk '{sum+=$2} END {print sum/1024/1024}')
	if [ $(echo "$vmSize > $max_vmSize" | bc) -eq 1 ]; then
        	max_vmSize=$vmSize
	fi
	utilizedMem=`echo "($max_vmSize * 100)/$DCRAB_REQ_MEM" | bc `
	notUtilizedMem=`echo "100 - $utilizedMem" | bc `

	# Construct mem data string
	mem_data="$mem_data""$node_total_mem, ""$DCRAB_REQ_MEM, ""$max_vmSize, ""$vmSize, ""$vmRSS ],"
}

dcrab_determine_main_process () {


	# Needed variables	
        DCRAB_DIFF_TIMESTAMP=0
        DCRAB_MAIN_PID=0
        updates=0
        declare -a upd_proc_name                
	declare -a proc_pids
	proc_number=0

        # CPU variables
        cpu_data="0,"

	# MEM variables
	min_utilizedMem=0
	max_vmSize=0
	mem_data="[0,"	

        # Determine the main process
        IFS=$'\n'
        for line in $(ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm | sed 's|\s\s*| |g' | grep "\s$DCRAB_USER_ID\s" | grep "Ss")
        do
                pid=$(echo "$line" | awk '{print $6}')
                pstree $pid | grep -q $DCRAB_JOB_ID
                [ "$?" -eq 0 ] && DCRAB_MAIN_PID=$pid && break
        done
        export DCRAB_MAIN_PID

        # Initialize data file
        for line in $(ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm | sed 's|\s\s*| |g' | grep "$DCRAB_MAIN_PID")
        do
		# Get information of the process
                pid=$(echo "$line" | awk '{print $6}')
                cpu=$(echo "$line" | awk '{print $7}')
                commandName=$(echo "$line" | awk '{print $8}')
		
		# Save in the data file
                echo "$pid $commandName" >> $DCRAB_PROCESS_FILE

                # CPU data
		upd_proc_name[$updates]=$commandName
                cpu_data="$cpu_data $cpu,"

		# MEM data
		proc_pids[$proc_number]=$pid
		proc_number=$((proc_number + 1))
        	        
		updates=$((updates + 1))
        done

        # Get time
        DCRAB_M1_TIMESTAMP=`date +"%s"`

        # CPU data. Remove the last comma
        cpu_data=${cpu_data%,*}
        cpu_data="[$cpu_data ],"
        write_data 0

	# MEM data
	dcrab_collect_mem_data
	write_data 1	
}

dcrab_update_data () {

        # CPU data
        cpu_data="["
	
	# MEM data
	mem_data="["

        updates=0
        IFS=$'\n'

        # Collect the data
        :> $DCRAB_PROCESS_FILE.tmp
        ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm | sed 's|\s\s*| |g' | grep "$DCRAB_MAIN_PID" >> $DCRAB_PROCESS_FILE.tmp
        DCRAB_M2_TIMESTAMP=`date +"%s"`
        DCRAB_DIFF_TIMESTAMP=$((DCRAB_M2_TIMESTAMP - DCRAB_M1_TIMESTAMP))

        # CPU data      
        cpu_data="$DCRAB_DIFF_TIMESTAMP,"

        # MEM data
        mem_data="[$DCRAB_DIFF_TIMESTAMP,"

        lastEmptyValue=0
        i=1
        for line in $(cat $DCRAB_PROCESS_FILE)
        do
                pid=$(echo "$line" | awk '{print $1}')
                commandName=$(echo "$line" | awk '{print $2}')

                pos=`cat $DCRAB_PROCESS_FILE.tmp | grep -n "$pid" | grep "$commandName"`
                if [ "$?" -eq 0 ]; then
                        lineNumber=$(echo $pos | cut -d: -f1)
                        cpu=$(echo "$pos" | awk '{print $7}')
                        sed -i "$lineNumber""d" $DCRAB_PROCESS_FILE.tmp
                else
                        lastEmptyValue=$i
                        cpu=" "
                fi

                # CPU data
                cpu_data="$cpu_data $cpu,"
	
                i=$((i + 1))
        done

        # Check if there are new processes
        for line in $(cat $DCRAB_PROCESS_FILE.tmp)
        do
                pid=$(echo "$line" | awk '{print $6}')
                cpu=$(echo "$line" | awk '{print $7}')
                commandName=$(echo "$line" | awk '{print $8}')
                sed -i '1s|^|'"$pid $commandName"'\n|' $DCRAB_PROCESS_FILE
                upd_proc_name[$updates]=$commandName

                # CPU data
                cpu_data=`echo $cpu_data | sed "s|^$DCRAB_DIFF_TIMESTAMP,|$DCRAB_DIFF_TIMESTAMP, $cpu,|"`

                # MEM data
                proc_pids[$proc_number]=$pid
                proc_number=$((proc_number + 1))

                updates=$((updates + 1))
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
}






