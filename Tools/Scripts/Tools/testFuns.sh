#!/bin/bash

function TestRestart {
	apacheRestartPid=$($sudoCmd ${HTTPD_BIN_ROOT}"apachectl" -k graceful & echo $!)
	isRestartFinished=$(ps --pid ${apacheRestartPid} -o pid= | wc -l)
	if [ "$isRestartFinished" -eq 0 ]
	then
		echo "Restart finished"
	else
		sleep 0.5s && vEcho "Sleep 0.5s"
	fi # Check apache restart
}

function TestPageRequest {
	wget ${WebServerUrlTest} && echo "Getting $WebServerUrlTest"
} # TestPageRequest

function TestAbRequest {
	/home/author/PlayGround/httpd-2.2.2/INSTALL/bin/ab -n 20 -c 4 http://192.168.56.101:50001/index.html	
} # TestAbRequest


function TestDeflate {
	echo "TestDeflate"
	curl -I -H 'Accept-Encoding: gzip,deflate' $WebServerUrlTest
} # TestDeflate

# $1: process id
# $2: a kill method
function WaitProc {
	sleepTime="2.5s"
	vEcho "In WaitProc()..."
	# tr is used to delete the trailing newline
	exist=$(ps --pid $1 -o pid= | wc -l | tr -d "\n")
	vEcho "exist = ${exist}"
	max=0

	while [ "$exist" -ne "0" ]
	do
		if [ $max == 0 ]; then
			echo -n "Sleeping"
		fi

		eval $2  && vEcho "issued $2" # Try the kill method
		sleep $sleepTime && echo -n "." 
		exist=$(ps --pid $1 -o pid= | wc -l | tr -d "\n")
		#ps --pid $1
		#ps --ppid $1
		((max++))

		# Try 20 times and returns
		if [ "${max}" -gt "20" ]
		then
			echo "Timedout: wait process $1"
			echo "Current dir is: $(pwd)"
			return 1
		fi

	done # while

	echo # Start a newline
	return 0
} # WaitProc

function WaitIfNoApachePidFile {
	vEcho "WaitIfNoApachePidFile"
	breakWhile=0
	while ! [ -f ${HTTPD_PID_FILE} ]
	do
		# Wait for 0.5 seconds
		sleep 0.5s
		((breakWhile++))
		if [ "$breakWhile" -eq "20" ]
		then
			# Wait 10 seconds then quit
			break
		fi
	done
}

# In case apache is not shut down fast enough to remove the pid file
# If we try to start Apache at this time, it would complaint about not 
# being able to bind the port
function WaitIfApachePidFileExist {
	breakWhile=0
	while [ -f ${HTTPD_PID_FILE} ]
	do
		sleep 0.5s
		((breakWhile++))
		# Wait for at most 10 seconds
		if [ "$breakWhile" -eq "20" ]
		then
			break
		fi
	done
}

# Function $1: modified config file path
# $2: configuration value 
# $3: configuration name
function RunTest {
	STARTTIME=$(date +%s)
	vEcho "Config file path: $1"
	vEcho "Config value: $2"
	vEcho "Config name: $3"
	vEcho "Test id: $4"
	vEcho "Test Case: $5"

	# Copy modified configuration back to INSTALL/conf
	if [ "$1" != "SKIPCOPY" ]; then	
		cp $1 ${CONFIG_DIR} && vEcho "Copy $1 to ${CONFIG_DIR}"
	fi

	# Check if Apache is running
	WaitIfApachePidFileExist
	if ! [ -f ${HTTPD_PID_FILE} ]
	then
		# Call pin
		currentDir=$(pwd) && vEcho "currentDir: ${currentDir}"
		if [ ! -d ${RAW_DATA_DIR} ]; then
			mkdir ${RAW_DATA_DIR} && vEcho "***Created ${RAW_DATA_DIR}"
		fi
		#	cd ${HARNESS_DIR}; 
		#$sudoCmd	${PIN_BIN} -t ${PIN_PLUGIN} -testId $4 -ConfigName $3 -ConfigVal $2 -outDir $1 -- ${HTTPD_BIN};
		$sudoCmd	${PIN_BIN} -t ${PIN_PLUGIN} -testId $4 -ConfigName $3 -ConfigVal $2 -SourceFilter ${G_S_FILTER} -- ${HTTPD_BIN};
		sleep 1; # Necessary for Apache to write to the PID file
		#		cd ${currentDir};
		#$sudoCmd ${HTTPD_BIN} && echo "Starting Apache";
		bSkipTest=false;
	else
		cat ${HTTPD_PID_FILE};
		bSkipTest=true;
	fi;

	if [ "${bSkipTest}" == "false" ]
	then
		ApachePid=$(cat ${HTTPD_PID_FILE} | tr -d "\n" )

		vEcho "Apache ID::${ApachePid}"

		# Make sure Apache has processes to serve
		vEcho $(ps --ppid ${ApachePid} -o pid=)
		ApacheOn=$(ps --ppid ${ApachePid} -o pid= | wc -l)
		if [ "$ApacheOn" -gt "0" ]
		then
			vEcho "Num of Apache daemons: $ApacheOn"
			# Run tests
			for i in $(seq 1 1 $G_TEST_REPEAT_TIMES)
			do
				$5
			done
		else
			echo "No HTTPD process to server requests"
		fi # if $ApacheOn
	fi # if bSkipTest

	# stop program
	WaitIfNoApachePidFile 
	if [ -f ${HTTPD_PID_FILE} ]
	then
		#apacheShutPid=$($sudoCmd ${HTTPD_BIN} -k stop & echo $!)
		$sudoCmd ${HTTPD_BIN} -k stop && echo "Stop issued"
	else
		echo "Cannot find ${HTTPD_PID_FILE}"
		echo "Does that mean no apache process is running?? hmmm.. let's try"
		ps alx | grep httpd
	fi
	WaitProc ${ApachePid} "$sudoCmd ${HTTPD_BIN} -k stop"
	rtnStatus=$?
	#echo "return status: ${rtnStatus}"
	if [ "$rtnStatus" -eq "0" ]
	then
		printf "Shut down succeed \n\n"
	else
		printf "!!Failed shut down\n\n"
		ps alx | grep httpd
	fi

	if [ -e ${HTTPD_PID_FILE} ]; then
		rm ${HTTPD_PID_FILE}
	fi	
} #RunTest
