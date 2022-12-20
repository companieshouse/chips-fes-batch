#!/bin/bash

cd /apps/fes/move-scan-files

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/fes/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/move-scan-files
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-move-scan-files-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting move-scan-files"

#Adjust docker-compose bind mappings if data dir location changes
DATA_DIR="/apps/fes/data"
#if DATA_DIR is not a valid folder
if ! [ -d $DATA_DIR ] ; then
   f_logError "$DATA_DIR is not a valid folder"
   exit 1
fi
BATCH_DATA_DIR=$DATA_DIR/Batches_DATA
BATCH_DATA_DELETED_DIR=$DATA_DIR/Batches_DATA_DELETED
BATCH_POST_OCR_DIR=$DATA_DIR/Batches_POST_OCR
BATCH_POST_OCR_DELETED_DIR=$DATA_DIR/Batches_POST_OCR_DELETED
PROCESSED_FILE=batch.processed
STOPPED_FILE=batch.stopped
ENVELOPE=ENVELOPE
COVLETT=COVLETT
DOCINFO=docinfo.txt

#Threshold to alert of number of files in HOTFOLDER directories
HOT_FOLDER_ALERT_THRESHOLD=25

#List of email addresses to alert
ALERT_EMAIL_LIST=${EMAIL_ADDRESS_FES}

DATEDIR=`date +"%y%m%d"`
PRE_OCR_BACKUP_DIR=$DATA_DIR/Batches_PRE_OCR_BACKUP

#Hot folder - used to move files to ABBYY
HOT_FOLDER_DIR=$DATA_DIR/Batches_HOTFOLDER2

#Flag to bypass OCR - set to Y to allow processing to continue if ABBYY system unavailable
BYPASS_OCR=N

#Flag to allow entire batch to be bypassed if it contains a document over page size threshold
ALLOW_BATCH_BYPASS=N

#Flag to allow an individual document to be bypassed if it contains a document over page size threshold (Will be ignored if whole batch is being bypassed)
ALLOW_DOC_BYPASS=Y
DOC_BYPASS_SIZE_THRESHOLD=8500000

#Load balancing flag - if Y then switch between either HOT FOLDER (If more than 1 HOT FOLDER exists)
LOAD_BALANCE_HOTFOLDER=Y

#Location of all Hot folders - used to decide which HOT FOLDER to use
HOT_FOLDER_DIR1=$DATA_DIR/Batches_HOTFOLDER
HOT_FOLDER_DIR2=$DATA_DIR/Batches_HOTFOLDER2

PRE_OCR_DIR=$DATA_DIR/Batches_PRE_OCR

#Size threshold for pages - bypass OCR if batch contains a file with more than this variables number of pages
MAX_PAGE_THRESHOLD=150

#Set debug flag to echo debug comments
DEBUG=N

f_logInfo "Processing files in folder $PRE_OCR_DIR"
f_logInfo "Bypass OCR flag set to $BYPASS_OCR"
f_logInfo "Allow Batch Bypass flag set to $ALLOW_BATCH_BYPASS"
f_logInfo "Allow Doc Bypass flag set to $ALLOW_DOC_BYPASS"
if [[ $ALLOW_DOC_BYPASS == "Y" ]] ; then
   f_logInfo "Doc Bypass threshold set to $DOC_BYPASS_SIZE_THRESHOLD bytes"
fi

#if we are bypassing the OCR, set the hot folder variable to be same as POST_OCR_FOLDER
if [ $BYPASS_OCR == "Y" ] ; then
   f_logInfo "Bypassing HOTFOLDER OCR"
   HOT_FOLDER_DIR=$BATCH_POST_OCR_DIR;
else
   if [ $LOAD_BALANCE_HOTFOLDER == "Y" ] ; then
      f_logInfo "Load balancing is set to true"
      #Decide which HOT folder to use - if load balance if false just use HOT_FOLDER_DIR value
      HOT_FOLDER_1_COUNT=`find $HOT_FOLDER_DIR1 -name 'ENW_*' -o -name 'SC_*' -o -name 'NI_*' | wc -l`
      HOT_FOLDER_2_COUNT=`find $HOT_FOLDER_DIR2 -name 'ENW_*' -o -name 'SC_*' -o -name 'NI_*' | wc -l`
      f_logInfo "Hot Folder 1 count is $HOT_FOLDER_1_COUNT and Hot Folder 2 count is $HOT_FOLDER_2_COUNT"
      #only load balance if the count for both folders is different
      if [[ $HOT_FOLDER_1_COUNT -ne $HOT_FOLDER_2_COUNT ]] ; then
         f_logInfo "Load balancing as HOT FOLDERS contain different number of files"
         #if Hot Folder 1 has fewer or the same number of files as Hot Folder 2 then allocate batch to Hot Folder 1
         if [[ $HOT_FOLDER_1_COUNT -le $HOT_FOLDER_2_COUNT ]] ; then
            HOT_FOLDER_DIR=$HOT_FOLDER_DIR1
         else
            #Hot folder 2 has fewer items to allocate to it
            HOT_FOLDER_DIR=$HOT_FOLDER_DIR2
         fi
      fi
   fi
   if [[ $HOT_FOLDER_1_COUNT -gt $HOT_FOLDER_ALERT_THRESHOLD ]] && [[ $HOT_FOLDER_2_COUNT -gt $HOT_FOLDER_ALERT_THRESHOLD ]] ; then
      f_logWarn "alerting as all HOT FOLDER directories have exceeded threshold"
      email_FES_group_f "HOT FOLDER SIZE WARNING" "WARNING: HOT FOLDER 1 count is $HOT_FOLDER_1_COUNT and HOT FOLDER 2 count is $HOT_FOLDER_2_COUNT"
   fi
fi

f_logInfo "Hot Folder is set to $HOT_FOLDER_DIR"
# Capture HOT_FOLDER_DIR starting value in case we need to restore it after a bypassed batch
HOT_FOLDER_DIR_STARTING_VALUE=$HOT_FOLDER_DIR

for file in `find $PRE_OCR_DIR -name batch.scanned`
do
   #This is the full path to the folder containing a batch.scanned file
   DIRNAME=`dirname $file`

   BATCHNAME=`basename $DIRNAME`
   f_logInfo "=========== Processing batch name $BATCHNAME =============="

   #Remove  batch.scanned to prevent being copying into HOT Folder
   rm $DIRNAME/batch.scanned
   f_logDebug "   Removing $DIRNAME/batch.scanned"

   SCANFOLDER=`dirname $DIRNAME`
   f_logDebug "  scan folder name is $SCANFOLDER"

   SCANNERNAME=`basename $SCANFOLDER`
   f_logDebug "  scannername  is $scannername"

   #Set bypass OCR for batch to N
   BYPASS_OCR_FOR_BATCH="N"

   #Copy contents of batch to pre ocr Backup folder
   f_logInfo "   Copying $DIRNAME to $PRE_OCR_BACKUP_DIR"
   f_logInfo "   contents of directory are:"
   ls -tr $DIRNAME | while IFS= read -r line; do f_logInfo "$line"; done
   cp -r $DIRNAME $PRE_OCR_BACKUP_DIR/$BATCHNAME

   # Only check for page threshold if not already bypassing OCR and bypass of batch is allowed
   if [[ $BYPASS_OCR == "N" ]] && [[ $ALLOW_BATCH_BYPASS == "Y" ]] ; then

      f_logDebug "checking if batch can be bypassed ..."

      #Check if we need to bypass this batch because it contains a document with too many pages
      MAX_PAGES=1
      FILENAME=$BATCH_DATA_DIR/$BATCHNAME/$DOCINFO
      if [ -f $FILENAME ] ; then
         while read -r FOLDER PAGES
         do
            #Strip CTRL M chars at end of PAGES if they exists
            PAGES=${PAGES%$'\r'}
            f_logDebug "pages is currently set to $PAGES and max pages is $MAX_PAGES"
            if [[ ! -z $PAGES ]] && [[ $PAGES == +([0-9]) ]] && [[ $PAGES -gt $MAX_PAGES ]] ; then
               MAX_PAGES=$PAGES
            fi
         done <"$FILENAME"
      fi

      if [[ $MAX_PAGES -gt $MAX_PAGE_THRESHOLD ]] ; then
         f_logWarn "Batch $BATCHNAME contains a document with over $MAX_PAGE_THRESHOLD pages - bypassing OCR"
         BYPASS_OCR_FOR_BATCH="Y"
         HOT_FOLDER_DIR=$BATCH_POST_OCR_DIR;
         f_logWarn "Temporarily set HOT_FOLDER to $HOT_FOLDER_DIR"
      fi
   fi

   f_logDebug "post BYPASS OCR check - bypass OCR is set to $BYPASS_OCR and bypass OCR for Batch is set to $BYPASS_OCR_FOR_BATCH"

   #if not bypassing OCR (Completely or for the Batch) ...
   if [[ $BYPASS_OCR == "N" ]] && [[ $BYPASS_OCR_FOR_BATCH == "N" ]] ; then
      f_logInfo "   moving ENVELOPE and COVLETT folders for $BATCHNAME to $BATCH_POST_OCR_DIR"
      #Iterate through batch files, moving Envelope and Covering letters
      #to POST OCR folder and only copy Forms to HOT FOLDER
      for subfolder in `find $DIRNAME -name "*_*" -type d`
      do
         f_logDebug "subfolder being processed is $subfolder"
         subfile=`basename $subfolder`
         f_logDebug "subfile is $subfile and batchname is $BATCHNAME"

         #Ignore if root folder returned by find command (Happens on some unix systems)
         if [[ $subfile != $BATCHNAME ]] ; then
            #Remove leading number
            suffix=`echo $subfile | cut -f2 -d "_"`
            #If suffix value is ENVELOPE or COVLETT, move to post OCR folder
            f_logDebug "suffix is $suffix"
            if [ "$suffix" == "$ENVELOPE" ] || [ "$suffix" == "$COVLETT" ] ; then
               #check if batch folder exists in POST OCR directory - if not, create
               if ! [ -d $BATCH_POST_OCR_DIR/$BATCHNAME ] ; then
                  mkdir $BATCH_POST_OCR_DIR/$BATCHNAME
               fi

               #Move envelope or covering letter to post OCR folder
               f_logDebug "moving $subfolder to $BATCH_POST_OCR_DIR/$BATCHNAME/$subfile"
               mv $subfolder $BATCH_POST_OCR_DIR/$BATCHNAME/$subfile
            else
               #Check to move files over a certain size directly to POST_OCR Folder (Bypass OCR)
               if [[ "$ALLOW_DOC_BYPASS" == "Y" ]] ; then

                  f_logDebug "checking DOC size - subfile is $subfile "
                  BYPASS_THIS_SUBFOLDER=N

                  #Iterate each image file - there should only be 1 per subfolder
                  for IMAGE_FILE in `find $subfolder -name "*.tif" -type f`
                  do
                     f_logDebug "image_file is $IMAGE_FILE"

                     #Get image file size - version below for Solaris
                     IMAGE_FILE_SIZE=`stat -c %s $IMAGE_FILE`

                     #Get image file size - version below for MacOS
                     #IMAGE_FILE_SIZE=`stat -f %z $IMAGE_FILE`

                     f_logDebug "image file size for $IMAGE_FILE is $IMAGE_FILE_SIZE"

                     #Check if image size is valid, and if it exeeds to Threshold
                     if [[ ! -z $IMAGE_FILE_SIZE ]] && [[ $IMAGE_FILE_SIZE == +([0-9]) ]] && [[ $IMAGE_FILE_SIZE -gt $DOC_BYPASS_SIZE_THRESHOLD ]] ; then
                        f_logDebug "bypassing for subfolder $subfolder as size too big"
                        BYPASS_THIS_SUBFOLDER=Y
                     fi
                  done

                  if [[ $BYPASS_THIS_SUBFOLDER == "Y" ]] ; then
                     f_logInfo "   bypassing OCR for subfolder $subfile as if contains an image over $DOC_BYPASS_SIZE_THRESHOLD - moving to $BATCH_POST_OCR_DIR/$BATCHNAME/$subfile"

                     #check if batch folder exists in POST OCR directory - if not, create
                     if ! [ -d $BATCH_POST_OCR_DIR/$BATCHNAME ] ; then
                     mkdir $BATCH_POST_OCR_DIR/$BATCHNAME
                     fi

                     #Move subfolder to post OCR folder
                     f_logInfo "   moving" $subfolder to $BATCH_POST_OCR_DIR/$BATCHNAME/$subfile
                     mv $subfolder $BATCH_POST_OCR_DIR/$BATCHNAME/$subfile
                  fi
               fi
            fi
         fi
      done
   fi

   DO_FOLDER_MOVE=Y

   #If allowing Docs to be bypassed, check there are any files to OCR before moving to HOT FOLDER
   if [[ $BYPASS_OCR_FOR_BATCH == "N" ]] && [[ $ALLOW_DOC_BYPASS == "Y" ]] ; then
      f_logDebug "batch not being bypassed and allow doc bypass is true - checking if any files need processing ..."
      FILES_IN_DIR_COUNT=`ls $PRE_OCR_DIR/$BATCHNAME | wc -l`
      f_logDebug "files in dir count is $FILES_IN_DIR_COUNT"
      if [[ ! -z $FILES_IN_DIR_COUNT ]] && [[ $FILES_IN_DIR_COUNT -eq 0 ]] ; then
         f_logInfo "   Bypassing docs and no folders left to process - no move required "
         DO_FOLDER_MOVE=N
         f_logInfo "   Deleting PRE_OCR_FOLDER $PRE_OCR_DIR/$BATCHNAME"
         rm -r $PRE_OCR_DIR/$BATCHNAME
      fi
   fi

   #No need to move folder if all files have already been copied over
   if [[ $DO_FOLDER_MOVE == "Y" ]] ; then
      #Move temp folder to HOT folder
      f_logInfo "   moving $PRE_OCR_DIR/$BATCHNAME to $HOT_FOLDER_DIR"
      mv $PRE_OCR_DIR/$BATCHNAME $HOT_FOLDER_DIR
   fi

   #If bypassing OCR for batch only, set hot folder back to correct value
   if [[ $BYPASS_OCR_FOR_BATCH == "Y" ]] ; then
      HOT_FOLDER_DIR=$HOT_FOLDER_DIR_STARTING_VALUE
      BYPASS_OCR_FOR_BATCH="N"
      f_logInfo "   setting HOT_FOLDER back to $HOT_FOLDER_DIR"
   fi

   f_logInfo "========== Batch $BATCHNAME has been processed ============="

done

f_logInfo "Starting cleardown of processed batch directories "
#--------------------------------------#
# Clear down Batches Data Directory
#--------------------------------------#
for file in `find $BATCH_DATA_DIR -name $PROCESSED_FILE`
do
   #get directory for file
   fullpath=`dirname $file`
   #remove leading path to get directory only
   dirname=`basename $fullpath`
   f_logInfo "Removing Batches_DATA/$dirname"
   rm -r $fullpath
done

#--------------------------------------#
# Clear down Batches POST OCR Directory
#--------------------------------------#
for file in `find $BATCH_POST_OCR_DIR -name $PROCESSED_FILE`
do
   #get directory for file
   fullpath=`dirname $file`
   #remove leading path to get directory only
   dirname=`basename $fullpath`
   f_logInfo "Removing Batches_POST_OCR/$dirname"
   rm -r $fullpath
done
f_logInfo "Finished cleardown of processed batch directories"

f_logInfo "Finished at  `date`"
f_logInfo "*************************************************************************"
