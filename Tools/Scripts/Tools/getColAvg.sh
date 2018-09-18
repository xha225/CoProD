#!/bin/bash
if [ $# -ne 2 ]; then
echo "Usage: script columnInd fileLocation"
exit 1
fi
columnInd=$1
#echo $columnInd
# -v is used to assign the column id, so that it does not have to be static 
awk -F, -v colInd="$columnInd" '{ total += $colInd } END { print total/NR }' $2
