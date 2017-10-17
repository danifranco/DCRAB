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

The first D is of Donostia International Physics Center Fundation (DIPC), who are the main developers of the software. The 'crab' part is related to the animal ...

### PROS

  - Real time monitorization
  - All data collected in a single .html file
  - No compilation required
  - Easy to use in a script because only two sentence are required to monitor data
