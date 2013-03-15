#!/bin/bash
Master="jan"
Server="irc.rizon.net"
Ident="o_o"
Ircname="O_o o.o"
Chanfile="./channels" ## example "chanfile": echo '#channel1 #channel2' > /tmp/channels
Regexfile="./regex"   ## 
Channels=`cat "$Chanfile"`
Nick="o__0"
Network="f g" ## identifier incase you're running the bot multiple times

echo "" > "/dev/shm/facebotreset$Network"
i=0

reloadchans() {
	echo "JOIN 0"
	Channels=`cat "$Chanfile"`
	for chan in ${Channels[@]}; do echo "JOIN $chan"; sleep 0.1; done
}

newchans() {
	Channels=`cat "$Chanfile"`
	for chan in ${Channels[@]}; do echo "JOIN $chan"; sleep 0.1; done
	echo "PRIVMSG $channel :Joined new channels"
}	

reloadquit() {
	echo "QUIT bye"
	exit 0
}

while :; do {

echo "USER $Ident 0 1 :$Ircname"
echo "NICK $Nick"
echo "MODE $Nick +gp"
sleep 1

for chan in ${Channels[@]}; do echo "JOIN $chan"; done

trap 'reloadbot' HUP

while read input; do
if `echo $input | awk '$2 == "PRIVMSG" { f=1 } END { exit !f }'`; then

	input=`echo "$input" | tr -d '\r\n'`
	channel=`echo "$input" | awk '{OFS=":"; print $3}'`

	if echo $input | awk -v master="^:$Master" 'tolower($1) ~ master && $4 ~ /^:\?/ { f=1 } END {exit !f}'; then
		if mastercmd=`echo $input | awk '$4 == ":?cmd" { print $5; f=1 } END {exit !f}'`; then
			case "$mastercmd" in
				quit)     reloadquit;;
				raw)      echo "$(echo $input | awk '{$1=$2=$3=$4=$5=""; print}' | cut -c 6-)";;
				list)     echo "PRIVMSG $channel :COMMANDS: [chan: add, del] [regex: add, del] [reload: chans, newchans, config] [cmd: raw, quit, test, list] ";;
				test)     echo "PRIVMSG $channel :TEST";;
			esac
		elif echo $input | awk '$4 == ":?reload" { f=1 } END {exit !f}'; then
			reloadarg=`echo $input | awk '{ print $5}'`
			case "$reloadarg" in
				chans)		reloadchans;;
				newchans)	newchans;;
				config)		echo "PRIVMSG $channel :Not yet implemented, sorry.";;
			esac
		elif chancmd=`echo $input | awk '$4 == ":?chan" { print $5; f=1 } END {exit !f}'`; then
			chanarg=`echo $input | awk '{ print $6}'`
			case "$chancmd" in
				add) 
					sed -i "s/$/& ${chanarg//\//\\/}/" $Chanfile
					sed -i "s/  / /g" $Chanfile
					echo "JOIN $chanarg"
					;;
				del)
					sed -i "s/${chanarg//\//\\/}//" $Chanfile
					sed -i "s/  / /g" $Chanfile
					echo "PART $chanarg"
					;;
			esac
		elif regexcmd=`echo $input | awk '$4 == ":?regex" { print $5; f=1 } END {exit !f}'`; then
			regexarg=`echo $input | awk '{$1=$2=$3=$4=$5=""; print}' | cut -c 6-`
			case "$regexcmd" in
				add)
					echo $regexarg >> $Regexfile;;
					#echo "PRIVMSG $channel :This feature is experimental, please check results after use and try not to use complicated regexes with it";;
				del)
					sed -i s/$regexarg// $Regexfile
					sed -i -n "s/^$//;t;p;" $Regexfile
					#echo "PRIVMSG $channel :This feature is experimental, please check results after use and try not to use complicated regexes with it";;
			esac	
		fi
	elif line=`echo "$input" | awk -F: '{OFS=":"; $1=$2=""; print}' | cut -c 3- | egrep -owif "$Regexfile"`; then
		if [ $i -lt 4 ]; then
			echo "PRIVMSG $channel :$line"
			((i++))
			if [[ $lock != 1 && $(<"/dev/shm/facebotreset$Network") != "reset" ]]; then
				lock=1
				(sleep 12; echo "reset" > "/dev/shm/facebotreset$Network") &
			fi
		elif [ $i -lt 8 ]; then
			sleep 0.5 && echo "PRIVMSG $channel :$line"
			((i++))
		fi
		if [[ $(<"/dev/shm/facebotreset$Network") == "reset" ]]; then
			i=0
			lock=0
			echo "" > "/dev/shm/facebotreset$Network"
		fi ## Hacked in flood limit ^^
	fi
fi

	## Pingpong ## FIX THIS LATER
	ping=`echo "$input" | cut -d " " -f1`
	if [ "$ping" = "PING" ]; then
		data=`echo "$input" | cut -d " " -f 2-`
		echo "PONG $data"
		continue
	fi
done

} <> /dev/tcp/$Server/6667 >&0

sleep 5
done
