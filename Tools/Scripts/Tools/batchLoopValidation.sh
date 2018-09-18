#!/bin/bash
if [ $# -ne 1 ]; then
echo "Usage script DataDir"
exit 1
fi

#CONFIG_DATA/Timeout/1/RawProfileData/loopInsCount.data
for configDir in $(ls -d $1/*);do
#echo $configDir;
for valDir in $(ls -d ${configDir}/*);do
echo $valDir;
# Call loopValidation.sh
echo "Processing ${valDir}/RawProfileData/loopInsCount.data";
# call removeHeadTail.sh script first to preserve the ppid info
./removeHeadTail.sh "${valDir}/RawProfileData/loopInsCount.data" "${valDir}/RawProfileData/" && echo "Removing start and end trace"
./loopValidation.exp.sh "${valDir}/RawProfileData/loopInsCount.data.rmHeadTail" "${valDir}/RawProfileData/loopInsCount.data.filtered"
#./loopValidation.exp.sh "${valDir}/RawProfileData/loopInsCount.data" "${valDir}/RawProfileData/loopInsCount.data.filtered" && echo "Removing false loops"
done # valDir
done # configDir
