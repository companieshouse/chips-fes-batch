#!/bin/bash

cd /apps/fes/monitoring
# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# no logging required, simple monitoring script

#Adjust docker-compose bind mappings if data dir location changes
DATA_DIR="/apps/fes/data"

find $DATA_DIR/Batches_DATA -name "docinfo.txt" -mmin +120 | awk -F/ '{print $(NF-1)}' > /tmp/hung-batch

time_check=`cat /tmp/hung-batch | wc -l`
if [ $time_check != 0 ]
then

email_FES_group_f "WARNING - There are batches hanging around in Batches_DATA - Please Investigate." "$(cat /tmp/hung-batch)"

fi
