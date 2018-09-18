#!/bin/bash
# This script is used to discover if for a given binary option, when 
# enables/disables changes the number of loops covered. 

if [ $# -ne 0 ]; then
echo "Usage: script"
exit 1
fi

source globalVar.sh
source testFuns.sh

bVerbose=0;
nonBinOpCount=0
binaryRegex="(.*)\/(.*)";
numericRegex="([0-9]+)\.\.([0-9]+)";
numOpLowBound=0
numOpHighBound=0

# Get the next numeric option from numeric options only file
# $1: index of the to be examined numeric option
# $2: numeric option file
function GetNextNumOp {
sed "${1}q;d" "$2"
} #GetNextNumOp

# $1: configuration row: c0,B,On/Off 
function GetOpName {
# Configuration name 
echo $1 | awk -F "," '{print $1}'
} #GetOpName

# $1: configuration row: c0,B,On/Off 
function GetOpValRange {
value=$(echo $1 | awk -F "," '{print $3}')
#echo $value
if [[ $value =~ $numericRegex ]];then
#echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
numOpLowBound=${BASH_REMATCH[1]}
numOpHighBound=${BASH_REMATCH[2]}
fi
} #GetOpValRange

# $1: non-binary option file location
# Identify the controlled option
# Usage: DoPairWiseTest "${CONFIG_INTER}/${NonBinaryOpFile}";
function DoPairWiseTest {
#echo "nonBinOpCount: $nonBinOpCount"
i=1
nonBinOpCount=$(cat ${CONFIG_INTER}/${NonBinaryOpFile} | wc -l)
while [ $i -le $nonBinOpCount ]; do
numOpLine=$(GetNextNumOp "$i" "$1")
echo "$numOpLine"
# parse out value range
name=$(GetOpName "$numOpLine")
echo "$name"
GetOpValRange "$numOpLine"
for ind in $(seq $numOpLowBound 1 $numOpHighBound);do
# non-binary value directory
nbValDir="${name}/${ind}"
mkdir -p "$nbValDir"
cp "${CONFIG_NAME}" "./${nbValDir}"
cd "${nbValDir}"
# Update config file
newVal=${name}" "${ind};
echo "New configuration: $newVal"
# Make changes to the copied configuration
# -i: changes make in place (save changes to file)
sed -i "s/^[ tab]*${name}\s\+.*/${newVal}/" ${CONFIG_NAME} && vEcho "Updated ${CONFIG_NAME}";
# Run test
echo "current config file location: $(pwd)/${CONFIG_NAME}" 
RunTest "$(pwd)/${CONFIG_NAME}" "$ind" "$name" "${TestCaseId}" "TestS4";
cd ../.. # return to the binary root
done #for ind
((i++))
done #while loop
} #DoPairWiseTest

function init {
# Clean files
# Create configuration interaction folder
if [ -d ${CONFIG_INTER} ]; then
rm -rf ${CONFIG_INTER}/* && echo "Deleted ${CONFIG_INTER}"
else
mkdir ${CONFIG_INTER} && echo "Created ${CONFIG_INTER}"
fi
} # init

# Main starts here 
init;
# Stop any Apache instance
$sudoCmd ${HTTPD_BIN} -k stop \
			 && echo "Apache stop issued, just in case any instance is still running.";
cd ${CONFIG_INTER} && echo "Entering ${CONFIG_INTER}"

# Loop through non-binary options
while IFS='' read -r nb_line || [[ -n "$nb_line" ]]; do

ParseConfigNamePath "$nb_line"
# Restore to the original configuration
cp ${CONFIG_ORIG_PATH} ${CONFIG_FILE_PATH} \
		 && vEcho "Restore config file ${CONFIG_FILE_PATH} to original state ${CONFIG_ORIG_PATH}";

# Configuration name 
nb_name=$G_OPTION_NAME #$(echo $nb_line | awk -F "," '{print $1}')
nb_config_path=${CONFIG_FILE_PATH}
#mkdir "$name" && vEcho "Created $name folder"
#cd $name && vEcho "Entering $(pwd)"

# Value range
nb_value=$(echo $nb_line | awk -F "," '{print $3}')
echo "$nb_name $nb_value" 

# Loop through binary options
while IFS='' read -r bo_line || [[ -n "$bo_line" ]]; do
ParseConfigNamePath "$bo_line"
# Configuration name 
bo_name=$G_OPTION_NAME #$(echo $bo_line | awk -F "," '{print $1}')
bo_config_path=$CONFIG_FILE_PATH

# Check if non-binary and binary option belongs to the same configuration file
if [ ${G_OP_CHECK_SAME_FILE_ONLY} -eq 1 ]; then
	if [ "${bo_config_path}" != "${nb_config_path}" ]; then
	# Get to the next binary option
	continue
	fi 
fi
# Value range
bo_value=$(echo $bo_line | awk -F "," '{print $3}')
if [[ $bo_value =~ $binaryRegex ]];then
#echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
firstVal=${BASH_REMATCH[1]} 
secondVal=${BASH_REMATCH[2]}
for binaryVal in $secondVal $firstVal; do
folderName="${nb_name}/${bo_name}-${binaryVal}"
mkdir -p "$folderName" && cd "$folderName";

# Make a copy of existing configuraitons
#cp ${CONFIG_FILE_PATH} . && vEcho "Copying config file from ${CONFIG_FILE_PATH}";
newBoConfigVal=${bo_name}" "${binaryVal};
echo "New binary config val: $newBoConfigVal"

# Modify on the original copy
sed -i "s/^[ tab]*${bo_name}\s\+.*/${newBoConfigVal}/" ${bo_config_path} && vEcho "Updated binary op ${bo_config_path}";

GetOpValRange "$nb_line"
jumpStep=$(G_GetStep $numOpHighBound $G_NB_STEP)
for ind in $(seq $numOpLowBound $jumpStep $numOpHighBound);do
# non-binary value directory
nbValDir="${ind}"
mkdir -p "$nbValDir" 
#cp "${CONFIG_NAME}" "./${nbValDir}"
cd "${nbValDir}"
# Update config file
newNbVal="${nb_name} ${ind}";
echo "New non-binary config val: $newNbVal"
# Update non-binary op value
sed -i "s/^[ tab]*${nb_name}\s\+.*/${newNbVal}/" ${nb_config_path} && vEcho "Updated non-binary op ${nb_config_path}";

# Run test 
GetTestNameById $TestCaseId 
RunTest "SKIPCOPY" "$ind" "$nb_name" "${TestCaseId}" "$G_TEST_NAME";
cd ..
done # for non-binary op loop
cd ../..
done # for loop through binary option value
fi # if [[ $value =~ $binaryRegex ]]
done < "$BinaryOpFile"
done < "$NonBinaryOpFile" # while loop for iterating through non-binary options
