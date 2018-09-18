#!/bin/bash
if [ $# -ne 2 ]; then
	echo "Usage: script dataFile outputFile";
	exit 1;
fi
source globalVar.sh

#TODO: Setup
bVerbose=0
outFile=$2
bFirst=1
lastLine=""
# Get header
# CallNum,TestId,NumOfCalls
header=$(head -n1 $1)
# Print header
echo $header > $outFile

LC_ALL=C sort -t, -k1n $1 | \
	{	# Loop through data and generate one data file for each function/routine
	while IFS='' read -r line || [[ -n "$line" ]]; 
	do
		# Skip other header lines
		if [[ $header =~ $line ]]; then
			continue;
		fi

		vEcho "current line: $line"
		# CallNum,TestId,NumOfCalls,ExeTime,ConfigVal
		# Get function/routine name
		funName=$(echo $line | awk -F "," '{print $1}')
		testId=$(echo $line | awk -F "," '{print $2}')
		#echo "instCout: $instCount";
		callCount=$(echo $line | awk -F "," '{print $3}')
		#echo "callCount: $callCount";
		exeTime=$(echo $line | awk -F "," '{print $4}')

		if [ $bFirst -eq 1 ]; then
			lastFunName=$funName
			bFirst=0
		fi

		confVal=$(echo $line | awk -F "," '{print $5}')
		vEcho "funName: $funName"
		vEcho "lastFunName: $lastFunName"

		# Verify if function name has changed since last line
		if [ "$lastFunName" -eq "$funName" ]; then
			vEcho "##funName: $funName"
			vEcho "##lastFunName: $lastFunName"
			# Do sum
			(( sumCall = sumCall + callCount ));
			(( sumExeTime = sumExeTime + exeTime ));
			#echo "sumCall: $sumCall";
		else   # Handle a different system call
			echo "$lastFunName,$testId,$sumCall,$sumExeTime,$confVal" >> $outFile;
			# Reset counters
			sumExeTime=$exeTime;
			sumCall=$callCount;
		fi
		lastFunName=$funName;		
	done
	# Output that last system call
	echo "$lastFunName,$testId,$sumCall,$sumExeTime,$confVal" >> $outFile
} 
# parenthesis is used preventing while loop from executing under a subshell. 
# This way we can still access varibles assigned in the loop when the loop terminates
