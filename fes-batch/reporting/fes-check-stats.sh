#!/bin/bash
# This script generates the report on FES Check Stats for Cardiff, Belfast and Scotland
cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-fes-check-stats-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating fes check stats report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

REPORT_TYPE="cardiff"
# by default the report is daily if the user passes -c then it will be cardiff
USAGE="Usage: $(basename $0) [-c|-cardiff, -b|-belfast, -s|-scotland] stats report"
case "$1" in
    -c|-cardiff)
        REPORT_TYPE="cardiff"
        ;;
    -b|-belfast)
        REPORT_TYPE="belfast"
        ;;
    -s|-scotland)
        REPORT_TYPE="scotland"
        ;;                
     -h|-help|-?)
       echo "$USAGE"
       exit 0
       ;;
esac

f_logInfo "Report type $REPORT_TYPE"

OUTFILE=/apps/fes/reporting/fes-check-stats-$REPORT_TYPE.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOF
DEFINE spool_file=${OUTFILE}
    @fes-check-stats-${REPORT_TYPE}.sql

EXIT;
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating  "
   email_FES_group_f "FES Check FES Check Stats reports failure" "FES Check FES Check Stats reports failure, please investigate"
else
   f_logInfo "FES check FES Check Stats reports generated:"
   email_report_f "${FES_IDENTIFICATION_STATS_REP_MAIL_LIST}" "${REPORT_TYPE^} FES Check Stats `date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} fes-check-stats-$REPORT_TYPE.csv)"
fi

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


exit 0

