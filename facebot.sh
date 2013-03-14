#!/bin/bash
Master="jan"
Server="irc.rizon.net"
Ident="o_o"
Ircname="O_o o.o"
Chanfile="./channels" ## example "chanfile": echo '#channel1 #channel2' > /tmp/chanells
Regexfile="./regex"   ## 
Regexes=`cat "$Regexfile"`
Channels=`cat "$Chanfile"`
Nick="o__0"
Network="" ## identifier *in case* you're running the bot multiple times

echo "" > /dev/shm/facebotreset$Network
i=0

reloadregex() {
	Regexes=`cat "$Regexfile"`
	echo "PRIVMSG $channel :Regex reloaded"
}

reloadtest() {
	echo "PRIVMSG $channel :TEST"
}

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
	if line=`echo "$input" | awk -F: '{OFS=":"; $1=$2=""; print}' | cut -c 3- | egrep -owi "$Regexes"`; then
		if [ $i -lt 4 ]; then
			echo "PRIVMSG $channel :$line"
			((i++))
			if [[ $lock != 1 && $(</dev/shm/facebotreset) != "reset" ]]; then
				lock=1
				(sleep 12; echo "reset" > /dev/shm/facebotreset$Network) &
			fi
		elif [ $i -lt 8 ]; then
			sleep 0.5 && echo "PRIVMSG $channel :$line"
			((i++))
		fi
		if [[ "$(</dev/shm/facebotreset$Network)" == "reset" ]]; then
			i=0
			lock=0
			echo "" > /dev/shm/facebotreset$Network
		fi ## Hacked in flood limit ^^
	fi

	if mastercmd=`echo $input | awk -v master="^:$Master" 'tolower($1) ~ master && $4 == ":?reload" { print $5; f=1 } END {exit !f}'`; then
		case "$mastercmd" in
			regex)    reloadregex;;
			chans)    reloadchans;;
			quit)     reloadquit;;
			newchans) newchans;;
			list)     echo "PRIVMSG $channel :regex chans newchans test quit";;
			test)     reloadtest;;
		esac
	elif addchannel=`echo $input | awk -v master="^:$Master" 'tolower($1) ~ master && $4 == ":?addchan" { print $5; f=1 } END {exit !f}'`; then
		sed -i "s/$/& ${addchannel//\//\\/}/" $Chanfile
		sed -i "s/  / /g" $Chanfile
		echo "JOIN $addchannel"
	elif delchannel=`echo $input | awk -v master="^:$Master" 'tolower($1) ~ master && $4 == ":?delchan" { print $5; f=1 } END {exit !f}'`; then
		sed -i "s/${delchannel//\//\\/}//" $Chanfile
		sed -i "s/  / /g" $Chanfile
		echo "PART $delchannel"
	
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
