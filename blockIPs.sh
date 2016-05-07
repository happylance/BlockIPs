#!/bin/bash

set -e
IPList_file=/etc/apache2/conf/IPList.conf
check_time=$(date +%Y-%m-%d-%H:%M:%S)
new_IPs_to_block_file="/tmp/new_IPs_to_block_at_$check_time"

duration_in_hours=4
let duration=$duration_in_hours*3600
now=$(date +%s)
logs=$(tail -5000 /var/log/apache2/access.log)
recent_log_count=$(echo "$logs" | sed 's/.*\[\([^ ]*\).*/\1/' | sed 's_/_-_g;s/:/ /' | sed 's_\(.*\)_date -d "\1" +%s_' | sh | awk -v now=$now -v duration=$duration '{print now-$1-duration}' | grep "-" | wc -l)
[ "$recent_log_count" -eq 0 ] && { echo "$check_time: No logs in the previous $duration_in_hours hours. Done"; exit 0; }

IPs=$(echo "$logs" | tail -$recent_log_count | grep -v 403 | grep xmlrpc.php | awk '{print $1}' | awk '{count[$1]++}END {for (word in count) if (count[word] > 10) print word}')
[ -z "$IPs" ] && { echo "$check_time: No IPs needs to be blocked in recent $recent_log_count logs. Done"; exit 0; }

echo "$IPs" | sed 's/^/Require not ip /' | grep -vxf "$IPList_file" > $new_IPs_to_block_file

[ $(cat $new_IPs_to_block_file | wc -l) -eq 0 ] && { echo "$check_time: Done"; exit 0; }

sudo sh -c "cat $new_IPs_to_block_file >> $IPList_file"
sudo service apache2 restart

echo "$check_time: Added new blocked IPs:"
cat $new_IPs_to_block_file
