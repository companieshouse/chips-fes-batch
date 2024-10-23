#!/bin/bash
cd /apps/fes/clear-failed-flags

# load variables created from setCron script
source /apps/fes/env.variables

# set up logging
LOGS_DIR=../logs/clear-failed-flags
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-clear-failed-flags-$(date +'%Y-%m-%d').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting clear-failed-flags"

for file in `find /apps/fes/data/Batches_DATA -name batch.failed`
do
  f_logInfo "Deleting $file"
  rm $file
done

for file in `find /apps/fes/data/Batches_POST_OCR -name batch.failed`
do
  f_logInfo "Deleting $file"
  rm $file
done
