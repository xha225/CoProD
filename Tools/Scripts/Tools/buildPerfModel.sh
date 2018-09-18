#!/bin/bash
# V.1, this script is used to prepare the data required to build the performance
# prediction model from configuration values

source globalVar.sh
if [ $# -ne 2 ]; then
	echo "Usage: ./buildPerfModel.sh singleOpRank.report interOpRank.report"
	exit 1
fi

# $1:low; $2:high
function GetSampledVals {
jumpStep=$(G_GetStep $2 $G_NB_STEP)
if [ $2 -gt $(($1+$jumpStep)) ]; then
	for i in $(seq $1 $jumpStep $2); do
		echo -n "$i," 
	done
else
echo -n "$1, $2"
fi
} # GetSampledVals

function CreateActsSysForm {
# Clean file
>$sysForm
# Create [System] section
echo "[System]" >> $sysForm
echo "Name: $G_APP_NAME" >> $sysForm

# Create [Parameter] section
echo "[Parameter]" >> $sysForm
# loop through option selection file
while IFS='' read -r op || [[ -n "$op" ]];do
#echo $op
# query harness file to get the value range
hLine=$(grep "^${op}@" $G_CONFIG_HARNESS)
ParseConfigNamePath "$hLine" 
#$G_OPTION_NAME 
#${CONFIG_FILE_PATH}
#${G_OPTION_TYPE}

case "${G_OPTION_TYPE}" in
N)
if [[ $G_OPTION_RANGE =~ ([0-9]+)\.\.([0-9]+) ]]; then
low=${BASH_REMATCH[1]}
high=${BASH_REMATCH[2]}
#echo "$low $high"
echo "${G_OPTION_NAME}@${CONFIG_FILE_PATH} (int) : $(GetSampledVals $low $high)" >> $sysForm
fi
;;
B)#echo "Binary value"
#echo "$G_OPTION_TYPE"
if [[ $G_OPTION_RANGE =~ (.*)\/(.*) ]]; then
low=${BASH_REMATCH[1]}
high=${BASH_REMATCH[2]}
echo "${G_OPTION_NAME}@${CONFIG_FILE_PATH} (enum) : ${low},${high}" >> $sysForm
fi
;;
esac # switch, for configuration type
# prepare entry for the parameter
# c1@s4.config (int) : 1,3,5,7,9
# TODO: look up type first, then create a range of data separated by comma
done <"$optionSelection"
} # CreateActsSysForm


# Main
sinOpRankReport=$1
interOpRankReport=$2

# optionName,weight,score: e.g. KeepAliveTimeout,1-2-3,11615.071
soRegEx="(.*),(.*),(.*)"
# numericOp-binaryOp-binaryVal,score
# optionName-binaryVal,weight,score: e.g. KeepAlive-Off,2-4-4,0.0
pwRegEx="(.*)-(.*)-(.*),(.*),(.*)"

# $NonBinaryOpFile
# $BinaryOpFile
# select single options
# sort by score, use top 2, e.g. C1, C2
# c4, 1

# Reset file
>$optionSelection
if ! [ -e ${sinOpRankReport} ]; then
echo "Can't find ${sinOpRankReport}. Aborting!"
exit 1
fi

LC_ALL=C sort -g -r -t, -k3 $sinOpRankReport | head -n $G_TOP_OP_RANK_THRESHOLD | \
while IFS='' read -r so_line || [[ -n "$so_line" ]];do
#echo "$so_line"
if [[ $so_line =~ $soRegEx ]]; then
echo "${BASH_REMATCH[1]}" >> $optionSelection
fi
done
# Separator, used for debugging purposes
#echo "---" >> $optionSelection

# select option pairs 
# sort by score, use top 2, e.g. C3*C4, C3*C7, C5*C6
# also output the relationships to a file for later inquery
# C3&C4; C3&C7
# C5:C6
#echo $interOpRankReport
LC_ALL=C sort -g -r -t, -k3 $interOpRankReport | head -n $G_TOP_OP_RANK_THRESHOLD | \
while IFS='' read -r pw_line || [[ -n "$pw_line" ]];do
# c0-1,c2,3
#echo $pw_line
if [[ $pw_line =~ $pwRegEx ]]; then
#echo ${BASH_REMATCH[1]}
#echo ${BASH_REMATCH[2]}
# Exclude option if it is in the file already
if ! grep -E "^${BASH_REMATCH[1]}$" --quiet $optionSelection; then
echo ${BASH_REMATCH[1]} >> $optionSelection 
fi

if ! grep -E "^${BASH_REMATCH[2]}$" --quiet $optionSelection; then
echo ${BASH_REMATCH[2]} >> $optionSelection
fi

fi # RegEx
done

# get a traning data options
# O1, O2, O3, O4, O5, O6
# Get coverage array - ACTS
# Sampling values, and then render the following scheme
# C1, C2, C3*C4, C5*C6, ... Label
# Take a look at the interactive testing code: parseCoverageArray.sh
CreateActsSysForm

# Call ACTS to generate coverage array
java $ACTS_ARGS $ACTS_JAR $sysForm $caFile

# Data quantity check, reject if less than 10
numOfEntry=$(tail -n +7 $caFile | wc -l)
if [ $numOfEntry -lt 10 ]; then
echo "Not enough sampled data to train model"
echo "Check $caFile" 
exit 1
fi

# Prepare trace data
if [ -e $caFile ]; then
./testWithCa.sh "$(pwd)/$caFile"
else
echo "Can't find $caFile"
exit 1
fi

echo "Working on getLearnData.sh"
./getLearnData.sh "${CONFIG_SAMPLE_DIR}"

echo "Working on getPredictionTrainData.sh"
./getPredictionTrainData.sh "$(pwd)/$caFile" "$(pwd)/$trainFile" "$optionSelection"
