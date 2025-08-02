#!/bin/bash

# InfluxDB/Monster Data API Configuration
API_KEY="*****"
MONSTER_HOST="*****"

# Ask user to enter the URL
read -p "Enter the URL to test: " URL

# Ask for VIP name
read -p "Enter the VIP name: " vip

# Ask user for the Token
read -p "Enter the X-DataDirect-Auth-Token: " TOKEN

# Ask user how many parallel connections he need to run
read -p "How many simultaneous connections would you like to run? " CONNECTION

VIP="${vip}-APAC"

# Creating a directory
mkdir -p curl_results

echo
echo "===== Starting Diagnostics (Running $CONNECTION parallel connections) ======="

# Launch parallel curl tests
for ((i=1; i<=CONNECTION; i++)); do
(
  result=$(curl -k -H "X-DataDirect-Auth-Token: $TOKEN" -o /dev/null -s -S -w "%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{speed_download}" "$URL")
  echo "$result" > curl_results/result_$i.txt
) &
done

wait

echo
echo "====== Results Summary ======"

for ((i=1; i<=CONNECTION; i++)); do
  if [[ -f curl_results/result_$i.txt ]]; then
    read dns connect tls start total speed < curl_results/result_$i.txt

    echo
    echo "========= Result #$i ========="
    echo "DNS Lookup:           ${dns}s"
    echo "TCP Connect:          ${connect}s"
    echo "TLS Handshake:        ${tls}s"
    echo "Start Transfer:       ${start}s"
    echo "Total Time:           ${total}s"
    echo "Download Speed:       $speed bytes/sec"

    # Line protocol (NO quotes around tag values)
    TIMESTAMP=$(date +%s%N)
    LINE="tcp_optimization.connection,VIP=$VIP dns=${dns},connect=${connect},tls=${tls},start=${start},total=${total},speed=${speed} ${TIMESTAMP}"

    # Upload to Monster/Influx
        response=$(curl -k -w "%{http_code}" -s -o /dev/null -X POST "$MONSTER_HOST/api/upload" \
                --header "Authorization: DATAAPI apikey=\"$API_KEY\"" \
                --header "Content-Type: text/plain" \
                --data "$LINE")

    if [[ "$response" == "200" || "$response" == "204" ]]; then
        echo "Uploaded to Data API successfully"
    else
        echo "Data API upload failed with status: Error, $response"
    fi
  fi
done

echo
echo "======== Test Completed ========"

# Clean up
rm -rf curl_results
