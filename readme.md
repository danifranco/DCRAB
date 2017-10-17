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
monitoring tool, like a crab grabbing its food, grabs the processes associated in the computation to collect the data. 

### PROS

  - Real time monitorization
  - All data collected in a single .html file
  - No compilation required
  - Easy to use in a script because only two sentences are required to monitor data

### Requirements/Limitations

  - Only supports one node calculations (will be added in a future version)
  - With PBS scheduler the option "#PBS -l mem=" must be written explicitly in the submission script for the memory data plot. The memory must be in GB.

### Coming features

  - MPI comunication statistics
  - Multinode computations
  - Support for Slurm.
