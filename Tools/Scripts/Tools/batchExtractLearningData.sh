#!/bin/bash
# V1.1, collect learning data per test ID
if [ $# -ne 1 ]; then
echo "Usage script ConfigRootDir"
exit 1;
fi

source globalVar.sh

for configDir in $(ls -d ${1}/*/);do
	echo "configDir: $configDir"
	testId=$TestCaseId
	echo $testId
	trace="testCase${testId}.trace";
	tracePath="${configDir}/${trace}";
	echo "${tracePath}";
	./extractLearningDataFromDataFile.sh "${tracePath}" "${configDir}/DATA/T${testId}";
done
