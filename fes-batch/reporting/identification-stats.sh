#!/bin/bash
# This script generates the report on Identification Stats for daily and monthly
cd /apps/fes/reporting

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/reporting
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-identification-stats-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting generating identification stats report"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

REPORT_TYPE="daily"
# by default the report is daily if the user passes -m then it will be monthly
USAGE="Usage: $(basename $0) [-m|-monthly] monthly report"
case "$1" in
    -m|-monthly)
        REPORT_TYPE="monthly"
        ;;
     -h|-help|-?)
       echo "$USAGE"
       exit 0
       ;;
esac

f_logInfo "Report type $REPORT_TYPE"


OUTFILE=/apps/fes/reporting/identification-stats-$REPORT_TYPE.csv
#Empty .out and .csv files
> $OUTFILE

#Run the SQL query 
sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOF
DEFINE spool_file=${OUTFILE}

    @identification-stats-${REPORT_TYPE}.sql

EXIT;
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
   f_logError "Error generating  "
   email_FES_group_f "FES Check Identification Stats reports failure" "FES Check Identification Stats reports failure, please investigate"
else
   f_logInfo "FES check Identification Stats reports generated:"
   email_report_f "${FES_IDENTIFICATION_STATS_REP_MAIL_LIST}" "Identification Stats $REPORT_TYPE `date '+%d/%m/%Y'`" "$(uuencode  ${OUTFILE} identification-stats-$REPORT_TYPE.csv)"
fi

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


exit 0

