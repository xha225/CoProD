#!/bin/bash
source globalVar.sh

bVerbose=0
>${interReport}
mInd=$(GetHeaderIndByName $G_MEASURE_NAME  $G_TRACE_HEADER)
# Offset index by 2
sysMInd=$((mInd-2))
echo "sysMInd: $sysMInd"

for f in $(find ${CONFIG_INTER}/ -iname ${uniqueLoopId}); do
	# File is not empty"
	if [ -s "${f}" ]; then
		loopDeltaPath=$(dirname $f)
		vEcho "loopDeltaPath: $loopDeltaPath"

		biOp=$(basename $loopDeltaPath)
		nbOp=$(basename $(dirname $loopDeltaPath))

		loop_id=$(cat $f | tr "\n" ",")
		vEcho "$loop_id"
		pwDataRoot="${loopDeltaPath}"
		vEcho "pwDataRoot: $pwDataRoot"
		dataDir="${pwDataRoot}/DATA/${G_TEST_FOLDER}"
		vEcho "dataDir: $dataDir"
		echo -n "Working on modeling,${biOp},${nbOp}"

		>"${CONFIG_INTER}/${learnerLog}"

		java -cp $javaClassPath FeatureModeling ${loop_id} ${pwDataRoot} 1 ${dataDir} \
			$(./getLoopCost.sh "$loop_id" "${loopDeltaPath}/DATA/${G_TEST_FOLDER}") \
			"2,$mInd" $G_WEIGHT_OPTION 10 \
			1>>${interReport} 2>>"${CONFIG_INTER}/${learnerLog}"
		
		# Report progress
		echo -n "..."

		# TODO: Don't we need to use the difference?
		# Output SysCall learning result
		sysCallDir="${pwDataRoot}/SysCall/"
		sysCall_ids=$(ls $sysCallDir | tr "\n" ",")
		#./getLoopCost.sh 
		java -cp $javaClassPath FeatureModeling "${sysCall_ids}" "${pwDataRoot}" 1 "${sysCallDir}" \
			$(./getLoopCost.sh "${sysCall_ids}" "${sysCallDir}" $(GetHeaderNameByInd ${sysMInd} ${G_SYSCALL_HEADER})) \
			"4,$sysMInd" $G_WEIGHT_OPTION 5 \
			1>>"${interReport}.sysCall" 2>>"${CONFIG_INTER}/${learnerLog}.sysCall"

		# Report progress
		echo  "Done"
	fi # if [ -s "${uniLoopIdPath}" ]; then
done
