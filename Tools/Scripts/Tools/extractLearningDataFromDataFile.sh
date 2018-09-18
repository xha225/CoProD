#!/bin/bash
if [ "$#" -ne 2 ] 
then
echo "Usage: script dataFile outDir";
exit 1;
fi

# Create data folder
dataDirName=$2;
isHeader=0;
headerLine=$(head -n 1 $1);

[ -d "$dataDirName" ] || { mkdir -p $dataDirName && echo "Created directory $dataDirName"; }
# Sort original data file by function name
# and pass it through piping to the while loop
LC_ALL=C sort -t , -k 1 $1 | \
# Loop through data and generate one data file for each function/routine
	while IFS='' read -r line || [[ -n "$line" ]]; 
	do

# Skip other header lines
	if [[ $headerLine =~ $line ]]; then
	continue;
	fi

# Get function/routine name
	funName=$(echo $line | awk -F "," '{print $1}');
	fileName="${dataDirName}/${funName}.csv";
# Verify if function name has changed since last line
	if [ "$lastFunName" == "$funName" ]
	then
	echo $line >> "$fileName";
	else
# Create individual data file
	if ! [ -e "$fileName" ] # File does NOT exist
	then
	echo $headerLine >> "$fileName";
	fi # File does not exist
	echo $line >> "$fileName";
	fi
# Create a data file for each function name    
#echo ${funName}
	lastFunName=$funName;		
	done 

