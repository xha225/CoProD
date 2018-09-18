#!/bin/bash
if [ $# -ne 2 ]; then
	echo "Usage: ./perfModelDriver.sh singleOpRank.report interOpRank.report"
	exit 1
fi
source globalVar.sh

./buildPerfModel.sh $1 $2 > bpm.${G_MEASURE_NAME}.log 2>&1 
mv bpm.${G_MEASURE_NAME}.log ${CONFIG_SAMPLE_DIR}
