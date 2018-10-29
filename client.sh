#!/usr/bin/env bash
while sleep 5; do
  bash -x -c 'curl -s -XPOST -d "{\"data\":\"`date`\"}" http://localhost/api/v1/work | jq';
done
