#!/bin/bash


write_data () {

	echo "L: $1, U: $updates"	

	# Update the plot to insert new process
	if [ "$updates" -gt 0 ]; then
		for i in $(seq 1 $updates); do
   		        # Creates a lock to write the data
		        (
		        flock -e 200
		
			# Add new process entry in the plot	
		        sed -i "$1"'s|]|, 0]|g' $DCRAB_REPORT_DIR/dcrab_report.html      
 			sed -i "/$node_hostname_mod addColumn space/a \data_$node.addColumn('number', '${upd_proc_name[$i]})');" $DCRAB_REPORT_DIR/dcrab_report.html

		        ) 200>$DCRAB_REPORT_DIR/aux/.dcrab.lockfile
		done
	fi

	# Creates a lock to write the data
	(
    	flock -e 200

	sed -i "$1"'s/.*/&'"$3"'/' $DCRAB_REPORT_DIR/dcrab_report.html	
	
	) 200>$DCRAB_REPORT_DIR/aux/.dcrab.lockfile
	
}
