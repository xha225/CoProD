#!/bin/bash
if [ $# -ne 1 ]; then 
	echo "Usage: script ConfigDataRootDir"
	exit 1
fi
source globalVar.sh

for dir in $(ls -d ${1}/*/*/RawProfileData/); do
	echo $dir
	exit 1

	fileName=$(basename ${dir})
	echo $fileName
	outDir=$(dirname ${dir})
	echo $outDir
	rtnPath="${dir}rtnCall.data"
	rtnOutPath="${rtnPath}.comb"
	#echo $rtnPath;
	#echo $rtnOutPath;

	#systemCall.data.comb
	sysPath="${dir}systemCall.data"
	sysOutPath="${sysPath}.comb"
	#echo $sysPath;
	#echo $sysOutPath;
	./combineProcData.sh $rtnPath $rtnOutPath
	./combSysData.sh $sysPath $sysOutPath
	rtnHeader=$(head -n1 $rtnOutPath)
	sysHeader=$(head -n1 $sysOutPath)
	# Extract learning data
	# Filter data by test id
	for testId in $(seq 1 1 $G_TEST_COUNT);do 
		rtnDataDir="${outDir}/../"
		rtnDataFile="${rtnDataDir}rtnData.test${testId}"
		#routine learning data output dir: RTN learning data
		rtnLdOutDir="${rtnDataDir}/RtnLD/${testId}/"
		if ! [ -d $rtnLdOutDir ]; then 
			mkdir $rtnLdOutDir
		fi 

		sysDataDir="${outDir}/../"
		sysDataFile="${sysDataDir}sysData.test${testId}"
		sysLdOutDir="${sysDataDir}/SysLD/${testId}/"
		if ! [ -d $sysLdOutDir ]; then 
			mkdir $sysLdOutDir
		fi 

		# Extract routine learning data
		echo $rtnHeader > $rtnDataFile
		grep -E ".+,${testId},.+,.+,.+" $rtnOutPath >> $rtnDataFile
		echo "Extracting data from $rtnDataFile"
		./extractLearningDataFromDataFile.sh $rtnDataFile ${rtnLdOutDir}
		echo "Output learning data to $rtnLdOutDir"

		# Extract system call learning data
		# CallNum,TestId,NumOfCalls,ExeTime,ConfigVal
		echo $sysHeader > $sysDataFile
		grep -E ".+,${testId},.+,.+" $sysOutPath >> $sysDataFile
		./extractLearningDataFromDataFile.sh $sysDataFile ${sysLdOutDir}
		echo "Output learning data to $sysLdOutDir"

	done # for testId
done # for test data folder
