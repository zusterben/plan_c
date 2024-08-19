#!/bin/sh

logpath=/tmp/upload
log=$logpath/merlinclash_node_mark.log

maxline=120

linecount=$(/usr/bin/wc -l $log | awk '{print $1}')

if [ "$linecount" -gt "$maxline" ]; then
    echo "" > $log
fi