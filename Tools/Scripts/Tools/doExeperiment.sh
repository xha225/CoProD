#!/bin/bash
if [ $# -ne 1 ]; then
	echo "Usage script StepVal"
	exit 1
fi

source globalVar.sh
# Main
# Step value
stepVal=$1
# N-Way does not exceed 7-way
maxTopN=2
ExpDir=Step${stepVal}

if [ -d $ExpDir ]; then
	echo "$ExpDir exists. Check!"
	exit 1
fi

mkdir "Step${stepVal}"
report=Step${stepVal}/report.csv
>$report

IFS=',' read -ra perfMeasures <<< "$G_MEASURES"

#for topN in $(seq 2 1 $maxTopN); do
for topN in $(seq $maxTopN 1 $maxTopN); do
	#echo "-$topN"
	maxNway=$topN
	#for nWay in $(seq 2 1 $maxNway); do
	for nWay in $(seq $maxNway 1 $maxNway); do
		#echo "--$nWay"
		dir="Top${topN}-${nWay}Way"
		# Update top-n and n-way in globalVar
		UpdateConfVal "G_TOP_OP_RANK_THRESHOLD" $topN "$(pwd)/globalVar.sh"
		UpdateConfVal "G_N_WAY" $nWay "$(pwd)/globalVar.sh"
	
		for perfM in "${perfMeasures[@]}"; do
			trainData="${perfM}.trainData.csv"
			echo "perfM: $perfM"
			SwitchPerfMeasure $perfM globalVar.sh

			for rankDir in $(ls -d ${CONFIG_DATA_DIR}/${perfM}/LoopWeightGroups/*/)
			do
				weightDir=$(basename $rankDir)
				subDir="${ExpDir}/${dir}/${perfM}/${weightDir}"
				mkdir -p $subDir 

				# Build model
				echo "Calling perfModelDriver"
				if [ $perfM == "ExeTime" ]; then
					tGroup="CombETWeightGroups"
				else
					tGroup="LoopWeightGroups"
				fi
				./perfModelDriver.sh ${CONFIG_DATA_DIR}/${perfM}/${tGroup}/${weightDir}/wgFile \
					${CONFIG_INTER}/${perfM}/${tGroup}/${weightDir}/wgFile
				# Copy globalVar.sh
				cp -u globalVar.sh $subDir/globalVar.${perfM}.sh
				# Copy train file
				# TODO: Incorporate weight directory 
				cp -u ${CONFIG_SAMPLE_DIR}/$trainData $subDir
				cp -u opSelection.${perfM}.file $subDir/opSelection.${perfM}.file

				java -cp $javaClassPath PredictionModel "$subDir/$trainData" > ${subDir}/perfModel.${perfM}.summary 2>&1 
				# Measure,StepVal, TopN, OpSelected, #OpSelected, N-Way, WeightMethod, Observations, Learner, ErrorRate
				echo -n "$perfM,$1,$topN,$(tr '\n' ';' < $subDir/opSelection.${perfM}.file )," >> $report 
				echo -n "$(cat $subDir/opSelection.${perfM}.file | wc -l),$nWay,$weightDir," >> $report
				echo "$(cat ${CONFIG_SAMPLE_DIR}/$trainData | wc -l),SMO2,$(cat relAbsErr.out)" >> $report

				mv relAbsErr.out ${subDir}/relAbsErr.${perfM}.out
				mv  ${CONFIG_SAMPLE_DIR}/bpm.${perfM}.log $subDir

			done # for, rankDir 
		done # for, measure loop
	done # nWay
done # topN
