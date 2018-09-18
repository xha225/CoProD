#!/bin/bash
if [ $# -ne 1 ]; then
	echo "Usage script corrageArrayFile"
	exit 1
fi 

bVerbose=0
source globalVar.sh
source testFuns.sh

function RestoreConfigFiles {
	i=0
	while [ "$i" -lt "$headerSize" ]; do
		# Parse path key
		IFS='@' read -ra configPathPair <<< "${headerArray[$i]}"
		CONFIG_PATH=${configPathPair[1]}
		vEcho "configPath: $CONFIG_PATH"
		# Restore each configuration file
		cp ${CONFIG_PATH}.orig ${CONFIG_PATH} && echo "Restore $CONFIG_PATH from ${CONFIG_PATH}.orig";

		((i++))
	done
}

# $1 configuration values
function PrepareConfigVal {
	IFS=',' read -ra valArray <<< "$1"
	i=0
	while [ "$i" -lt "$headerSize" ]; do
		vEcho "${headerArray[$i]}: ${valArray[$i]}";
		# Parse path key
		IFS='@' read -ra configPathPair <<< "${headerArray[$i]}"
		name=${configPathPair[0]}
		CONFIG_PATH="${configPathPair[1]}"
		newConfigVal="$name ${valArray[$i]}"
		vEcho "name: $name configPath: $CONFIG_PATH newConfigVal: $newConfigVal"
		# Replace configuration value
		# Update configuration item with the new value
		sed -i "s/^[ tab]*${name}\s\+.*/${newConfigVal}/" ${CONFIG_PATH} && vEcho "Updated ${CONFIG_PATH}";

		# Make a copy of existing configuraitons
		cp ${CONFIG_PATH} . && vEcho "Copying config file from ${CONFIG_PATH} to $(pwd)";

		((i++))
	done

	# Run test
	# 		$2: configVal; $3: configName; $4: testId
	GetTestNameById $TestCaseId
	RunTest "SKIPCOPY" 0 "${G_CONFSET_NAME}${confSetId}" ${TestCaseId} "$G_TEST_NAME";

	#RestoreConfigFiles 
} #PrepareConfigVal

function CheckConfigOrigFile {
	i=0
	while [ "$i" -lt "$headerSize" ]; do
		# Parse path key
		IFS='@' read -ra configPathPair <<< "${headerArray[$i]}"
		CONFIG_PATH=${configPathPair[1]}
		vEcho "configPath: $CONFIG_PATH"
		IsFileExist "${CONFIG_PATH}.orig" "${CONFIG_PATH}.orig"  || ChainExit

		((i++))
	done
} # checkConfigOrigFile

# Main 
commentRegEx="^#.*"
isHeader=1
confSetId=1

SetupCheck

# Create configuration interaction folder
if [ -d ${CONFIG_SAMPLE_DIR} ]; then
	rm -rf ${CONFIG_SAMPLE_DIR} && echo "Deleted ${CONFIG_SAMPLE_DIR}"
fi

mkdir ${CONFIG_SAMPLE_DIR} && echo "Created ${CONFIG_SAMPLE_DIR}"
cd ${CONFIG_SAMPLE_DIR}

confSetDir="${G_TEST_FOLDER}"
mkdir $confSetDir 
cd $confSetDir

while IFS='' read -r line || [[ -n "$line" ]]; do
	if ! [[ ${line} =~ ${commentRegEx} ]];then

		if [ $isHeader -eq 1 ]; then
			header=$line
			IFS=',' read -ra headerArray <<< "$header"
			headerSize=${#headerArray[@]}	

			CheckConfigOrigFile
			# Just in case previous runs got interrupted before script finishes

			RestoreConfigFiles && echo "Restore config files before updating values" 
			#echo ${headerArray[@]}
			isHeader=0
		else
			mkdir $confSetId
			cd $confSetId

			PrepareConfigVal $line
			((confSetId++))
			cd ..
		fi

	fi # ! [[ ${line} =~ ${commentRegEx} ]]

done < "$1" 
