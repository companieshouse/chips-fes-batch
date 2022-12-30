#!/bin/bash

cd /apps/fes/monitoring

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/fes/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/monitoring
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-fes-check-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting fes-check"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

OUTFILE=/apps/fes/monitoring/fes-check.out

#Function to print each report as required
printReport() {

   #Find forms with an invalid status in FES
   result=$($ORACLE_HOME/bin/sqlplus -s -L ${FES_SQLPLUS_CONN_STRING} << EOF
      set serveroutput on
      set linesize 1000
      set feedback off
      set heading off

      DECLARE
        cursor c1 is
            select form_id, form_barcode, form_incorporation_number, batch_name, batch_scanned, form_status,
                   form_status_type_description
            from form f inner join envelope e on e.envelope_id = f.form_envelope_id
                        inner join batch b on b.batch_id = e.envelope_batch_id
                        inner join form_status_type fst on fst.form_status_type_id = f.form_status
            where form_status in (3,4,13,14,15)
            order by form_status asc, batch_scanned;
      BEGIN

         dbms_output.enable('100000000');
         dbms_output.put_line('Checking for forms with invalid status ...\n');
         dbms_output.put_line('\n');
         for v1 in c1 loop
            dbms_output.put_line('Batch: '||v1.batch_name||' - form id: '||v1.form_id||' form barcode: '||v1.form_barcode || ' has status: ' || v1.form_status ||' (' || v1.form_status_type_description || ') - please investigate\n');
         end loop;
      END;
      /
EOF
)  #the EOF needs to be flush to the edge to work..!

   exit_code=$?
   if [ $exit_code -ne 0 ]; then
      echo "Error generating fes check report "
      echo -e $result
   else
      echo -e $result
   fi

   echo "Checking for unprocessed folders ...."
   for folder in Batches_DATA Batches_PRE_OCR Batches_POST_OCR Batches_PROCESSING_FAILED
   do
      for data_files in $(find $HOME/data/$folder/. -name 'ENW_*' )
      do
         echo " "$folder "contains unprocessed folder " $(basename $data_files) " - please investigate"
      done
      for data_files in $(find $HOME/data/$folder/. -name 'SC*' )
      do
         echo " "$folder "contains unprocessed folder " $(basename $data_files) " - please investigate"
      done
      for data_files in $(find $HOME/data/$folder/. -name 'NI_*' )
      do
         echo " "$folder "contains unprocessed folder " $(basename $data_files) " - please investigate"
      done
   done
}

printReport > $OUTFILE

f_logInfo "FES check report generated:"
cat $OUTFILE | while IFS= read -r line; do f_logInfo "$line"; done

lines=$(cat $OUTFILE | wc -l)

if [ $lines -gt 4 ]
then
  f_logWarn "FES check found issues, alerting"
  email_FES_group_f "FES Check" "$(cat $OUTFILE)"
fi
