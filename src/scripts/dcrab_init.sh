#!/bin/bash

# Check the scheduler system used and define host list
if [ -n "$SLURM_NODELIST" ]; then
      	DCRAB_SCHEDULER=slurm
	DCRAB_JOB_ID=$SLURM_JOB_ID
	DCRAB_WORKDIR=$SLURM_SUBMIT_DIR
	DCRAB_JOBNAME=$SLURM_JOB_NAME
        NODES=`scontrol show hostname $SLURM_NODELIST`
elif [ -n "$PBS_NODEFILE" ]; then
        DCRAB_SCHEDULER=pbs
        DCRAB_JOB_ID=$PBS_JOBID
        DCRAB_WORKDIR=$PBS_O_WORKDIR
	DCRAB_JOBNAME=$PBS_JOBNAME
        NODES=`cat $PBS_NODEFILE | sort | uniq`
else
        DCRAB_SCHEDULER=none
        DCRAB_JOB_ID=`date +%s`
        DCRAB_WORKDIR=.
        NODES=`hostname -a`
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
echo "$NODES" >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
echo "</body> " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html
echo "</html> " >> dcrab_report_$DCRAB_JOB_ID/dcrab_report.html

