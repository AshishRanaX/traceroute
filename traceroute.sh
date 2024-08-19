#!/bin/bash
TARGET=""


HELP="\
traceroute\\n\
Options:\n\
\t-p PING_OPTION=VALUE,..\tpass arbitrary switches to pings used in the script, seperated by ',' and wrappen in double qoutes '\"'\n\
\t\treserved switches: (-A, -c) there are other switches to set arbitrary value for -c, -W\n\
Usage Examples:\n\
\t$0 -p \"-t=64,-r\" google.com\tput -t 64 -r before other ping switches
"

REDIRECT_DEST="/dev/null"

PING_COUNT=2
TRACE_TRIES=1

#COMMANDNAME_SWITCHES are used along each COMMANDNAME, this is portability (to test if different switches work on current machine)
#init_COMMANDNAME_switches will be called at the start of the script and fill COMMANDNAME_SWITCHES
#these switches are currently assumed to work for ping: -c
#switches that will be used if availbale: -A
PING_SWITCHES=""

#assumed global variables typically to test things when an actual valid one is not availbale
ASSUMED_RELIABLE_IP="127.0.0.1"

function handle_args {

		while getopts "hp:c:" name;do
					case $name in
					h)
							echo -e $HELP
							exit 1;;
					p) 		
							PING_SWITCHES=$(echo $OPTARG | tr '=' ' ' | tr ',' ' ');;
					c) 		
							PING_COUNT=$OPTARG;;
					?)    
							echo -e $HELP
							exit 1;;
					esac
		done

		# Shift processed options away
		shift $((OPTIND -1))

		TARGET=$1
		
		if [ -z $TARGET ];then
				echo  no target provided
				exit 1 	
		fi
}

function init_ping_switches {
		#-A Adaptive ping
		if ping -c 1 -A $ASSUMED_RELIABLE_IP >&$REDIRECT_DEST;then
				PING_SWITCHES=$PING_SWITCHES" -A "
		fi
}



handle_args $@
init_ping_switches

ping $PING_SWITCHES -c $PING_COUNT $TARGET >&$REDIRECT_DEST
if [[ $? -ne 0 ]];then
	echo "[*] Not able to ping $TARGET"
	exit 1
fi
echo [*] $TARGET is alive.

rcv_ttl=$(ping $PING_SWITCHES -c $PING_COUNT $TARGET | grep -i ttl|  cut -d ' ' -f 7 | cut -d '=' -f 2 | head -1)
if [[ $rcv_ttl -gt 64 ]];then
	hops=$(expr 128 - $rcv_ttl)
else
	hops=$(expr 64 - $rcv_ttl)
fi
echo [*] $TARGET is at $hops hops

route=$(mktemp)


old_trace_tries=$TRACE_TRIES
for i in $(seq 1 $hops);do
	TRACE_TRIES=$old_trace_tries
	while [[ $TRACE_TRIES -gt 0 ]];do
		echo ''
		echo -n "hop $i"
		ping $PING_SWITCHES -c $PING_COUNT -t $i $TARGET  > $route
		if [[ $(cat $route | grep -i "bytes from" | wc -l) -gt 0 ]];then
			echo [*] $TARGET reached.
			exit 0
		fi
		if [[ $(cat $route | grep -i "Time to live exceeded" | wc -l) -gt 1 ]];then

			postition=$(cat $route | grep -i "Time to live exceeded" |  head -1 | grep -b -o icmp_seq | cut -d : -f 1)
			cat $route  | grep -i "Time to live exceeded" | head -1 | cut -c 5-$postition
			break
		fi
		TRACE_TRIES=$(expr $TRACE_TRIES - 1)
	done
	if [[ $TRACE_TRIES -eq 0 ]];then
		echo " * * *"
	fi
done
rm $route
