#!/bin/bash
source globalVar.sh

>${CONFIG_DATA_DIR}/${learnerLog}
echo "Working on machine learning"
mInd=$(GetHeaderIndByName $G_MEASURE_NAME  $G_TRACE_HEADER)
# Offset index by 2
sysMInd=$((mInd-2))
echo "sysMInd: $sysMInd"

timestamp=$(date +%s);
>$singleOpRankReport
for dir in $(ls -d ${CONFIG_DATA_DIR}/*/);do
	#echo $dir
	echo "Working on modeling,$(basename $dir)"
	dataDir="${dir}/DATA/${G_TEST_FOLDER}"
	loop_ids=$(ls $dataDir | tr "\n" ",")
	#echo $loop_ids

	java -cp $javaClassPath FeatureModeling "${loop_ids}" "${dir}" 2 "${dataDir}" \
		$(./getLoopCost.sh "$loop_ids" "${dataDir}") "2,$mInd" $G_WEIGHT_OPTION 10 \
	 	1>>${singleOpRankReport} 2>>"${CONFIG_DATA_DIR}/${learnerLog}"

	# Output SysCall learning result
	sysCallDir="${dir}/SysCall/"
	sysCall_ids=$(ls $sysCallDir | tr "\n" ",")
	#./getLoopCost.sh 
	java -cp $javaClassPath FeatureModeling "${sysCall_ids}" "${dir}" 2 "${sysCallDir}" \
		$(./getLoopCost.sh "${sysCall_ids}" "${sysCallDir}" $(GetHeaderNameByInd ${sysMInd} ${G_SYSCALL_HEADER})) \
		"4,$sysMInd" $G_WEIGHT_OPTION 5 \
		1>>"${singleOpRankReport}.sysCall" 2>>"${CONFIG_DATA_DIR}/${learnerLog}.sysCall"
done

SecondUsed "Machine learning" $timestamp
