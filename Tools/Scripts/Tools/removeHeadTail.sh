#!/bin/bash
if [ "$#" -ne "2" ] 
then
echo "Usage: script TraceFile outDir";
fi 

#loopInsCount.data.rmHeadTail

outFile="$(basename $1).rmHeadTail";
echo "outFile:$outFile";
# Retain the header
head -n1 $1 > $2/${outFile};

# 1234:ppid(pid)2420 (2421)
# Find first ppid, record its line number
# Find second ppid, record it line number, if different, remove the content in between
# Find the third ppid and reuse the first ppid variable, compare with the second ppid variable, if differet, delete content in between
# When reaching the tail, check the last comparison result, 
#if different, delete everything up to the tail, if not different, keep till the tail.
# grep -E "^[^,]+,[^,]+,[0-9]+,2," -in -m 1
#to get just the number part from grep:"  cut -d: -f1" 
ppidRegex="^([0-9]+):ppid\(pid\)([0-9]+)";
bFirst=1;
bLastTimeEqual=0;
for line in $(grep -E "ppid\(pid\)[0-9]+ \([0-9]+\)" -in $1)
do 
echo "${line}";
if [[ $line =~ $ppidRegex ]]
then 
lineNum=${BASH_REMATCH[1]};
ppid=${BASH_REMATCH[2]};
#echo "line number: $lineNum";
#echo "ppid: $ppid";

# Initialization
if [ "$bFirst" -eq "1" ]; then
oldPpid=${ppid};
startLine=${lineNum};
endLine=${lineNum};
bFirst=0;
continue;
fi

# The goal is to only keep the trace files that have the same PPID
if [ "$oldPpid" -ne "$ppid" ]
then
if [ "$bLastTimeEqual" -eq "1" ]
then
# Update end line
endLine=$((lineNum-1));
# In a given instance, the ppid should remain unchanged. 
# Thus group traces by the same ppid
echo "keep between ${startLine} and ${endLine}"; 
sed -n "${startLine},${endLine}p" $1 >> $2/${outFile}
bLastTimeEqual=0;
else # "$bLastTimeEqual" -eq "1"
# Update start line
startLine=${lineNum};
fi # $bLastTimeEqual

else # if [ "$oldPpid" -ne "$ppid" ]
bLastTimeEqual=1;
fi

oldPpid=${ppid};
fi # ppidRegex
done
