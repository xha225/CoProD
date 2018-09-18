#!/bin/bash
# Version 1.1, one test case at a time
if [ "$#" -lt "1" ]
then
	echo "Usage: script ConfigDataRoot"
	echo "ConfigDataRoot is the folder that contains all test data across different configuration values"
	exit 1
fi 

source globalVar.sh
# grep -E "^[^,]+,[^,]+,[0-9]+,2," -in -m 1
#to get just the number part from grep:"  cut -d: -f1" 

# For batch testing
#for testId in $(seq 1 1 ${G_TEST_COUNT});do
testId=$TestCaseId
echo "testId: $testId"
output="testCase${testId}.trace"

# Enable header for each test case
bPrintHead=1

# Loop through configuration value folders
for dir in $(ls -d $1/*/)
do
	echo $dir;
	traceFile="${dir}/RawProfileData/loopInsCount.data.filtered"
	echo ${traceFile};

	# Keep header
	if [ "${bPrintHead}" -eq "1" ]; then
		cat ${traceFile} > "$1/$output"
		bPrintHead=0
	else # Print without header
		tail -n +2 ${traceFile} >> "$1/$output"
	fi

done
