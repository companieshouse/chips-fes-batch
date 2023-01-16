#!/bin/bash

cd /apps/fes/monitoring

# load variables created from setCron script
source /apps/fes/env.variables

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
