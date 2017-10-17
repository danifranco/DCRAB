#!/bin/bash


write_data () {

	echo "AR: $1, AC: $2, U: $updates"	
	echo "data: $3, DCRAB_DIFF_TIMESTAMP: $DCRAB_DIFF_TIMESTAMP"

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
