#!/bin/bash
# This script generates the report on FES QA Stats for weekly and monthly
cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-fes-qa-stats-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating fes qa stats report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

REPORT_TYPE="Weekly"
REPORT_TYPE_ID=7
# by default the report is weekly if the user passes -m then it will be monthly
USAGE="Usage: $(basename $0) [-m|-monthly] monthly report"
case "$1" in
    -m|-monthly)
        REPORT_TYPE="Monthly"
        REPORT_TYPE_ID=31
        ;;
     -h|-help|-?)
       echo "$USAGE"
       exit 0
       ;;
esac

f_logInfo "Report type $REPORT_TYPE"


OUTFILE=/apps/fes/reporting/fes-qa-stats_$REPORT_TYPE.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOF
DEFINE report_type_id=${REPORT_TYPE_ID}
DEFINE spool_file=${OUTFILE}

    @fes-qa-stats.sql

EXIT;
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating  "
   email_FES_group_f "FES Check fes qa stats reports failure" "FES Check fes qa stats reports failure, please investigate"
else
   f_logInfo "FES check fes qa stats reports generated:"
   email_report_f "${FES_QA_STATS_REP_MAIL_LIST}" "$REPORT_TYPE FES QA Stats `date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} fes-qa-stats_$REPORT_TYPE.csv)"
fi

exit 0

