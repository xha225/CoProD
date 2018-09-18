#!/bin/bash
if [ "$#" -ne "1" ]; then
echo "Usage script ConfigInterDir"
exit 1
fi

source globalVar.sh 
bVerbose=0
#$1: loopPath
#$2: filePath
function GroupSameLoops {
# Detect if other files that may have the same loop source
# -m 1: only return the first occurrence
# -l: only return the file name
loopDir=$(dirname $2)
loopFileName=$(basename $2)

# Loop through files that have the same loop source path
for file in $(grep "$1$" $loopDir -rin -m 1 -l); do
# Skip self
if [ "$file" == "$2" ]; then  
continue
fi

vEcho "$2"
vEcho "Append $file to $2"
# Combine file without header 
echo "$(tail -n +2 $file)" >> $2
# Delete the file that contains the same loop source
if ! [ "$file" == "$2" ]; then  
rm -f $file
echo "Deleted: $file"
fi
done # for, combine loops

# Check if record exists in dictionary
loopId=$(grep "$1$" $LOOP_DICT | sed -r 's/(.*):.*/\1/')
if [ "$loopId" == "" ]; then 
# Update duplicated loop dictionary
echo "${loopFileName%.*}:${1}" >> $LOOP_DICT
else
newName="${loopDir}/${loopId}.csv"
vEcho "newName: $newName"
vEcho "currentName: $2"
if [ "$2" != "$newName" ]; then # Just in case moving file to self
mv "$2" "$newName"
fi
fi

} #GroupSameLoops

# Main

for dataDir in $(ls -d ${1}/*/DATA/*/); do
echo "data dir $dataDir"
 for loopFile in $(ls $dataDir); do
  # Add the full path
  loopFile="${dataDir}$loopFile"
  # file could be deleted, so check existence first
  if ! [ -f $loopFile ]; then 
   continue 
  fi

   echo $loopFile
   # Get loop source from last column
   loopSource=$(tail -n 1 $loopFile | awk -F "," '{print $NF}');
   #echo $loopSource
   # Create a global name reference for loops that have the same source 
   GroupSameLoops "$loopSource" "$loopFile"
  done
done
