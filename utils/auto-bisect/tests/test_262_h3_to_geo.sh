#!/bin/bash
set -e

echo "$PWD"
CH_PATH=${CH_PATH:=datastore}


$CH_PATH client  -mn -q "
SELECT version();
SELECT h3ToGeo(toUInt64(0));
"
