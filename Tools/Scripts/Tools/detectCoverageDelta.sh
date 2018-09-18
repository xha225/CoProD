#!/bin/bash
# This script is used to identify the extra loop coverage 
# when a given binary option is enabled/disabled 
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
scriptRoot=$(pwd)
numOpLowBound=0
numOpHighBound=0

# Main starts here 
#SetupCheck;
# Stop any Apache instance

cd "${CONFIG_INTER}" && echo "Entering ${CONFIG_INTER}"

while IFS='' read -r nb_line || [[ -n "$nb_line" ]]; do
# Configuration name 
ParseConfigNamePath "$nb_line"
nb_name=$G_OPTION_NAME #$(echo $nb_line | awk -F "," '{print $1}')

# Value range
nb_value=$(echo $nb_line | awk -F "," '{print $3}')
#echo "$name $type $value" 

while IFS='' read -r bo_line || [[ -n "$bo_line" ]]; do
ParseConfigNamePath "$bo_line"
bo_name=$G_OPTION_NAME #$(echo $bo_line | awk -F "," '{print $1}')
bo_value=$(echo $bo_line | awk -F "," '{print $3}')

if ! [[ $bo_value =~ $binaryRegex ]];then
echo "!!Failed to parse: $value";
else # if [[ $value =~ $binaryRegex ]]
#echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
v1=${BASH_REMATCH[1]} 
v2=${BASH_REMATCH[2]}
D1="${bo_name}-${v1}"
D2="${bo_name}-${v2}"

# Query coverage and see if anything changes
# ../S4_CONFIG_INTER/c1/c0-0/DATA/
f1="${nb_name}/${D1}/DATA/${D1}.loopSet${TestCaseId}"
f2="${nb_name}/${D2}/DATA/${D2}.loopSet${TestCaseId}"
echo "Test on $(pwd)/$f1 and $(pwd)/$f2"

# The assumption is that when binary option enables,
# it would cover more loops, so that the fist file should 
# contains more row than the second file 

comm -23 ${f1} ${f2} > "${nb_name}/${D1}/${uniqueLoopId}"
comm -13 ${f1} ${f2} > "${nb_name}/${D2}/${uniqueLoopId}"

fi 
done < "$BinaryOpFile"
#cd .. && vEcho "Go up to interaction directory root: $(pwd)";
done < "$NonBinaryOpFile" # while loop for iterating through binary options

