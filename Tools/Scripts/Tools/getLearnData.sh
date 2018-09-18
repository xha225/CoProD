#!/bin/bash
# This script is used to get learning data
if [ $# -ne 1 ]; then
	echo "Usage script dataFolder"
	exit 1
fi;

source globalVar.sh
#DATA_FOLDER="${CONFIG_INTER}"
DATA_FOLDER="$1"

timestamp=$(date +%s);
echo "Working on batchLoopValidation"
./batchLoopValidation.sh ${DATA_FOLDER} || \
	ChainExit "batchLoopValidation: something is wrong processing ${DATA_FOLDER}"
SecondUsed "batchLoopValidation" $timestamp 

echo "Working on collectTraceByTestId"
timestamp=$(date +%s);
for dir in $(ls -d ${DATA_FOLDER}/*/)
do
	echo "Processing ${dir}"
	./collectTraceByTestId.sh ${dir}
	echo "Working on combining system call data"
	# Combine system call data
	for rawDir in $(ls -d ${dir}/[0-9]*/RawProfileData/); do
		./combSysData.sh "${rawDir}/systemCall.data" "${rawDir}/sysCall.comb"
		echo -n "."
	done
	echo # Start a new line
	# Create system data trace file
	./combineTraceByName.sh sysCall.comb "${dir}"
	# Extract SysCall learning data
	sysCallTrace="${dir}/testCase${TestCaseId}.sysCall.comb.trace"
	./extractLearningDataFromDataFile.sh "${sysCallTrace}" "${dir}/SysCall/"
done
SecondUsed "collectTraceByTestId" $timestamp 

echo "Working on batchExtractLearningData"
timestamp=$(date +%s);
./batchExtractLearningData.sh ${DATA_FOLDER}
SecondUsed "batchExtractLearningData" $timestamp 

echo "Working on combDupLoops"
timestamp=$(date +%s);
# Combine duplicated loops
./combDupLoops.sh ${DATA_FOLDER}
SecondUsed "combDupLoops" $timestamp
