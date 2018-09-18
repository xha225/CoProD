#!/bin/bash
#SBATCH -J apache.worker.deflate
#SBATCH -n 16
#SBATCH -t 30-00:00:00 #12:00:00 #1-00:00:00
#SBATCH -p Long #Med #PartNod #Short
INITTIME=$(date +%s)
source globalVar.sh
./batchKill.sh
# Single option selection
./apacheGo.sh
# Option interaction selection
./apachePairWiseDriver.sh
# Gen training data
if [ "${SLURM_JOBID}" == "" ]; then
	SLURM_JOBID=$(tail -n 1 "dir.id")
fi
./doExeperiment.sh ${G_NB_STEP}-${TestCaseId}-${SLURM_JOBID}
SecondUsed "Time spent on oneTouch" $INITTIME
