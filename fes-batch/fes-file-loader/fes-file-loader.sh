#!/bin/bash

cd /apps/fes/fes-file-loader

# load variables created from setCron script
source /apps/fes/env.variables

# create properties file and substitutes values
envsubst < fes-file-loader.properties.template > fes-file-loader.properties

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/fes-file-loader
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-fes-file-loader-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting fes-file-loader"

RUNNING_PROCESSES=`ps -ef | grep fes-file-loader.jar | grep -v grep | wc -l`
if [ $RUNNING_PROCESSES -gt 0 ] ; then
   f_logError "ERROR: file loader appears to already be running - please investigate"
   exit 1
else
   java -jar ./fes-file-loader.jar $1
fi