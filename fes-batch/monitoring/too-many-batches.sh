#!/bin/bash

cd /apps/fes/monitoring

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/fes/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# Not setting up logging as simple monitoring script

tempfile=/tmp/batchdata
batch_check=`ls /apps/fes/data/Batches_DATA | wc -l`
if [ $batch_check -gt 50 ]
then
        echo "$batch_check batches in Batches_DATA" >> $tempfile
        echo "Too many batches in Batches_DATA - please investigate!" >> $tempfile

        email_FES_group_f "WARNING - possible FES problem" "$(cat $tempfile)"

rm $tempfile
fi
