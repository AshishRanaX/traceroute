#!/bin/bash
tgt=$1


#COMMANDNAME_SWITCHES are used along each COMMANDNAME, this is portability (to test if different switches work on current machine)
#init_COMMANDNAME_switches will be called at the start of the script and fill COMMANDNAME_SWITCHES
#these switches are currently assumed to work for ping: -c
#switches that will be used if availbale: -A
PING_SWITCHES=""

#assumed global variables typically to test things when an actual valid one is not availbale
ASSUMED_RELIABLE_IP="127.0.0.1"

function init_ping_switches {
		#-A Adaptive ping
		if ping -c 1 -A $ASSUMED_RELIABLE_IP >$REDIRECT_DEST;then
				PING_SWITCHES=$PING_SWITCHES" -A "
		fi
}

ping $PING_SWITCHES -c 4 $tgt > /dev/null
if [[ $? -ne 0 ]];then
	echo "[*] Not able to ping $tgt"
	exit 0
fi
echo [*] $tgt is alive.

rcv_ttl=$(ping $PING_SWITCHES -c 2 $tgt | grep -i ttl|  cut -d ' ' -f 7 | cut -d '=' -f 2 | head -1)
if [[ $rcv_ttl -gt 64 ]];then
	hops=$(expr 128 - $rcv_ttl)
else
	hops=$(expr 64 - $rcv_ttl)
fi
echo [*] $tgt is at $hops hops

route=$(mktemp)

for i in $(seq 1 $hops);do
	try=3
	while [[ $try -gt 0 ]];do
		echo ''
		echo -n "hop $i"
		ping $PING_SWITCHES -c 2 -t $i $tgt  > $route
		if [[ $(cat $route | grep -i "bytes from" | wc -l) -gt 0 ]];then
			echo [*] $tgt reached.
			exit 0
		fi
		if [[ $(cat $route | grep -i "Time to live exceeded" | wc -l) -gt 1 ]];then

			postition=$(cat $route | grep -i "Time to live exceeded" |  head -1 | grep -b -o icmp_seq | cut -d : -f 1)
			cat $route  | grep -i "Time to live exceeded" | head -1 | cut -c 5-$postition
			break
		fi
		try=$(expr $try - 1)
	done
	if [[ $try -eq 0 ]];then
		echo " * * *"
	fi
done
rm $route
