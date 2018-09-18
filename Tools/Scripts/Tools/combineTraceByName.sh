#!/bin/bash
# Version 1.1, a generic version for combining trace files
if [ "$#" -lt "2" ]
then
	echo "Usage: ./combineTraceByName.sh TraceFileName ConfigDataRoot"
	echo "ConfigDataRoot is the folder named after configuration option name"
	exit 1
fi 

source globalVar.sh

fileName=$1
testId=$TestCaseId
echo "testId: $testId"
output="${2}/testCase${testId}.${fileName}.trace"
echo "output: $output"

# Enable header for each test case
bPrintHead=1

# Loop through configuration value folders
for dir in $(ls -d $2/[0-9]*/)
do
	traceFile="${dir}/RawProfileData/${fileName}"
	# echo ${traceFile}

	# Keep header
	if [ "${bPrintHead}" -eq "1" ]; then
		cat ${traceFile} > "$output"
		bPrintHead=0
	else # Print without header
		tail -n +2 ${traceFile} >> "$output"
	fi

done
