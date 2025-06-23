#!/bin/bash

# InfluxDB Configuration

API_KEY="Enter api key"
MONSTER_HOST="Influx url"

# Asking user to enter the url
read -p "Enter the URL: " URL

# Asking user to enter the token
read -p "Enter the X-DataDirect-Auth-Token: " TOKEN

# Asking user how many simultaneous connections they want to run
read -p "How many simultaneous connection you would like to run? " CONNECTION

# Creating a directory where simultaneous result will be stored
mkdir -p curl_results

echo
echo "=====Starting Diagnostics (Running $CONNECTION parallel connections) ======="

for ((i=1; i<=CONNECTION; i++)); do
    (
        result=$(curl -k -H "X-DataDirect-Auth-Token: $TOKEN" -o /dev/null -s -S -w "\
%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{speed_download}" "$URL")

        echo "$result" > curl_results/result_$i.txt
    ) &
done

# Wait for all background jobs to finish
wait

echo
echo "====== Results Summary ======"

for ((i=1; i<=CONNECTION; i++)); do
    if [[ -f curl_results/result_$i.txt ]]; then
        read dns connect tls start total speed < curl_results/result_$i.txt

        echo
        echo "======= Result #$i ======="
        echo "DNS Lookup:        ${dns}s"
        echo "TCP Connect:       ${connect}s"
        echo "TLS Handshake:     ${tls}s"
        echo "Start Transfer:    ${start}s"
        echo "Total Time:        ${total}s"
        echo "Download Speed:    $speed bytes/sec"

        # formatting data in line protocol
        TIMESTAMP=$(date +%s%N)
        LINE="curl_metrics,connection_id=$i url=$(echo "$URL" | sed 's/,/_/g') \
dns=${dns},connect=${connect},tls=${tls},start=${start},total=${total},speed=${speed} ${TIMESTAMP}"

        # Send data to InfluxDB
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "MONSTER_HOST/api/upload" \
            --header "Authorization: DATAAPI apikey=\"$API_KEY\"" \
            --header "Content-Type: text/plain" \
            --data-raw "$LINE")
		
		if[["$response" == "200"]];then
			echo "Uploaded to Data API successfully"
		else
			echo "Data API upload failed with status: Error, $response"
		fi
    fi
done

echo
echo "======== Test Completed ========"

rm -rf curl_results

