#!/bin/bash

cd /apps/fes/monitoring
# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# no logging required, simple monitoring script

if [[ $# -eq 0 ]] ; then
    echo 'Batch status to check for needs to be supplied as script argument'
    echo 'Example: /apps/fes/fes-batch/monitoring/batch-status.sh 1'
    exit 1
fi
BATCH_STATUS=$1

OUTFILE=/apps/fes/monitoring/batch-status${BATCH_STATUS}.csv
#Empty .out and .csv files
> $OUTFILE

result=$(
$ORACLE_HOME/bin/sqlplus -s -L ${FES_SQLPLUS_CONN_STRING} << EOF

set head off
set feed off
set veri off
set pages 0
spool ${OUTFILE}

select batch_name from batch
where batch_status_id = '${BATCH_STATUS}'
and batch_scanned < sysdate -30
order by batch_id;
spool off

exit;
/
EOF
)

fail_check=`cat $OUTFILE | wc -l`
if [ $fail_check != 0 ]
then

email_FES_group_f "Batches at status ${BATCH_STATUS} over 30 days old" "$(cat $OUTFILE)"

fi
