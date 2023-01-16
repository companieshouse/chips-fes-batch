#!/bin/bash

cd /apps/fes/backup-clear-down

# load variables created from setCron script
source /apps/fes/env.variables

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/backup-clear-down
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-backup-clear-down-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting backup-clear-down"

#Adjust docker-compose bind mappings if data dir location changes
DATA_DIR="/apps/fes/data"
#if DATA_DIR is not a valid folder
if ! [ -d $DATA_DIR ] ; then
   f_logError "$DATA_DIR is not a valid folder"
   exit 1
fi

#Folder for processing
BATCH_DATA_BACKUP_DIR=$DATA_DIR/Batches_DATA_BACKUP
BATCH_POST_OCR_BACKUP_DIR=$DATA_DIR/Batches_POST_OCR_BACKUP
BATCH_HEADERS_DIR=$DATA_DIR/Batches_HEADERS
BATCH_PRE_OCR_BACKUP_DIR=$DATA_DIR/Batches_PRE_OCR_BACKUP
BATCH_RESCAN_DIR=$DATA_DIR/Batches_RESCAN

#Number of days before clearing files from backup folders
DAYS_BEFORE_BACKUP=28

## Cleardown function
f_clearDownDirectories_ENW_SC_NI () {
   DIR_TO_CLEAR=$1
   DAYS_TO_KEEP=$2

   for dir in `find $DIR_TO_CLEAR ! -path $DIR_TO_CLEAR -mtime +$DAYS_TO_KEEP -type d \( -name "ENW_*" -o -name "SC_*" -o -name "NI_*" \)`
   do
      f_logInfo "Removing $dir"
      rm -r $dir
   done
}

#----------------------------------------------------------------#
# Clear down Batches HEADERS Directory (Older than n days)
#----------------------------------------------------------------#
f_logInfo "Clearing Headers directory"
for file in `find $BATCH_HEADERS_DIR -mtime +$DAYS_BEFORE_BACKUP -name '*.pdf'`
do
   f_logInfo "Removing $file"
   rm -r $file
done

#----------------------------------------------------------------#
# Clear down Batches DATA BACKUP Directory (Older than n days)
#----------------------------------------------------------------#
f_logInfo "Clearing Data backup directories"
f_clearDownDirectories_ENW_SC_NI $BATCH_DATA_BACKUP_DIR $DAYS_BEFORE_BACKUP

#----------------------------------------------------------------#
# Clear down Batches PRE OCR BACKUP Directory (Older than n days)
#----------------------------------------------------------------#
f_logInfo "Clearing Pre OCR backup directories"
f_clearDownDirectories_ENW_SC_NI $BATCH_PRE_OCR_BACKUP_DIR $DAYS_BEFORE_BACKUP

#----------------------------------------------------------------#
# Clear down Batches POST OCR BACKUP Directory (Older than n days)
#----------------------------------------------------------------#
f_logInfo "Clearing Post OCR backup directories"
f_clearDownDirectories_ENW_SC_NI $BATCH_POST_OCR_BACKUP_DIR $DAYS_BEFORE_BACKUP

#----------------------------------------------------------------#
# Clear down Batches RESCAN Directory (Older than 15 day)
#----------------------------------------------------------------#
f_logInfo "Clearing Batches Rescan directories"
f_clearDownDirectories_ENW_SC_NI $BATCH_RESCAN_DIR 15

f_logInfo "Finished cleardown of backup directories"
f_logInfo "*************************************************************************"
