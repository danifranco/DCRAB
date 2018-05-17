#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Autor: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# This script contains configuration functions which initialize necessary environment and starts DCRAB reporting 
# on the nodes
#
# Do NOT execute manually. DCRAB will use it automatically.
#
# ===============================================================================================================

# 
# Saves the environment to charge it later on the computing nodes 
#
dcrab_save_environment () {

	if [ $# -eq 0 ]; then 
		DCRAB_KEY_STRING="DCRAB_"
	else
		DCRAB_KEY_STRING="$1"		
	fi
	case $DCRAB_HOST_OS in
                        SUSE)
                        declare -p | grep "^$DCRAB_KEY_STRING" >> $DCRAB_REPORT_DIR/aux/env.txt
                        ;;
                        CentOS)
                        declare -p | grep "$DCRAB_KEY_STRING" >> $DCRAB_REPORT_DIR/aux/env.txt
                        ;;
                        *)
                        declare -p | grep "$DCRAB_KEY_STRING" >> $DCRAB_REPORT_DIR/aux/env.txt
                        ;;
        esac
}


#
# Checks the scheduler (if used) and initialize some variables 
#
dcrab_check_scheduler () {

	# Check the scheduler system used and define host list
	if [ -n "$SLURM_NODELIST" ]; then
		DCRAB_SCHEDULER=slurm
		DCRAB_JOB_ID=$SLURM_JOB_ID
		DCRAB_WORKDIR=$SLURM_SUBMIT_DIR
		DCRAB_JOBNAME=$SLURM_JOB_NAME
		DCRAB_NODES=`scontrol show hostname $SLURM_NODELIST`
		# Remove '-' character of the names to create javascript variables
		DCRAB_NODES_MOD=`echo $DCRAB_NODES | sed 's|-||g'`
		DCRAB_NNODES=`scontrol show hostname $SLURM_NODELIST | wc -l`
		DCRAB_JOBFILE=`ps $PPID | awk '{printf $6}'`
		DCRAB_REQ_MEM=0
		DCRAB_REQ_CPUT=0
		DCRAB_REQ_PPN=0
	elif [ -n "$PBS_NODEFILE" ]; then
		DCRAB_SCHEDULER=pbs
		DCRAB_FULL_JOB_ID=$PBS_JOBID
		DCRAB_JOB_ID=${DCRAB_FULL_JOB_ID%.*}
		DCRAB_WORKDIR=$PBS_O_WORKDIR
		DCRAB_JOBNAME=$PBS_JOBNAME
		# Sort reverse because PBS scheduler starts the execution in descending order
		for n in `cat $PBS_NODEFILE | sort -r | uniq`; do
			DCRAB_NODES="$DCRAB_NODES"" $n"
		done
		# Remove '-' character of the names to create javascript variables
		DCRAB_NODES_MOD=`echo $DCRAB_NODES | sed 's|-||g'`
		DCRAB_NNODES=`cat $PBS_NODEFILE | sort | uniq | wc -l`
		DCRAB_JOBFILE=`ps $PPID | awk '{printf $6}'`
		DCRAB_REQ_MEM=`cat $DCRAB_JOBFILE | grep "\-l mem=" | cut -d'=' -f2 | sed 's/[^0-9]*//g'`
		DCRAB_REQ_CPUT=$(cat $DCRAB_JOBFILE | grep "\-l cput" | cut -d'=' -f2)
		DCRAB_REQ_PPN=$(cat $DCRAB_JOBFILE | grep ":ppn" | grep "^#P" | cut -d'=' -f3)
		DCRAB_REQ_PPN=$(echo ${DCRAB_REQ_PPN#*ppn})
		DCRAB_REQ_PPN=$(echo ${DCRAB_REQ_PPN%%:*} | cut -d'=' -f2)
	else
		DCRAB_SCHEDULER="none"
		DCRAB_JOB_ID=`date +%s`
		DCRAB_WORKDIR=.
		DCRAB_JOBNAME="$USER.job"
		DCRAB_NODES=`hostname -a`
		DCRAB_NNODES=1
		DCRAB_JOBFILE="none"
		DCRAB_REQ_MEM=0
		DCRAB_REQ_CPUT=0
		DCRAB_REQ_PPN=0
	fi
}


#
# Initialize necessary variables 
# Arguments:
#       1- Int --> If only the internal report is enabled or not  (1 = Only internal mode, 0 = Normal monitoring)
#
dcrab_init_variables () {

        DCRAB_INTERNAL_MODE=$1

        if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then
                DCRAB_REPORT_DIR=$DCRAB_WORKDIR/dcrab_report_$DCRAB_JOB_ID
                DCRAB_HTML=$DCRAB_REPORT_DIR/dcrab_report.html
                DCRAB_LOCK_FILE=$DCRAB_REPORT_DIR/aux/dcrab.lockfile
        else
		DCRAB_REPORT_DIR=/scratch/administracion/admin/dcrab/job/$DCRAB_JOB_ID
        fi
	
	DCRAB_LOG_INFO="echo \"\$(date \"+%Y-%m-%d %H:%M:%S\")\" [JOB: \$DCRAB_JOB_ID] INFO: "
	DCRAB_LOG_ERROR="echo \"\$(date \"+%Y-%m-%d %H:%M:%S\")\" [JOB: \$DCRAB_JOB_ID] ERROR: "
	DCRAB_LOG_DIR=$DCRAB_REPORT_DIR/log
	DCRAB_WAIT_MPI_PROCESSES_DIR=$DCRAB_REPORT_DIR/aux/waitMPI
	
        DCRAB_USER_ID=`id -u $USER`
        DCRAB_HOST_OS=$(cat /etc/*release | head -1 | awk '{print $1}')

        # Delay to collect the data
        DCRAB_COLLECT_TIME=10
		
        # Used to calculate the numbers of loops a node must be done until found 
        # the control port process, which is the first step to start collecting data
        DCRAB_SLEEP_TIME_CONTROL=10
}


#
# Creates reporting directory structure baseline
#
dcrab_create_report_files () {

	# Create data folder 
        mkdir -p $DCRAB_REPORT_DIR/data

	# Create folders to save required files
	mkdir -p $DCRAB_REPORT_DIR/aux
	[ $DCRAB_INTERNAL_MODE -eq 0 ] && mkdir $DCRAB_REPORT_DIR/aux/mem
	mkdir $DCRAB_REPORT_DIR/aux/ib
	mkdir $DCRAB_REPORT_DIR/aux/ldisk
	mkdir $DCRAB_WAIT_MPI_PROCESSES_DIR

	if [ $DCRAB_INTERNAL_MODE -eq 0 ]; then		
		# Generate the first steps of the report
		dcrab_generate_html 
	fi
	
	# Change permissions
        chmod -R 755 $DCRAB_REPORT_DIR
}


#
# Starts the reporting script in the nodes involved in the execution 
#
dcrab_start_data_collection () {
		
	# Save environment
        dcrab_save_environment

	declare -a DCRAB_PIDs
	i=0
	for node in $DCRAB_NODES
	do
		# Create node folders
		mkdir -p $DCRAB_REPORT_DIR/data/$node
		
		COMMAND="$DCRAB_PATH/scripts/dcrab_node_monitor.sh $DCRAB_REPORT_DIR/aux/env.txt $i $DCRAB_LOG_DIR/$node.log & echo \$!"

		DCRAB_PIDs[$i]=`ssh -n $node "$COMMAND" | tail -n 1`
		eval $DCRAB_LOG_INFO "Node: $node - PID: ${DCRAB_PIDs[$i]}"

		i=$((i+1))
	done
	
	# Save DCRAB_PID variable for future use
	dcrab_save_environment "DCRAB_PID"
}

