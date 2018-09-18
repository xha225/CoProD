#!/bin/bash
# V1.0
# This script is used to calculate the cost of loop for a given measure
# e.g. the execution time, the instruction count

# input: 1. comma separated value: a list of loop ids
# 2. directory contains all the loop CSV files 
# 3. measure name, by default, it uses $G_MEASURE_NAME
# output: a list of costs

if [ $# -lt 2 ]; then
echo "Usage: script loopIds(CSV) csvDir measureName(optional)"
exit 1
fi

# Validate arguments
if [ ! -d $2 ]; then
echo "$2 does not exist!"
exit 1
fi

# Main
source globalVar.sh
csvList="$1"
csvDir="$2"
# Loop through csv list
IFS=',' read -ra loopIdArr <<< "$csvList"
for loopId in "${loopIdArr[@]}"; do
csvFilePath="${csvDir}/${loopId}"
traceHeader=$(head -n 1 $csvFilePath)
if [ "$3" == "" ]; then # For backward compatibility
colInd=$(GetHeaderIndByName ${G_MEASURE_NAME} ${traceHeader})
else
colInd=$(GetHeaderIndByName ${3} ${traceHeader})
fi
#echo "colInd: $colInd"
# Adjusted to one based column index
((colInd+=1))
# Calculate the cost (average value)
cost=$(./getColAvg.sh $colInd <(tail -n+2 $csvFilePath))
echo -n "${cost},"
done

# 0x424cfc.csv, 0x44cd64.csv
# Get directory first:../Apache_CONFIG_INTER/Timeout/KeepAlive-On/
# Append data folder, and the loop id file name: 0x424cfc.csv 


# Return the cost values as CSV
