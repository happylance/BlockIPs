#!/bin/bash

set -e
IPList_file=/etc/apache2/conf/IPList.conf
check_time=$(date +%Y-%m-%d-%H:%M:%S)
new_IPs_to_block_file="/tmp/new_IPs_to_block_at_$check_time"
IPs=$(cat /var/log/apache2/access.log | tail -5000 | grep -v 403 | grep xmlrpc.php | awk '{print $1}' | awk '{count[$1]++}END {for (word in count) if (count[word] > 10) print word}')
[ -z "$IPs" ] && { echo "$check_time: Done"; exit 0; }

echo "$IPs" | sed 's/^/Require not ip /' | grep -vxf "$IPList_file" > $new_IPs_to_block_file

[ $(cat $new_IPs_to_block_file | wc -l) -eq 0 ] && { echo "$check_time: Done"; exit 0; }

sudo sh -c "cat $new_IPs_to_block_file >> $IPList_file"
sudo service apache2 restart

echo "$check_time: Added new blocked IPs:"
cat $new_IPs_to_block_file
