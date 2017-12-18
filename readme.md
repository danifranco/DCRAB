# DCRAB (Dipc Control and Report Application in Bash)

DCRAB monitorizes submitted jobs into a scheduler system and creates a realtime based report to have a general view of how the job is going. It allows to view the CPU usage per node,
memory consumed by all the processes, MPI comunication statistics etc.

### How to use it

To use DCRAB you need only to 'start' and 'finish' it with the following commands in your script:
```bash
dcrab start

##################################
#    BLOCK OF CODE TO MONITOR    #
##################################

dcrab finish
```

### Why DCRAB?

The first D is of Donostia International Physics Center Fundation (DIPC), who are the main developers of the software. The 'crab' part is an acronym of 'Control and Report 
Application in Bash' but also is related to the animal. This is because this monitoring tool, like a crab grabbing its food, grabs the processes associated in the computation to 
collect the data. Furthermore, there is an analogy between crab claw and the way DCRAB monitors the processes with 'start' and 'finish' commands. DCRAB catches the block 
code to monitor inside this commands like a crab holds everything inside its claws.

### PROS

  - Real time monitorization. The report file is continuously updating so if the job fails the report will be completed up to there 
  - Monitors at PID level which allows to collect data only of the processes generated inside its 'start' and 'finish' statements. This allows to monitor different jobs 
    in the same node
  - All data collected in a single .html file
  - No compilation required
  - Easy to use in a script because only two sentences are required to monitor processes

### Monitoring modules added

All this modules monitor always the processes generated by the job and creates a plot for each node. Modules available are listed below:

  - CPU used
  - Memory usage 
  - Infiniband statistics 
  - Processes IO statistics
  - NFS usage (of the entire node)
  - Disk IO statistics

### Requirements/Limitations

  - Supports multinode statistics (only for MPI jobs)
  - PBS scheduler requirements:
    - DCRAB report directory will be created in the working directory (where the job was submitted with qsub)
    - The option "#PBS -l mem=" must be written explicitly in the submission script for the memory data plot and the memory must be in GB
    - The option "#PBS -l nodes=x:ppn=y" must be written explicitly in the submission script to calculate elapsed and remaining times  

### Coming features

  - Beegfs usage 
  - MPI comunication statistics
  - Internal report statistics for sysadmins
  - Support for Slurm
