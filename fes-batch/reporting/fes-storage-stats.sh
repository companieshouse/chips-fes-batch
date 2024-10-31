#!/bin/bash
# This script generates the report on FES Storage Stats
cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-fes-storage-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating fes storage report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi




OUTFILE=/apps/fes/reporting/fes-storage.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOF
DEFINE spool_file=${OUTFILE}

    @fes-storage-stats.sql

EXIT;
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating  "
   email_FES_group_f "FES Check FES Storage reports failure" "FES Check FES Storage reports failure, please investigate"
else
   f_logInfo "FES check FES Storage reports generated:"
   email_report_f "${EMAIL_ADDRESS_FES}" "FES Storage Stats`date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} fes-storage.csv)"
fi
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

exit 0

