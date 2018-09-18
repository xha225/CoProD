#!/bin/bash
# This script is used to get correlation data between 
# program execution time and loop instruction count
if [ $# -ne 2 ]; then
	echo "Usage: instructionLearningData outDir"
	exit 1
fi

source globalVar.sh
source testFuns.sh
bVerbose=0
outFile="$2/correlation.${G_TEST_FOLDER}.csv"

# $1: CSV conf value
function UpdateConfVal {
	# split value by comma
	IFS=',' read -ra confValArr <<< $1
	arrSize=${#confValArr[@]}
	opSize=$((arrSize-2))
	for ind in $(seq 0 1 $opSize)
	do
		op=${opArr[$ind]}
		nameVal="$op ${confValArr[$ind]}"
		path=${opPathArr[$ind]}
		vEcho "nameValPair: $nameVal, path: $path"
		sed -i "s/^[ tab]*${op}\s\+.*/${nameVal}/" ${path} 
	done
	# Update config value
} # UpdateConfVal

function BeforeTest {
	./batchKill.sh
	# Start Apache
	${HTTPD_BIN}
} # BeforeTest

function DoTest {
	GetTestNameById $TestCaseId
	${G_TEST_NAME}
} # DoTest

function AfterTest {
	${HTTPD_BIN} -k stop 
} # AfterTest

function RestoreConfigFile {
	# Restore configuration
	for path in "${opPathArr[@]}"
	do
		oriPath="${path}.orig"
		#echo "path $path, oriPath: $oriPath"
		cp $oriPath $path
	done
	cp ${CONFIG_ORIG_PATH} ${CONFIG_FILE_PATH}
} # RestoreConfigFile

function NanoSecondUsed {
	#echo "($(date +%s%N) - $1)/1000000" | bc
	echo "$(date +%s%N) - $1" | bc
}

# Main
>$outFile
# Get header
echo "$(head -n 1 $1),Time" >> $outFile
# Get option location from header file and harness file 
IFS=',' read -ra headerArr <<< "$(head -n 1 $1)"
arrSize=${#headerArr[@]}
opSize=$((arrSize-2))
echo "Number of options: $opSize"

for ind in $(seq 0 1 $opSize)
do
	opArr[$ind]=${headerArr[$ind]}
	op=${opArr[$ind]}
	vEcho "op: $op"
	# query harness file to get the value range
	hLine=$(grep "^${op}@" $G_CONFIG_HARNESS)
	vEcho "line: $hLine"
	ParseConfigNamePath "$hLine" 
	opPathArr[$ind]=${CONFIG_FILE_PATH}
	vEcho "configFilePath: ${CONFIG_FILE_PATH}"
done

# Setup before test, for instance, start server	
BeforeTest
while IFS='' read -r line || [[ -n "$line" ]]
do
	vEcho $line
	echo -n "${line}," >> $outFile
	# Update configuration file
	UpdateConfVal $line
	sumTime=0
	# Run test without instrumentation, and keep track of execution time
	for i in $(seq 1 1 $G_TEST_REPEAT_TIMES)
	do
		STARTTIME=$(date +%s%N)
		#	STARTTIME=$(date +%s)
		DoTest
		time=$(NanoSecondUsed $STARTTIME)
		sumTime=$(echo "$sumTime+$time" | bc)
		echo $sumTime
		sleep 3s
	done
	avgTime=$(echo "$sumTime/$G_TEST_REPEAT_TIMES" | bc)
	echo $avgTime >> $outFile
done < <(tail -n +2 $1) # Skip header line
# Post test	
AfterTest
# Restore configuration files
RestoreConfigFile
