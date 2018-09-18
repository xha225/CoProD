#!/bin/bash
#
# Usage
if [ "$#" -ne "0" ] 
then
	echo "Number of arguments is: $#";
	echo "Usage: Script + ConfigPath + ConfigHarnessFilePath";
	echo "ConfigPath is relative to the Apache/install/conf/ folder";
	echo "ConfigHarnessFilePath is the full path to the harness file";
	exit 1;
fi 

source globalVar.sh
source testFuns.sh
bVerbose=0;

# Main
# Stop any Apache instance
$sudoCmd ${HTTPD_BIN} -k stop \
	&& echo "Apache stop issued, just in case any instance is still running.";

if [ -d ${CONFIG_DATA_DIR} ]; then
	rm -rf ${CONFIG_DATA_DIR}/* && echo "Removed previous data in $CONFIG_DATA_DIR"; 
else
	mkdir ${CONFIG_DATA_DIR} && echo "Created $CONFIG_DATA_DIR";
fi

cd $CONFIG_DATA_DIR && vEcho "Entering $CONFIG_DATA_DIR";
# Test configuration folder location
# Loop through the harness file: ConfigName, Type, ValueRange
#for i in {1..10}

binaryRegex="(.*)\/(.*)";
numericRegex="([0-9]+)\.\.([0-9]+)";
# Read from harness file
while IFS='' read -r line || [[ -n "$line" ]]; do
	printf "\nWorking on $line\n";

	# Reset config value order
	configValOrder=1

	ParseConfigNamePath "$line"
	# Configuration name 
	mkdir $G_OPTION_NAME && vEcho "Created $G_OPTION_NAME folder"
	cd $G_OPTION_NAME && vEcho "Entering $(pwd)"

	# Value range
	value=$(echo $line | awk -F "," '{print $3}')

	# Pattern matching to parse out values
	if [[ $value =~ $numericRegex ]];then
		#echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
		startVal=${BASH_REMATCH[1]}
		endVal=${BASH_REMATCH[2]}

		# Change values within range
		while [ "$startVal" -lt "$endVal" ];do
			newConfigVal=${G_OPTION_NAME}" "${startVal};
			vEcho "Testing $configValOrder $newConfigVal"
			mkdir $configValOrder && cd $configValOrder;
			# Make changes to the copied configuration
			# -i: changes make in place (save changes to file)
			#echo "s/^${name}.*/${newConfigVal}/"
			pwd;
			# Make a copy of existing configuraitons
			#cp ${CONFIG_FILE_PATH} . && vEcho "Copying config file from ${CONFIG_FILE_PATH}";
			# Update configuration item with the new value
			CONFIG_NAME=$(basename $CONFIG_FILE_PATH)
			#TODO: update in place
			#sed -i "s/^[ tab]*${G_OPTION_NAME}\s\+.*/${newConfigVal}/" ${CONFIG_NAME} && vEcho "Updated ${CONFIG_NAME}";
			sed -i "s/^[ tab]*${G_OPTION_NAME}\s\+.*/${newConfigVal}/" ${CONFIG_FILE_PATH} && vEcho "Updated ${CONFIG_FILE_PATH}";
			modifiedConfigLoc=$(pwd);

			GetTestNameById $TestCaseId
			RunTest "SKIPCOPY" $startVal ${CONFIG_NAME} ${TestCaseId} "${G_TEST_NAME}"
	
			((configValOrder++));
			jumpStep=$(G_GetStep $endVal $G_NB_STEP)
			((startVal+=$jumpStep)); #TODO: make smart adaptive steps
			cd ..
		done # while loop, non-binary op range
	else
		echo "!!Failed to parse: $value";
	fi

	# Restore to the original configuration
	cp ${CONFIG_ORIG_PATH} ${CONFIG_FILE_PATH} \
		&& echo "Restore config file ${CONFIG_FILE_PATH} to original state ${CONFIG_ORIG_PATH}";

	cd .. && printf "\nGo up one directory: $(pwd)\n";
done < "${NonBinaryOpFile}" # while loop for iterating through configuration harness file
