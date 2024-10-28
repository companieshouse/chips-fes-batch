#!/bin/bash

cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-identified-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating identification stats report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

OUTFILE=/apps/fes/reporting/identified.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} @identified.sql

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating identification stats report "
   email_FES_group_f "FES Check identification stats report failure" "FES Check identification stats report failure, please investigate"
else
   f_logInfo "FES check identification stats report generated:"
   email_report_f "${FES_IDENTIFICATION_STATS_REP_MAIL_LIST}" "Identification Stats `date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} identification_stats.csv)"
fi

exit 0

