#!/bin/bash
source globalVar.sh
bVerbose=0
driverTimer=$(date +%s);
>$G_PW_LOG
SplitOpByType;

SetupCheck

bpdTimestamp=$(date +%s);
echo "Working on getRawInterData"
./getRawInterData.sh >> $G_PW_LOG 2>&1
SecondUsed "getRawInterData" $bpdTimestamp

for dir in $(ls -d ${CONFIG_INTER}/*/);do
	echo $dir
	./getLearnData.sh "$dir" >> $G_PW_LOG 2>&1
done

echo "Working on getAllLoops"
getAllLoopsTimestamp=$(date +%s);
# Prepare loop full set
./getAllLoops.sh ${fullLoopSet} $TestCaseId "${CONFIG_INTER}/*/" >> $G_PW_LOG 2>&1
SecondUsed "getAllLoops" $getAllLoopsTimestamp

echo "Working on detectCoverageDelta"
timestamp=$(date +%s);
./detectCoverageDelta.sh >> $G_PW_LOG 2>&1
SecondUsed "detectCoverageDelta" $timestamp

# Move log to the data folder
mv ${G_PW_LOG} ${CONFIG_INTER}/${G_PW_LOG}

echo "Working on genInterReport"
IFS=',' read -ra perfMeasures <<< "$G_MEASURES"
for perfM in "${perfMeasures[@]}"; do
	echo "PerfMeasure: $perfM"
	SwitchPerfMeasure $perfM globalVar.sh
	./genInterReport.sh
	mv confModel.out ${CONFIG_INTER}/confModel.${perfM}.out 

	STARTTIME=$(date +%s)
	
	intOpRankReport=${CONFIG_INTER}/${G_TEST_FOLDER}.${perfM}.interOp.report 
	echo "intOpRankReport: $intOpRankReport"
	./groupWeightFiles.sh ${intOpRankReport}.sysCall "${CONFIG_INTER}/${perfM}/SysCallWeightGroups"
	./groupWeightFiles.sh ${intOpRankReport} "${CONFIG_INTER}/${perfM}/LoopWeightGroups"

	# Combine ExeTime of SysCall and loops
	if [ $perfM == "ExeTime" ]; then
		./combExeTime.sh "${CONFIG_INTER}/${perfM}/"
	fi

	SecondUsed "Setup weight groups" $STARTTIME
done

SecondUsed "Driver script time used" $driverTimer
exit 0 
