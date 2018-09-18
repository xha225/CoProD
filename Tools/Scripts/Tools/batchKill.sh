#!/bin/bash
ps aux | grep http | awk '{print $2}' | \
while IFS='' read -r pid || [[ -n "$pid" ]];do
kill -kill $pid
done
