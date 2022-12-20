#!/bin/bash

########################################################################
#
#   Script:       batch-clear-down.sh (previously FESDocRetention.ksh)
#
#   Description:  Script to delete entries from tables:
#                 envelope, covering_letter, form, attachment, form_event, form_issue, image, image_comment,
#                 entity_lock, image_event, event_exception and image_reject
#                 where the batch was processed more than 30 days prior to rundate
#                 and where the batch_status_id = 6
#                 and all forms in envelope have been accepted, rejected or deleted (form_status=8,10,12)
#
#                 Then it deletes the batches on the batch table
#
######################################################################

cd /apps/fes/batch-clear-down

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/fes/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst <batch-clear-down.properties.template >batch-clear-down.properties

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/batch-clear-down
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-batch-clear-down-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting batch-clear-down"

PROGNAME="$(basename $0)"
PROGHOST="$(uname -n)"

if [ -z "${FES_SQLPLUS_CONN_STRING}" ]; then
   f_logError "FES_SQLPLUS_CONN_STRING - Required Environment variable missing."
   return 1
fi

# =============================================================================
#     Main Process
# =============================================================================
$ORACLE_HOME/bin/sqlplus -s ${FES_SQLPLUS_CONN_STRING} <<EOS
DEFINE return_val = 0
VARIABLE return_val NUMBER
DEFINE return_count = 0
VARIABLE return_count NUMBER

SET SERVEROUTPUT ON
SET TIME ON
SET ECHO ON
SET TIMING ON

DECLARE
lv_found          varchar2(1) := 'N';
v_buffer           varchar2(255);

BEGIN

   /********************************************************
   * RETRIEVE BATCHES OLDER THAN 30 DAYS
   ********************************************************/
   FOR batch_rec in (SELECT b.batch_id,
                        b.batch_processed_date
                        FROM batch b
                        WHERE b.batch_status_id = 6
                        AND b.batch_processed_date IS NOT NULL
                        AND trunc(b.batch_processed_date)  <  (sysdate - 30)     )

   LOOP

      /***************************************************************************************
      * ARE THERE ANY FORMS IN A BATCH THAT ARE NOT STATUS 8,10,12
      ****************************************************************************************/
      lv_found := 'N';

      BEGIN
         SELECT 'Y'
            INTO lv_found
            FROM envelope e
            INNER JOIN form f
            ON  f.form_envelope_id = e.envelope_id
            WHERE e.envelope_batch_id = batch_rec.batch_id
            AND f.form_status NOT IN (8,10,12)
            AND rownum < 2;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
            lv_found := 'N';
      END;

      IF lv_found = 'Y' THEN
         DBMS_OUTPUT.put_line ('Batch with forms not accepted, rejected or deleted.  Batch_id = ' || batch_rec.batch_id);
      END IF;

      IF lv_found = 'N'  THEN

         /********************************************************
         * RETRIEVE ENVELOPES WITHIN A BATCH
         ********************************************************/
         FOR env_rec in (SELECT e.envelope_id
                           FROM envelope e
                           WHERE e.envelope_batch_id = batch_rec.batch_id)
         LOOP

            /*************************************************************************************************
            * DELETE FORMS AND IMAGES IN ENVELOPE
            **************************************************************************************************/
            FOR form_rec in (SELECT f.form_id,
                              f.form_status,
                              f.form_image_id
                              FROM  form f
                              WHERE f.form_envelope_id = env_rec.envelope_id   )
            LOOP
               DELETE FROM image_event
                  WHERE image_event_image_id = form_rec.form_image_id;

               DELETE FROM image_exception
                  WHERE image_exception_image_id = form_rec.form_image_id;

               DELETE FROM image_comment
                  WHERE image_id = form_rec.form_image_id;

               DELETE FROM entity_lock
                  WHERE entity_lock_type_id = 2
                  AND entity_lock_entity_id = form_rec.form_id;

               DELETE FROM form_issue
                  WHERE form_issue_form_id = form_rec.form_id;

               DELETE FROM form_event
                  WHERE form_event_form_id = form_rec.form_id;

               DELETE FROM attachment
                  WHERE attachment_form_id = form_rec.form_id
                  OR attachment_image_id = form_rec.form_image_id;

               DELETE FROM form
                  WHERE form_id = form_rec.form_id;

               DELETE FROM image
                  WHERE image_id = form_rec.form_image_id;

            END LOOP;       --  form_rec

            /*******************************************************
            * DELETE COVERING LETTERS AND IMAGES
            ********************************************************/
            FOR letter_rec in (SELECT cl.covering_letter_id,
                                 cl.covering_letter_image_id
                                 FROM  covering_letter cl
                                 WHERE cl.covering_letter_envelope_id = env_rec.envelope_id )
            LOOP
               DELETE FROM entity_lock
                  WHERE entity_lock_type_id = 1
                  AND entity_lock_entity_id = letter_rec.covering_letter_id;

               DELETE FROM covering_letter
                  WHERE covering_letter_id = letter_rec.covering_letter_id;

               DELETE FROM image
                  WHERE image_id = letter_rec.covering_letter_image_id;

            END LOOP;    --  letter_rec

            /*****************************
            * DELETE ENVELOPE
            *****************************/

            DELETE FROM envelope
               WHERE envelope_id = env_rec.envelope_id;

         END LOOP;                      --  env_rec


         /**********************
         * DELETE BATCH
         **********************/
         DELETE FROM batch_event
            WHERE batch_event_batch_id = batch_rec.batch_id;

         DELETE FROM batch
            WHERE batch_id = batch_rec.batch_id;

         COMMIT;
      END IF;

   END LOOP;     --  batch_rec

   :return_val := 0;

   EXCEPTION
      WHEN OTHERS
      THEN
         v_buffer := DBMS_UTILITY.format_error_backtrace;
         DBMS_OUTPUT.put_line (SUBSTR (SQLERRM, 1, 255));
         DBMS_OUTPUT.put_line (SUBSTR (v_buffer, 1, 255));

      IF LENGTH (v_buffer) > 255 THEN
         DBMS_OUTPUT.put_line (SUBSTR (v_buffer, 256, 255));
      END IF;
      ROLLBACK;
      :return_val := 1;

END;
/

exit     :return_val
EOS

SQL_RESULT=$(echo "$?")

# =================================================================================
# Log an error or success message, send an email if the program failed, and exit
# =================================================================================

if [ "$SQL_RESULT" -ne 0 ]; then
   email_FES_group_f "ERROR: ${PROGNAME}@${PROGHOST}" "batch-clear-down.sh Failed. Please check log file ${LOG_FILE}!"
   f_logError "ERROR: batch-clear-down.sh - Failed."
   return 1
else
   f_logInfo "batch-clear-down.sh finished successfully."
fi
