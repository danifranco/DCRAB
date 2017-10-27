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


dcrab_determine_main_process () {

        DCRAB_DIFF_TIMESTAMP=0
        DCRAB_MAIN_PID=0
        updates=0
        declare -a upd_proc_name                

        # CPU data
        cpu_data="0,"

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
                pid=$(echo "$line" | awk '{print $6}')
                cpu=$(echo "$line" | awk '{print $7}')
                commandName=$(echo "$line" | awk '{print $8}')
                echo "$pid $commandName" >> $1
                upd_proc_name[$updates]=$commandName

                # CPU data
                cpu_data="$cpu_data $cpu,"

                updates=$((updates + 1))
        done

        # Get time
        DCRAB_M1_TIMESTAMP=`date +"%s"`

        # Remove the last comma
        cpu_data=${cpu_data%,*}
        cpu_data="[$cpu_data ],"

        write_data $addRow_inject_line $addColumn_inject_line $cpu_data
}

dcrab_update_data () {

        # CPU data
        cpu_data="["

        updates=0
        IFS=$'\n'

        # Collect the data
        :> $1.tmp
        ps axo stat,euid,ruid,sess,ppid,pid,pcpu,comm | sed 's|\s\s*| |g' | grep "$DCRAB_MAIN_PID" >> $1.tmp
        DCRAB_M2_TIMESTAMP=`date +"%s"`
        DCRAB_DIFF_TIMESTAMP=$((DCRAB_M2_TIMESTAMP - DCRAB_M1_TIMESTAMP))

        # CPU data      
        cpu_data="$DCRAB_DIFF_TIMESTAMP,"

        lastEmptyValue=0
        i=1
        for line in $(cat $1)
        do
                pid=$(echo "$line" | awk '{print $1}')
                commandName=$(echo "$line" | awk '{print $2}')

                pos=`cat $1.tmp | grep -n "$pid" | grep "$commandName"`
                if [ "$?" -eq 0 ]; then
                        lineNumber=$(echo $pos | cut -d: -f1)
                        cpu=$(echo "$pos" | awk '{print $7}')
                        sed -i "$lineNumber""d" $1.tmp
                else
                        lastEmptyValue=$i
                        cpu=" "
                fi

                # CPU data
                cpu_data="$cpu_data $cpu,"

                i=$((i + 1))
        done

        # Check if there are new processes
        for line in $(cat $1.tmp)
        do
                pid=$(echo "$line" | awk '{print $6}')
                cpu=$(echo "$line" | awk '{print $7}')
                commandName=$(echo "$line" | awk '{print $8}')
                sed -i '1s|^|'"$pid $commandName"'\n|' $1
                upd_proc_name[$updates]=$commandName

                # CPU data
                cpu_data=`echo $cpu_data | sed "s|^$DCRAB_DIFF_TIMESTAMP,|$DCRAB_DIFF_TIMESTAMP, $cpu,|"`

                updates=$((updates + 1))
        done

        # To avoid cpu_data termine like '0, ]', which means that the last process has been terminated, and will cause an error in the plot 
        # So we put a 0 value instead of the ' ' (space) character 
        if [ $((lastEmptyValue + 1)) -eq $i ]; then
                cpu_data=${cpu_data%,*}
                cpu_data="$cpu_data""0,"
        fi

        # Remove the last comma
        cpu_data=${cpu_data%,*}
        cpu_data="[$cpu_data],"
}

write_data () {

	# Update the plot to insert new process
	if [ "$updates" -gt 0 ]; then
		for i in $(seq 0 $((updates -1)) ); do
			echo "write, loop $i"
   		        # Creates a lock to write the data
		        (
		        flock -e 200

			# Add new process entry in the plot. Specifically in the second position of the every data array
		        sed -i "$1"'s|\[\([0-9]*\),|\[\1, ,|g' $DCRAB_REPORT_DIR/dcrab_report.html      
			# Add new process column
 			sed -i "$2""s|^|data_$node_hostname_mod.addColumn('number', '${upd_proc_name[$i]}'); |" $DCRAB_REPORT_DIR/dcrab_report.html

		        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab_$node_hostname_mod.lockfile
		done
	fi

        # Creates a lock to write the data
        (
        flock -e 200

        sed -i "$1"'s/.*/&'"$3"'/' $DCRAB_REPORT_DIR/dcrab_report.html

        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab_$node_hostname_mod.lockfile
}
