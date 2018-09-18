#/bin/bash
if [ $# -ne 2 ]; then
	echo "Usage: groupWeightFiles.sh reportFile outDir"
	exit 1
fi

source globalVar.sh
bFirst=0
while IFS='' read -r line || [[ -n "$line" ]]; do
	#echo $line
	if [ "$bFirst" == "0" ]; then
		lastGroup=$(GetHeaderNameByInd 1 $line)
		bFirst=1
	fi
	group=$(GetHeaderNameByInd 1 $line)

	if [ "$group" != "$lastGroup" ]; then
		# Get directory name
		dir=$lastGroup
		out="${2}/${dir}"
		mkdir -p "$out"
		mv wgFile ${out}
		echo $line >> wgFile
	else	
		echo $line >> wgFile
	fi
	lastGroup=$(GetHeaderNameByInd 1 $line)
done < <(sort -t, -k2 "$1")

out="${2}/${lastGroup}"
mkdir -p "$out"
mv wgFile ${out}
