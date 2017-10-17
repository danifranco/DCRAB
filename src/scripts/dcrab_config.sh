#!/bin/bash


dcrab_save_environment () {

        declare -p | grep "$1" >> dcrab_report_$DCRAB_JOB_ID/aux/env.txt
}

dcrab_start_report () {

	# Check the scheduler system used and define host list
	if [ -n "$SLURM_NODELIST" ]; then
	      	DCRAB_SCHEDULER=slurm
		DCRAB_JOB_ID=$SLURM_JOB_ID
		DCRAB_WORKDIR=$SLURM_SUBMIT_DIR
		DCRAB_JOBNAME=$SLURM_JOB_NAME
	        DCRAB_NODES=`scontrol show hostname $SLURM_NODELIST`
	elif [ -n "$PBS_NODEFILE" ]; then
	        DCRAB_SCHEDULER=pbs
	        DCRAB_JOB_ID=$PBS_JOBID
	        DCRAB_WORKDIR=$PBS_O_WORKDIR
		DCRAB_JOBNAME=$PBS_JOBNAME
	        DCRAB_NODES=`cat $PBS_NODEFILE | sort | uniq`
	else
	        DCRAB_SCHEDULER=none
	        DCRAB_JOB_ID=`date +%s`
	        DCRAB_WORKDIR=.
	        DCRAB_NODES=`hostname -a`
	fi


	# Creates report folder and .html
	cd $DCRAB_WORKDIR
	mkdir -p dcrab_report_$DCRAB_JOB_ID/data
	
	# Generate the first steps of the report
	echo "<html lang=\"en\">" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "<head><title>DCRAB REPORT</title></head> " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "<body>" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "<h1>DCRAB REPORT - JOB $DCRAB_JOB_ID </h1>" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "Name of the job: $DCRAB_JOBNAME" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "User: $USER" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "Working directory: $DCRAB_WORKDIR" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "Node list: " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "$DCRAB_NODES" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "</body> " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
	echo "</html> " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html

        # Folder to save the environment
        mkdir -p dcrab_report_$DCRAB_JOB_ID/aux
}

dcrab_finalize () {

	# Need this variables set to restore environment
        if [ -n "$SLURM_NODELIST" ]; then
		DCRAB_WORKDIR=$SLURM_SUBMIT_DIR	
                DCRAB_JOB_ID=$SLURM_JOB_ID
        elif [ -n "$PBS_NODEFILE" ]; then
		DCRAB_WORKDIR=$PBS_O_WORKDIR
                DCRAB_JOB_ID=$PBS_JOBID
        else
		DCRAB_WORKDIR=.
                DCRAB_JOB_ID=`date +%s`
        fi

	# Restore environment
	cd $DCRAB_WORKDIR	
	source dcrab_report_$DCRAB_JOB_ID/aux/env.txt
	
	# Finalize functions
	source $DCRAB_BIN/scripts/dcrab_finalize.sh

	# Stop DCRAB processes	
	dcrab_stop_remote_processes
}

dcrab_start_data_collection () {

        declare -a DCRAB_PIDs
        i=0
        for node in $DCRAB_NODES
        do
                # Create node folders
                mkdir -p dcrab_report_$DCRAB_JOB_ID/data/$node

                COMMAND="$DCRAB_BIN/scripts/dcrab_startDataCollection.sh $DCRAB_WORKDIR/dcrab_report_$DCRAB_JOB_ID/data/$node >> $DCRAB_WORKDIR/dcrab_report_$DCRAB_JOB_ID/dcrab.log & echo \$!"
                # Hay que poner la key, sino pide password
                DCRAB_PIDs[$i]=`ssh -n $node PATH=$PATH $COMMAND | tail -n 1 `

                echo "N: $node P:"${DCRAB_PIDs[$i]} >> dcrab_report_$DCRAB_JOB_ID/dcrab.log

                # Next
                i=$((i+1))
        done
	
	# Save DCRAB_PID variable for future use
	dcrab_save_environment "DCRAB_PIDs"
}




