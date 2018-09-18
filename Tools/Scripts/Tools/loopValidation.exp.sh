#!/bin/bash
source globalVar.sh

if [ "$#" -ne 2 ]
then
echo "Usage script datafile outputFile";
exit 1
fi

#HPC_HOME=$(echo $HOME | sed 's/\//\\\//g')
STARTTIME=$(date +%s)

skipCount=0;
bUseCache=0;
bVerbose=0;
nonLoopCache="${CONFIG_DATA_DIR}/invalidLoop.cache";
hasNonLoopCache=0;
isExcluded=0;
# example:usr/include/c++/4.8/ext/string_conversions.h_64
sourceRegex="(.*\..+)_([0-9]+)$"; 
# example 1. for(; 2. for (; 3. while(; 4. while (;
loopRegex="(for|while)[[:space:]]*\(";
# Preserve the header
header=$(head -n 1 $1)
echo $header > $2;
lastColInd=$(echo $header | awk -F , "{print NF}")
latestLoopPath=""
#echo $lastColInd
bIsLoop=0
while IFS='' read -r line || [[ -n "$line" ]]; 
do
 
# HPC, match source directory
#line=$(echo $line | sed "s/\/home\/x/${HPC_HOME}/g");
lastCol=$(echo $line | awk -F "," '{print $NF}');
#echo "line: $lastCol"
#echo "latestLoopPath: $latestLoopPath"
#echo "skipCount: $skipCount"

if [ "$latestLoopPath" == "$lastCol" ] ; then
	if [ "$bIsLoop" -eq "1" ]; then
		echo "$line" >> $2
	fi
		((skipCount++))
	continue
fi

# Reset skip loop validation
bIsLoop=0
for exSource in ${G_EXCLUDE_SOURCE[@]}; do
	if [[ $lastCol =~ $exSource ]];then
		isExcluded=1
		#vEcho "excluded line: $lastCol"
		break
	fi
done

if [ $isExcluded -eq 1 ]; then
	isExcluded=0
	continue
fi

if [[ ${lastCol} =~ ${sourceRegex} ]];then

latestLoopPath="$lastCol"
if [ $bUseCache -eq 1 ]; then 
if [ ${hasNonLoopCache} -eq 1 ]; then
# Check cache file first
if grep --quiet ${lastCol} ${nonLoopCache}; then continue; fi
else
if [ -f ${nonLoopCache} ]; then hasNonLoopCache=1; fi
fi
fi # Block comment

filePath=${BASH_REMATCH[1]};
lineNum=${BASH_REMATCH[2]};
#echo "filePath:${filePath}";
#echo "lineNum:${lineNum}";
loopLine=$(sed "${lineNum}q;d" "$filePath");
# Disable case sensitivity 
shopt -s nocasematch;
if [[ $loopLine =~ $loopRegex ]];then
# Print loop match
#vEcho ${BASH_REMATCH[1]};
# Write real loops into a new file
echo "$line" >> $2;
bIsLoop=1
else
#vEcho "!! NOT A LOOP: $loopLine";
bIsLoop=0
if [ $bUseCache -eq 1 ]; then 
# Write to cache file
echo "${lastCol}" >> $nonLoopCache ;
fi

fi #[[ $loopLine =~ $loopRegex ]] 

# Enable case sensitivity
shopt -u nocasematch; 
else # if [[ ${lastCol} =~ ${sourceRegex} ]] 
#vEcho "!! NO SOURCE LINE MATCH: ${lastCol}";
# no-op command, :, served as a place holder
:
fi
done < <(sort -t, -k ${lastColInd} $1)

ENDTIME=$(date +%s)
#echo "It takes $(($ENDTIME - $STARTTIME)) seconds to complete this task..."
#echo "skipCount: $skipCount"
