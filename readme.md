# DCRAB

DCRAB monitorizes submitted jobs into a scheduler system and creates a realtime based report to have a general view of how the jobs is going. It allows to view the CPU usage per node,
memory consumed by all the processes, MPI comunication statistics etc.

### How to use it

To use DCRAB you need only to 'start' and 'finish' it with the following commands in your script:
```bash
dcrab start
[
BLOCK OF CODE TO MONITOR
]
dcrab finish
```

### Why DCRAB?

The first D is of Donostia International Physics Center Fundation (DIPC), who are the main developers of the software. The 'crab' part is related to the animal because this
monitoring tool, like a crab grabbing its food, grabs the processes associated in the computation to collect the data. Furthermore, there is an analogy between crab claw
and the way DCRAB monitors the processes with 'start' and 'finish' commands. DCRAB catches the block code to monitor inside this commands like a crab holds everything 
inside its claws.


### PROS

  - Real time monitorization. The report file is continuously updating so if the job fails the report will be completed up to there 
  - All data collected in a single .html file
  - No compilation required
  - Easy to use in a script because only two sentences are required to monitor processes

### Requirements/Limitations

  - Supports multinode statistics (only for MPI jobs)
  - With PBS scheduler the option "#PBS -l mem=" must be written explicitly in the submission script for the memory data plot. The memory must be in GB

### Coming features

  - MPI comunication statistics
  - IB network statistics
  - Support for Slurm.
