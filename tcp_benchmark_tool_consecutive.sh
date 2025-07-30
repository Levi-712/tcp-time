#!/bin/bash

# InfluxDB/Monster Data API Configuration
API_KEY="*****"
MONSTER_HOST="*****"

# Ask for the URL
read -p "Enter the URL: " URL

# Ask for the VIP
read -p "Enter the VIP name: " vip

# Ask for the Token
read -p "Enter the X-DataDirect-Auth-Token: " TOKEN

# Ask the user how many times to run the test
read -p "How many iterations would you like to run? " ITERATIONS

VIP="${vip}-APAC"

echo
echo "=============== TEST STARTED ==============="
echo "Testing URL: $URL"
echo "Running $ITERATIONS iterations"
echo "============================================"

# Loop for the number of iterations
for ((i=1; i<=ITERATIONS; i++))
do
    echo
    echo "======= Running Test #$i ======="
    echo

    # Run curl and collect all metrics
    result=$(curl -k -H "X-DataDirect-Auth-Token: $TOKEN" -o /dev/null -s -S -w "%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{speed_download}" "$URL")

    # Parse the result into individual variables
    read dns connect tls start total speed <<< "$result"

    # Show full info for this iteration
    echo "-------- Timing Breakdown --------"
    echo "DNS Lookup:        ${dns}s"
    echo "TCP Connect:       ${connect}s"
    echo "TLS Handshake:     ${tls}s"
    echo "Start Transfer:    ${start}s"
    echo "Total Time:        ${total}s"
    echo "Download Speed:    $speed bytes/sec"

    # echo "======= Test #$i Completed ======="
    echo

    # Line protocol
    TIMESTAMP=$(date +%s%N)
    LINE="tcp_optimization.seq,VIP=$VIP dns=${dns},connect=${connect},tls=${tls},start=${start},total=${total},speed=${speed} ${TIMESTAMP}"

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


done
