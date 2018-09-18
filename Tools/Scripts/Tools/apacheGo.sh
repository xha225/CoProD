#!/bin/bash
./genDirId.sh 
source globalVar.sh

# Create binary op file and non-binary op file
SplitOpByType
SetupCheck

# Reset log file
>${G_SO_LOG}

INITTIME=$(date +%s)
STARTTIME=$(date +%s)
echo "Working on testEngine"
 ./testEngine.sh > $G_SO_LOG 2>&1 || { PrintMsg "testEngine.sh failed!" "testLog" && exit 1; }
SecondUsed "testEngine" $STARTTIME 

echo "Working on batchLoopValidation"
STARTTIME=$(date +%s)
 ./batchLoopValidation.sh "$CONFIG_DATA_DIR" >> $G_SO_LOG 2>&1 || { PrintMsg "batchLoopValidation" "testLog" && exit 1; }
SecondUsed "batchLoopValidation" $STARTTIME 

STARTTIME=$(date +%s)
for dir in $(ls -d ${CONFIG_DATA_DIR}/*/)
do
echo "Processing ${dir}"
 ./collectTraceByTestId.sh "${dir}" >> $G_SO_LOG 2>&1
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
SecondUsed "collectTraceByTestId" $STARTTIME 

STARTTIME=$(date +%s)
echo "Batch extract loop learning data"
./batchExtractLearningData.sh "${CONFIG_DATA_DIR}" >> $G_SO_LOG 2>&1 || { PrintMsg "batchExtractLearningData" "testLog" && exit 1; }
# TODO: Extract system call data
SecondUsed "batchExtractLearningData" $STARTTIME 

echo "Working on combDupLoops"
timestamp=$(date +%s)
# Combine duplicated loops
./combDupLoops.sh ${CONFIG_DATA_DIR} >> $G_SO_LOG 2>&1
SecondUsed "combDupLoops" $timestamp

## SysCall and RoutineCall are temporarily left out
#STARTTIME=$(date +%s)
#echo "Batch extracting SysCall and routine learning data";
##./batchCombineProcData.sh "$CONFIG_DATA_DIR" >> $G_SO_LOG 2>&1 || { PrintMsg "batchCombineProcData" "testLog" && exit 1; };
#SecondUsed "batchCombineProcData" $STARTTIME 

# Copy log file to the data folder
mv ${G_SO_LOG} ${CONFIG_DATA_DIR}/${G_SO_LOG}

IFS=',' read -ra perfMeasures <<< "$G_MEASURES"
for perfM in "${perfMeasures[@]}"; do
	echo "PerfMeasure: $perfM"
	SwitchPerfMeasure $perfM globalVar.sh
	./genSingleOpReport.sh 
	mv confModel.out ${CONFIG_DATA_DIR}/confModel.${perfM}.out 

	STARTTIME=$(date +%s)
	sinOpRankReport=${CONFIG_DATA_DIR}/${G_TEST_FOLDER}.${perfM}.singleOp.report
	echo "sinOpRankReport: $sinOpRankReport"
	./groupWeightFiles.sh ${sinOpRankReport}.sysCall "${CONFIG_DATA_DIR}/${perfM}/SysCallWeightGroups"
	./groupWeightFiles.sh ${sinOpRankReport} "${CONFIG_DATA_DIR}/${perfM}/LoopWeightGroups"

	# Combine ExeTime of SysCall and loops
	if [ $perfM == "ExeTime" ]; then
		./combExeTime.sh "${CONFIG_DATA_DIR}/${perfM}/"
	fi
	SecondUsed "Setup weight groups" $STARTTIME
done

SecondUsed "Time spent on the script:" $INITTIME 
exit 0 
