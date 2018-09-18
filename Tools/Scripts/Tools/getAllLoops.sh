#!/bin/bash
# This script is used to gather all the loops apeared in the trace file
if [ $# -ne 3 ]; then
echo "Usage: script 1.fullLoopSetOutFileName 2.testId 3.ConfInterDir"
exit 1
fi 

function isItemInFile {
# $1 item to insert
# $2 collection to be insert into
item=$1
file=$2
grep -xc $item $file
} #isItemInFile

source globalVar.sh 
tempFile=loopSet
# Create empty temp file for sort
>"$1"

# Look through all loops in a given test folder
for configDir in $(ls -d ${3}/*/);do
loopDir="${configDir}/DATA/T${2}"
outFile="${configDir}/DATA/$(basename ${configDir}).${tempFile}${2}"

ls ${loopDir} > $outFile
sort -u $1 $outFile -o $1
done
