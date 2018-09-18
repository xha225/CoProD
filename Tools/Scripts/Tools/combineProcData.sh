#!/bin/bash
if [ $# -ne 2 ]; then
	echo "Usage: ./combineProcData.sh dataFile outputFile"
	exit 1
fi

bVerbose=0;
source globalVar.sh

outFile=$2;
bFirst=1;
bChangedId=0;
oldTestId=0;

# Get header
# RtnName,TestId,NumOfIns,NumOfCalls
header=$(head -n1 $1);

LC_ALL=C sort -t , -k1,1 $1 | \
	# Loop through data and generate one data file for each function/routine
while IFS='' read -r line || [[ -n "$line" ]]; 
do
	# Skip other header lines
	if [[ $header =~ $line ]]; then
		continue;
	fi

	vEcho "current line: $line";
	# Get function/routine name
	funName=$(echo $line | awk -F "," '{print $1}');
	testId=$(echo $line | awk -F "," '{print $2}');
	instCount=$(echo $line | awk -F "," '{print $3}');
	#echo "instCout: $instCount";
	callCount=$(echo $line | awk -F "," '{print $4}');
	#echo "callCount: $callCount";

	confVal=$(echo $line | awk -F "," '{print $5}');
	# Verify if function name has changed since last line
	if [ "$lastFunName" == "$funName" ];then
		vEcho "testId $testId oldTestId $oldTestId";
		if [ $testId -ne $oldTestId ]; then
			bChangedId=1;
			echo "$funName,$oldTestId,$sumInst,$sumCall,$confVal" >> $outFile;
			# Reset sum
			sumInst=0;
			sumCall=0;
			oldTestId=$testId;
		else
			bChangedId=0;
		fi

		# Sum on inst
		(( sumInst = sumInst + instCount ));
		#echo "sumInst: $sumInst";

		# Sum call count
		(( sumCall = sumCall + callCount ));
		#echo "sumCall: $sumCall";
	else # A complete new line
		if [ "$bFirst" -eq "1" ]; then
			bFirst=0;
			echo $header > $outFile;
		else
			# Parse out the testId
			echo "$lastFunName,$oldTestId,$sumInst,$sumCall,$confVal" >> $outFile;
			vEcho "---------------";
		fi

		newLine=$line;
		# Create a data file for each function name    
		# echo ${funName}
		lastFunName=$funName;		
		oldTestId=$testId;
		# Reset sum
		sumInst=$instCount;
		sumCall=$callCount;
	fi
done 
#echo "$funName,$testId,$sumInst,$sumCall" >> $outFile
