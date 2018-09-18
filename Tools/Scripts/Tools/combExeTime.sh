#/bin/bash
# This script is used to add ExeTime from both SysCall and Loops
if [ $# -ne 1 ]; then
	echo "Usage: combExeTime.sh BaseDirToLoop"
	exit 1
fi
source globalVar.sh
bVerbose=0

loopWeightsDir="$1/LoopWeightGroups"
sysCallWeightsDir="$1/SysCallWeightGroups"
combEtWeightsGroup="$1/CombETWeightGroups"
mkdir -p $combEtWeightsGroup

for dir in $(ls -d $loopWeightsDir/*/)
do
	#echo $dir
	while IFS='' read -r line || [[ -n "$line" ]]; do
		# KeepAliveTimeout,1-2-3,0.0
		#echo $line
		# Todo: find the counterpart in SysCallWeightGroups
		IFS=',' read -ra valArray <<< "$line"
		key="${valArray[0]},${valArray[1]}"
		val=${valArray[2]}

		vEcho "key=$key, val=$val"
		# Value from SysCall
		grepFile="${sysCallWeightsDir}/$(basename $dir)/wgFile"
		#echo "grepKey=$key, grepFile=$grepFile"
		val2=$(grep "$key" "${grepFile}" | cut -d, -f3)
		vEcho "val2=$val2"
		# Todo: output to CombETWeightGroups
		outVal=$(echo "scale=0;$val + $val2" | bc)
		vEcho "outVal=$outVal"
		outDir="$combEtWeightsGroup/$(basename $dir)/"
		mkdir -p $outDir
		echo "$key,$outVal" >> "$outDir/wgFile"

	done < <(sort -t, -k2 "$dir/wgFile")
done
