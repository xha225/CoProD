#!/bin/bash
## Test Subject
G_APP_NAME="Apache"
G_CONFIG_HARNESS="$(pwd)/apache.harness" 
# Match a configuration harness file comment line
G_OP_CMT_REGEX="^#.*$"
G_EXCLUDE_SOURCE[0]="${HOME}/PlayGround/httpd-2.2.2/srclib/" #"${HOME}/PlayGround/httpd-2.2.2/srclib/"
# TO add more excluded source: G_EXCLUDE_SOURCE[1]=""

G_TRACE_HEADER="LoopId,ConfigName,ConfigVal,TestId,NumOfInst,ExeTime,Assembly,NumOfIteration,outputDir,sourceInfo"
G_SYSCALL_HEADER="CallNum,TestId,NumOfCalls,ExeTime,ConfigVal"
# Configuration location
CONFIG_DIR="${HOME}/PlayGround/httpd-2.2.2/INSTALL/conf/"

#G_MEASURES="NumOfInst,ExeTime"
G_MEASURES="ExeTime"
G_MEASURE_NAME=ExeTime
sudoCmd=""

## PIN
PIN="${HOME}/PlayGround/pin-2.14-71313-gcc.4.4.7-linux/"
PIN_BIN=${PIN}"intel64/bin/pinbin"
PIN_PLUGIN=${PIN}"source/tools/ManualExamples/obj-intel64/CountLoopIns.so"
# For storing data files from pin plugin
RAW_DATA_DIR="RawProfileData/"
# Source path filter
G_S_FILTER="${HOME}/PlayGround/httpd-2.2.2/"

## Test Cases
# The speed of the non-binary value increases
# It is now a decimal value (0~1) used as percentage
G_NB_STEP=0.3
TestCaseId=1
G_TEST_NAME=""
G_TEST_FOLDER="T${TestCaseId}"
G_TEST_COUNT=1
G_TEST_MAP="$(pwd)/testIdName.map"
G_TEST_REPEAT_TIMES=3

# Intentionally initiated to empty
CONFIG_FILE_PATH=""
CONFIG_ORIG_PATH=""
G_OPTION_NAME=""
G_OPTION_RANGE=""
G_OPTION_TYPE=""

NonBinaryOpFile="$(pwd)/NonBinOp.config"
BinaryOpFile="$(pwd)/BinOp.config"

## For single option evluation
G_F_ID=$(tail -n 1 "dir.id")
CONFIG_DATA_DIR="$(pwd)/${G_APP_NAME}.D1.${G_TEST_FOLDER}.$G_F_ID/"
CONFIG_SAMPLE_DIR="$(pwd)/${G_APP_NAME}.D3.${G_TEST_FOLDER}.$G_F_ID/"
G_SO_LOG="so.log" 

## Configuration Interaction
CONFIG_INTER="$(pwd)/${G_APP_NAME}.D2.${G_TEST_FOLDER}.$G_F_ID/"
G_PW_LOG="pw.log"
# Use single character to reduce the text file size 
G_CONFSET_NAME="r"

#Loop dictionary. Name value pair
LOOP_DICT="$(pwd)/loopDict"
fullLoopSet="fullLoopSet"

# Combine only binary and non-binary options in the same file
# Useful for projects like Apache where there are more than one configuration files
# The assumption is that configuration options in the same file tend to have more 
# influence on each other. This also reduces the number of configuration options to combine
G_OP_CHECK_SAME_FILE_ONLY=0

# Newly discovered loop coverage 
# when the binary option value changes
uniqueLoopId="uniLoopId.file" 

## Java
javaClassPath="${HOME}/workspace/weka-src/build/classes:${HOME}/workspace/weka-src/lib/java-cup.jar"
learnerLog="learner.log"
# Single option learning data log
G_SOLD_LOG="${CONFIG_DATA_DIR}/ld.log"
# Pair-wise learning data log
G_PWLD_LOG="${CONFIG_INTER}/ld.log"

## Report
interReport="${CONFIG_INTER}/${G_TEST_FOLDER}.${G_MEASURE_NAME}.interOp.report"
singleOpRankReport="${CONFIG_DATA_DIR}/${G_TEST_FOLDER}.${G_MEASURE_NAME}.singleOp.report"

## ACTS, coverage array
G_N_WAY=2
ACTS_ARGS="-Ddebug=off -Ddoi=${G_N_WAY} -Doutput=csv -Dchandler=no"
ACTS_JAR="-jar ${HOME}/PlayGround/ACTS3.0/acts_3.0.jar"

sysForm="${G_APP_NAME}.${G_MEASURE_NAME}.sysForm"
caFile="${G_APP_NAME}.${G_MEASURE_NAME}.ca"
optionSelection="$(pwd)/opSelection.${G_MEASURE_NAME}.file"
trainFile="${G_MEASURE_NAME}.trainData.csv"

## Performance Modeling
G_PERF_TEST_DATA_FOLDER="${CONFIG_SAMPLE_DIR}/PerfTestData/${G_TEST_FOLDER}"
G_TOP_OP_RANK_THRESHOLD=2
G_WEIGHT_OPTION=2

## Custom 
HTTPD_ROOT="${HOME}/PlayGround/httpd-2.2.2/INSTALL/"
HTTPD_BIN_ROOT=${HTTPD_ROOT}"bin/"
HTTPD_BIN=${HTTPD_BIN_ROOT}"httpd"
HTTPD_LOG=${HTTPD_ROOT}"logs/"
HTTPD_PID_FILE=${HTTPD_LOG}"httpd.pid"

WebServerUrl="http://192.168.56.101:50001/"
WebServerUrlTest=${WebServerUrl}index.html

function vEcho {
	if [ $bVerbose -eq 1 ] ; then 
		echo $1;
	fi
} # vEcho
# $1: error message
# $2: output log name, in case different script outputs to different logs

function PrintMsg {
echo "$1 failed, please check $2";
}

#$1: task name; $2:start timestamp
function SecondUsed {
echo "$1 takes $(($(date +%s) - $2)) seconds";
}

#$1: Path to file 
#$2: Description of the file being checked
function IsFileExist {
if [ -e $1 ]; then
	echo "PASS: $2";
else
	echo "!!FAILED, cannot find $2, $1" && exit 1;
fi
} # function IsFileExist

#$1: harness file
function SetupCheck {
echo "TestCaseId: $TestCaseId"
echo "Beginning script configuration setup check";
IsFileExist ${PIN_BIN} "PIN binary";

IsFileExist ${PIN_PLUGIN} "PIN plugin";

IsFileExist ${G_TEST_MAP} "Test id name mapping file"
# Validate configuration harness & configuration file
while IFS='' read -r line || [[ -n "$line" ]]; do
# Skip comment lines 
if [[ $line =~ $G_OP_CMT_REGEX ]]; then
continue
fi

# Skip empty lines
# String is null, that is, has zero length
[ -z "$line" ] && continue

ParseConfigNamePath $line
IsFileExist ${CONFIG_FILE_PATH} "Configuration file";
CONFIG_ORIG_PATH="${CONFIG_FILE_PATH}.orig"
IsFileExist "${CONFIG_ORIG_PATH}" "Configuration restore file";

if [[ ${CONFIG_ORIG_PATH} =~ ${CONFIG_FILE_PATH} ]]; then
	echo "PASS: Config & restore file look good";
else
	echo "!!FAILED: check config and its restore file";
exit 3;
fi;

if grep -- "${G_OPTION_NAME}" "${CONFIG_FILE_PATH}" > /dev/null; then
	echo "PASS:${G_OPTION_NAME} found in config file";
else
	echo "!!?FAILED:${G_OPTION_NAME} NOT found in ${CONFIG_FILE_PATH}";
exit 1;
fi;
done < "$G_CONFIG_HARNESS"; # harness file

} # SetupCheck

# $1: config1@configurationFilePath
function ParseConfigNamePath {
IFS=',' read -ra valArray <<< "$1"
i=0
#echo "${valArray[0]}";
G_OPTION_TYPE=$"${valArray[1]}"
G_OPTION_RANGE="${valArray[2]}"
# Parse path key
IFS='@' read -ra configPathPair <<< "${valArray[0]}"
G_OPTION_NAME=${configPathPair[0]}
#echo "G_OPTION_NAME: $G_OPTION_NAME"
CONFIG_FILE_PATH=${CONFIG_DIR}${configPathPair[1]}
CONFIG_ORIG_PATH="${CONFIG_FILE_PATH}.orig"
#echo "$CONFIG_FILE_PATH"
} #ParseConfigNamePath 

# $1: message to print
function ChainExit {
if [ $? -ne 0 ]; then 
echo "$1"
exit 1
fi
}
# Create separate files for different option types 
# $1: the configuration harness file 
# Return the option value pair
function SplitOpByType {
if [ -e $NonBinaryOpFile ]; then
>$NonBinaryOpFile
fi

if [ -e $BinaryOpFile ]; then
>$BinaryOpFile
fi

while IFS='' read -r line || [[ -n "$line" ]]; do
#echo $line
# Skip comment lines 
if [[ $line =~ $G_OP_CMT_REGEX ]]; then
continue
fi

type=$(echo $line | awk -F "," '{print $2}')
value=$(echo $line | awk -F "," '{print $3}')

case "$type" in 
N)#echo "Numerical value"
if [[ $value =~ $numericRegex ]];then
echo "$line" >> "$NonBinaryOpFile"
fi
;;
B)#echo "Binary value"
#echo $value | grep -E "(.*)\/(.*)"
if [[ $value =~ $binaryRegex ]];then
echo "$line" >> "$BinaryOpFile"
fi
;;
esac
done < "$G_CONFIG_HARNESS" 
} # SplitOpByType

# $1: column name
# $2: header, csv list
# Returns the index, if nothing is found, return -1
function GetHeaderIndByName {
local headerArr
ind=0
IFS=',' read -ra headerArr <<< "$2"
for colName in "${headerArr[@]}"; do
if [ "$colName" == "$1" ]; then
	echo $ind
return 0
fi
((ind++))
done
echo "-1" # Signal not such column is found
} #GetHeaderIndByName

# $1: column index (0-based)
# $2: header, csv list
# Returns name, if nothing is found, return ""
function GetHeaderNameByInd {
local headerArr
ind=$1
IFS=',' read -ra headerArr <<< "$2"
echo ${headerArr[$ind]}
} # GetHeaderNameByInd

# $1: test id
function GetTestNameById {
testLine=$(grep "${1}," $G_TEST_MAP -ih)
#echo $testLine
if [[ $testLine =~ ([0-9]+),(.+) ]]; then
G_TEST_NAME=${BASH_REMATCH[2]}
else
G_TEST_NAME="FailToParse"
fi
} #GetTestNameById

#TODO: need config path as well
# $1: configuration option name
# out: value
function GetOptionVal {
grep -oP "fileSize \K[0-9]+" $CONFIG_FILE_PATH
} #GetOptionVal

# $1: Upper bound value
# $2: step in percentage
function G_GetStep {
awk -v baseVal="$1" -v step="$2" 'BEGIN {printf("%d\n", baseVal*step+1)}'
} # G_GetStep

# Only works for pairs like name=val
# $1: option name
# $2: value
# $3: file location
function UpdateConfVal {
opName=$1
opVal=$2
sed -ri "s/(^[ tab]*${opName}=).*/\1${opVal}/g" $3
} # UpdateConfVal

# $1: new measure 
# $2: globalVar.sh location
function SwitchPerfMeasure {
# Try another measure
# Update globalVar.sh
UpdateConfVal "G_MEASURE_NAME" $1 $2
} # SwitchPerfMeasure 

