#!/bin/bash
# This script generates the report on ICO Snapshot for daily and monthly
cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-ico-snapshot-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating ico snapshot report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi




OUTFILE=/apps/fes/reporting/ico-snapshot.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOF
DEFINE spool_file=${OUTFILE}

    @ico-snapshot.sql

EXIT;
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating  "
   email_FES_group_f "FES Check ICO Snapshot reports failure" "FES Check ICO Snapshot reports failure, please investigate"
else
   f_logInfo "FES check ICO Snapshot reports generated:"
   email_report_f "${FES_ICO_SNAPSHOT_REP_MAIL_LIST}" "ICO Snapshot `date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} ico-snapshot.csv)"
fi
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

exit 0

