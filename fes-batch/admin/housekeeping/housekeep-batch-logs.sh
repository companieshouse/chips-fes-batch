#!/bin/bash

## Script to prune log files created by chips-fes-batch jobs
## $1 is days to keep
## we will only log latest run, no need to have this log loads
##

if [[ $# -eq 0 ]] ; then
    echo 'Logs will be deleted if older than the days you supply as script argument'
    echo 'Example: /apps/fes/admin/housekeeping/housekeep-batch-logs.sh 90'
    exit 1
fi

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/fes/.msmtprc.template > /apps/fes/.msmtprc
source /apps/fes/scripts/alert_functions

# set up logging
LOGS_DIR=/apps/fes/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-housekeep-batch-logs.log"
source /apps/fes/scripts/logging_functions

exec > ${LOG_FILE} 2>&1

## go to root of logs directory
cd /apps/fes/logs

## hard coded list of fes batch log directories as this is in a shared mount point so we are specific
DIRS="backup-clear-down batch-clear-down clear-failed-flags fes-file-loader monitoring move-scan-files"

## Logs will be deleted if older than the days you supply as script argument
DAYS=$1

f_logInfo  "~~~~~~~~ Starting Housekeeping of Log Files $(date) ~~~~~~~~~~~"
f_logInfo  "Running "$0

f_logInfo  "These files will be removed"
find ${DIRS} \( -name "*log" \) -mtime +${DAYS} -ls

f_logInfo  "Now removing these files"
find ${DIRS} \( -name "*log" \) -mtime +${DAYS} -exec rm {} \;

f_logInfo  "~~~~~~~~ Ending Housekeeping of Log Files ~~~~~~~~~~~"
