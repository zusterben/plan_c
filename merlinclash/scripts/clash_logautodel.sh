#!/bin/sh

logpath=/tmp/upload
log=$logpath/merlinclash_node_mark.log
logmc=$logpath/merlinclash_log.txt

maxline=500

linecount=$(/usr/bin/wc -l $log | awk '{print $1}')
linecountmc=$(/usr/bin/wc -l $logmc | awk '{print $1}')

if [ "$linecount" -gt "$maxline" ]; then
    echo "" > $log
fi

if [ "$linecountmc" -gt "$maxline" ]; then
    echo "" > $logmc
fi