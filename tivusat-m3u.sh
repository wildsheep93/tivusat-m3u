#!/bin/bash

host="minisatip" # minisatip host
output="/usr/share/minisatip/html/tivusat.m3u8" # Output m3u
port=554 # RTSP port
hport=8080 # HTTP port
rfreq=10992 # Reference transponder frequency
rpol="v" # Reference transponder polarization
rsym=27500 # Reference transponder symbol rate
rmsys="dvbs&mtype=qpsk" # Reference transpoder Delivery System and Modulation
max_retries=5 # number of tries for NIT and SDT fetching

cd /run/tivusat-m3u

if [ ! -f $output ]; then
	echo No reference M3U downloading tables...
	echo "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pid=16" 
	timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=16&msys=$rmsys" > nit.ts
	sleep 30
#	timeout 10  curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pid=16" > nit.ts
#	echo "http://$host:8080/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pid=16" 
	timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=17&msys=$rmsys" > sdt.ts
	sleep 30
#	echo "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pid=17"
	tstables --default-pds EACEM nit.ts | grep -E 'Transport Stream Id:|Frequency:|Polarization:|Delivery system:|Modulation:|Symbol rate:|Inner FEC:|Service Id:' > nit.txt
	echo NIT Count: $( grep -c 'Service Id:' nit.txt )
	tstables sdt.ts | grep -E 'Transport Stream Id:|Service Id:|Service:' > sdt.txt
	echo SDT Count: $( grep -c 'Service:' sdt.txt )
else
	retry=1
	nm3u=$(grep -cE '^#EXTINF:-1' $output)
	while (( $retry < $max_retries )); do
		timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=16&msys=$rmsys" > nit.ts
		sleep 30
#		echo "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pid=16" 
		nnit=$(tstables --default-pds EACEM nit.ts | grep -c 'Service Id:')
		if (( ${nnit} - ${nm3u} <= 5 && ${nm3u} - ${nnit} <= 5 )); then
		      echo NEW NIT OK...
		      echo NIT Count: "$nnit" vs. old "$nm3u"
		      tstables --default-pds EACEM nit.ts | grep -E 'Transport Stream Id:|Frequency:|Polarization:|Delivery system:|Modulation:|Symbol rate:|Inner FEC:|Service Id:' > nit.txt
		      break
	        else
		      echo -e "\nNIT Not OK... Downloading new one"
		      timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=16&msys=$rmsys" > nit.ts
		      sleep 30
		      nnit=$(tstables --default-pds EACEM nit.ts | grep -c 'Service Id:')
		      retry=$((retry+1))
		      continue
		fi
	done
	if (( $retry == $max_retries )); then
		echo Too many tentatives... exiting
		exit 1
	fi
	retry=1
	while (( $retry < $max_retries )); do
		timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=17&msys=$rmsys" > sdt.ts
		sleep 30
		nsdt=$(tstables sdt.ts | grep -c 'Service:')
		if (( ${nsdt} - ${nm3u} <= 5 && ${nm3u} - ${nsdt} <= 5 )); then
		      echo NEW SDT OK...
		      echo -e "\nSDT Count: "$nsdt" vs. old "$nm3u""
		      tstables sdt.ts | grep -E 'Transport Stream Id:|Service Id:|Service:' > sdt.txt
		      break
		else
		      echo SDT Not OK... Downloading new one
		      nnit=$(tstables --default-pds EACEM nit.ts | grep -c 'Service Id:')
		      timeout 20 curl "http://$host:$hport/?src=3&freq=$rfreq&pol=$rpol&sr=$rsym&pids=17&msys=$rmsys" > sdt.ts
		      sleep 30
		      nsdt=$(tstables sdt.ts | grep -c 'Service:')
		      retry=$((retry+1))
		      continue
		fi
	done
	if (( $retry == $max_retries )); then
		echo Too many tentatives... exiting
		exit 1
	fi
fi
> channels.txt
while IFS= read -r line; do
	if [[ $line =~ Transport\ Stream\ Id:\ 0x[0-9a-fA-F]+\ \(([0-9]+)\) ]]; then
		tsid="${BASH_REMATCH[1]}"
		> lcn.txt
		match="$line"
		while IFS= read -r nline; do
			if [[ $nline =~ Transport\ Stream\ Id:\ 0x[0-9a-fA-F]+\ \(([0-9]+)\).* ]]; then
				ntsid="${BASH_REMATCH[1]}"
				continue
			fi
			
			if [[ $nline =~ Frequency:\ ([0-9]{2})\.([0-9]{3}).* ]] && [[ $ntsid = $tsid ]] ; then
				freq="${BASH_REMATCH[1]}""${BASH_REMATCH[2]}"
		       		continue
			fi		

			if [[ $nline =~ Polarization:.*\(([0-9])\) ]] && [[ $ntsid = $tsid ]] ; then
				case "${BASH_REMATCH[1]}" in
					0) pol="h" ;;
					1) pol="v" ;;
					2) pol="l" ;;
					3) pol="r" ;;
				esac
				continue
			fi

			if [[ $nline =~ Delivery\ system:\ (.*)-(.*) ]] && [[ $ntsid = $tsid ]] ; then
				del="${BASH_REMATCH[1]}""${BASH_REMATCH[2]}"
				continue
			fi

			if [[ $nline =~ Modulation: ]] && [[ $ntsid = $tsid ]] ; then
#				echo "${BASH_REMATCH[0]}"
#				echo "${BASH_REMATCH[1]}""${BASH_REMATCH[2]}" 
				mmod=$( echo "$nline" | grep -o \([0-9]\) | xargs | tr -d ' ()' )
				case $mmod in
					1) mod="qpsk" ;;
					20) mod="8psk&ro=0.35" ;;
					21) mod="8psk&ro=0.25" ;;
					22) mod="8psk&ro=0.30" ;;
				esac
				continue
			fi
			if [[ $nline =~ Symbol\ rate:\ ([0-9]{2})\.([0-9]{3})[0-9] ]] && [[ $ntsid = $tsid ]] ; then
				sym="${BASH_REMATCH[1]}""${BASH_REMATCH[2]}"
				continue
			fi
			
			if [[ $nline =~ Inner\ FEC:\ .*\ \(([0-9])\) ]] && [[ $ntsid = $tsid ]] ; then
				case "${BASH_REMATCH[1]}" in
					0) fec="0" ;;
					1) fec="12" ;;
					2) fec="23" ;;
					3) fec="34" ;;
					4) fec="56" ;;
					5) fec="78" ;;
					6) fec="89" ;;
					7) fec="35" ;;
					8) fec="45" ;;
					9) fec="910" ;;
				esac
			 	timeout 25 curl "http://$host:$hport/?src=3&freq=$freq&pol=$pol&msys=$del&mtype=$mod&plts=on&sr=$sym&fec=$fec&pids=0" > pat.ts
				sleep 30
#			 	echo "http://$host:$hport/?src=3&freq=$freq&pol=$pol&msys=$del&mtype=$mod&plts=on&sr=$sym&fec=$fec&pids=0"
				echo -e "\n$tsid"
				pids=$( tstables pat.ts | grep Program: | tr -s ' ' | cut -d ' ' -f 6 | xargs | sed 's/ /,/g' )
				tstables pat.ts | grep Program: | tr -s ' ' | cut --output-delimiter="|" -d ' ' -f 3,6 > pat.txt
#				echo "$pids"
			 	timeout 25 curl "http://$host:$hport/?src=3&freq=$freq&pol=$pol&msys=$del&mtype=$mod&plts=on&sr=$sym&fec=$fec&pids=$pids" > pmt.ts
				fi
			if [[ $nline =~ Service[[:space:]]Id:[[:space:]]+([0-9]+)[[:space:]]\(0x[0-9a-fA-F]+\),[[:space:]]+Visible:[[:space:]]1,[[:space:]]Channel[[:space:]]number:[[:space:]]+([0-9]+) ]] && [[ $ntsid = $tsid ]] ; then
				echo ""${BASH_REMATCH[1]}"|"${BASH_REMATCH[2]}"" >> lcn.txt
				continue
			fi
		done < nit.txt
		continue
	fi
	
	if [[ $line =~ (Service\ Id:)\ (0x[0-9A-Fa-f]+)\ \(([0-9]+)\) ]]; then
		sid="${BASH_REMATCH[3]}"
		nr=$( grep -w "$sid" lcn.txt | cut -d '|' -f 2 )
#		echo 1 "${BASH_REMATCH[1]}"
#		echo 3 "${BASH_REMATCH[3]}"
#		echo 2 "${BASH_REMATCH[2]}"
		count=$(tstables --default-pds EACEM nit.ts | grep -cE "${BASH_REMATCH[1]}"[[:space:]]+"${BASH_REMATCH[3]}"[[:space:]])
	fi
	
	read -r nextline

	if [[ $nextline =~ ^Service:\ \"([^\"]+)\" ]]; then
		ser="${BASH_REMATCH[1]}"
		pmt=$( grep -w "$sid" pat.txt | cut -d '|' -f 2 )
		[ -z $pmt ] && continue
		pids=$( echo "$pmt" | xargs -I _ tstables -p _ pmt.ts | grep 'Elementary stream:' | grep -oE '\([0-9]+\)$' | tr -d \(\) | xargs | sed 's/ /,/g' )
		echo "$pids" 
#		echo "$(printf "%03d %s\n" "$nr" "$text") "$ser" http://"$host":8080/?src=3&freq="$freq"&pol="$pol"&msys="$del"&mtype="$mod"&plts=on&sr="$sym"&fec="$fec"&sid="$sid" "$count""
		echo ""$nr"|"$ser"|"$sid"|"$freq"|"$pol"|"$del"|"$mod"|"$sym"|"$fec"|"$pids"" >> channels.txt
#		echo "$nr" "$ser" "http://"$host":8080/?src=3&freq="$freq"&pol="$pol"&msys="$del"&mtype="$mod"&plts=on&sr="$sym"&fec="$fec"&sid="$sid""
	fi
done < sdt.txt

echo "#EXTM3U" > "$output"
while IFS='|' read -r nr ser sid freq pol del mod sym fec pids; do
			 echo "#EXTINF:-1,$nr $ser" >> "$output"
			 echo "rtsp://$host:$port/?src=3&freq=$freq&pol=$pol&msys=$del&mtype=$mod&plts=on&sr=$sym&fec=$fec&pids=$pids" >> "$output"
			 echo "$host" "$port" "$freq" "$pol" "$del" "$mod" "$sym" "$fec" "$pids" 
done < <(sort -n channels.txt)
