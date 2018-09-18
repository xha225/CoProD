#!/bin/bash
# V0.1, this script is used to prepare training data for the final prediction
# model, it assembles configuration option values from the coverage array file
# and used the selected measurement as its label

# 1. How to sample configuration values
# 2. How to calculate labels (instruction count, execution time)
# for each config set, get all the loop data from 
# print config set value, and calculate the sum of all loop counts of this config set

if [ $# -ne 3 ]; then 
echo "Usage script coverageArrayFile output opSelectionFile";
exit 1
fi

source globalVar.sh
recordInd=1
labelSum=0
caFile=$1

>"$2"
# Print header for selected options
while IFS='' read -r opEntry || [[ -n "$opEntry" ]];do
echo -n "$opEntry," >> $2
done < $3

echo "${G_MEASURE_NAME}" >> $2

tail -n +8  $caFile | \
while IFS='' read -r caEntry || [[ -n "$caEntry" ]];do
# grep option: h: ignore file name
#echo "${G_CONFSET_NAME}${recordInd}"

# In rare cases, data for a given record id is not generated
# this step makes sure such data does not get into the final 
# training data. TODO: report when such case happens
testTraceFile="${CONFIG_SAMPLE_DIR}/${G_TEST_FOLDER}/testCase${TestCaseId}.trace"
recordCount=$(grep "${G_CONFSET_NAME}${recordInd}," "$testTraceFile" -ih | wc -l)
if [ $recordCount -eq 0 ]; then
echo "ERR: Can't find $recordInd"
# Move on to the next record
((recordInd++))
echo "Moved to $recordInd"
continue
fi

echo -n "$caEntry," >> "$2"

traceHeader=$(head -n 1 "$testTraceFile")
colInd=$(GetHeaderIndByName ${G_MEASURE_NAME} ${traceHeader})
if [ $colInd -eq -1 ]; then
echo "Can't parse ${G_MEASURE_NAME} index from header"
echo "Check traceHeader: $traceHeader"
echo "colInd: $colInd"
exit 1
fi

while IFS='' read -r grepEntry || [[ -n "$grepEntry" ]];do
# TODO: make the label configurable, based on index of the trace file header
# parse out the iteration count from each match
#echo $grepEntry
IFS=',' read -ra valArray <<< "$grepEntry"
#echo ${valArray[4]}
labelSum=$(echo "scale=0;(${labelSum}+${valArray[$colInd]})/1" | bc)
#echo "labelSum=$labelSum"
# Use process substitution to make labelSum still accessible outside while loop
done < <(grep "${G_CONFSET_NAME}${recordInd}," "${CONFIG_SAMPLE_DIR}/${G_TEST_FOLDER}/DATA/${G_TEST_FOLDER}" -rih)

echo $labelSum >> "$2"
((recordInd++))
# reset label sum 
labelSum=0
done # coverage array entry

mv "$2" ${CONFIG_SAMPLE_DIR}
