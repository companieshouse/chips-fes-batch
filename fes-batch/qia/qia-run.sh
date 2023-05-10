#!/bin/bash

# This script forms part of the manual QIA sanity checking process where certain scanned images are reviewed by humans. 
# Images needing review are placed in a Work folder automatically by this script.
# After those images are reviewed and if no issues are found, they are manually moved to a Release folder.
# If an issue is found, the images are manually moved to an Identified_Breach folder.

# The folder /apps/fes/qia/breaches is a filesystem location external to the chips-fes-batch container 
# that has been bind mounted into the container as /apps/fes/qia/breaches
#
# This script carries out the following steps:
#  1. queries a database (via SSH and SCP) to obtain a list of scanned images that need manual review
#  2. looks for a corresponding folder in /apps/fes/qia/images for each image:
#  2.a  if found skips and checks next image
#  2.b  if not found, creates the folder and then copies the image from the image server to the /apps/fes/qia/breaches folder
#

cd /apps/fes/qia

# load variables created from setCron script
source /apps/fes/env.variables

# set up logging
LOGS_DIR=../logs/qia-run
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-qia-run-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

LOCAL_IMAGE_DIR=/apps/fes/qia/images
DPS_IMAGE_DIR=/apps/fes/qia/breaches/Work
IMAGE_USER=${QIA_IMAGE_USER}
IMAGE_SERVER=${QIA_IMAGE_SERVER}
IMAGE_USER_server=${IMAGE_USER}@${IMAGE_SERVER}
DB_QUERY_SCRIPT=./db_queryqia
DB_QUERY_OUTPUT=/tmp/mw_unload
BARCODE_LIST=barcodes.out
KEY_FOLDER=/apps/fes/.ssh

# Set up SSH key if not already present
if [ ! -f ${KEY_FOLDER}/${QIA_KEY_FILE} ]; then
  mkdir -p ${KEY_FOLDER}
  chmod 0700 ${KEY_FOLDER}
  echo -e ${QIA_KEY} > ${KEY_FOLDER}/${QIA_KEY_FILE}
  chmod 0600 ${KEY_FOLDER}/${QIA_KEY_FILE}
fi

# Obtain list of form barcodes that have not yet been through sort
f_logInfo "Querying for outstanding barcodes"

ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=/dev/null -i ${KEY_FOLDER}/${QIA_KEY_FILE} ${IMAGE_USER_server} ${DB_QUERY_SCRIPT}
scp -o StrictHostKeychecking=no -o UserKnownHostsFile=/dev/null -i ${KEY_FOLDER}/${QIA_KEY_FILE} ${IMAGE_USER_server}:${DB_QUERY_OUTPUT} ${BARCODE_LIST} 
sed -i 's/ $//g' ${BARCODE_LIST}
sed -i 's/ /:/g' ${BARCODE_LIST}

f_logInfo "Query for outstanding barcodes completed"
wc -l ${BARCODE_LIST}

# Iterate through list - checking if we already have the image folders locally
# If we don't have the folder we haven't copied it over to the QIA Work folder yet
for FOUR_FIELDS in `cat ${BARCODE_LIST}`
do

 BATCH_BARCODE=${FOUR_FIELDS%%:*}

 THREE_FIELDS=${FOUR_FIELDS#*:}
 FORM_BARCODE=${THREE_FIELDS%%:*}

 TWO_FIELDS=${THREE_FIELDS#*:}
 COMPANY_NUM=${TWO_FIELDS%%:*}

 DOC_TYPE=${TWO_FIELDS##*:}

 f_logInfo "Processing batch ${BATCH_BARCODE} document ${FORM_BARCODE} company ${COMPANY_NUM} type ${DOC_TYPE}"

 # Ensure batch folder exists
 BATCH_FOLDER=${LOCAL_IMAGE_DIR}/${BATCH_BARCODE}
 mkdir -p ${BATCH_FOLDER}
 QIA_FOLDER=${DPS_IMAGE_DIR}/${BATCH_BARCODE}_${FORM_BARCODE}_${COMPANY_NUM}_${DOC_TYPE}

 # Path to form image folder
 FORM_IMAGE_FOLDER_PATH=${BATCH_FOLDER}/${FORM_BARCODE}

 # Does form image folder exist - if not, copy images
 if [ ! -d ${FORM_IMAGE_FOLDER_PATH} ]; then

   mkdir -p ${QIA_FOLDER}
   chmod 777 ${QIA_FOLDER}

   f_logInfo "${BATCH_BARCODE}${FORM_BARCODE}${COMPANY_NUM}${DOC_TYPE} Existing image folder not found: ${FORM_IMAGE_FOLDER_PATH}"
   f_logInfo "${BATCH_BARCODE}${FORM_BARCODE}${COMPANY_NUM}${DOC_TYPE} Copying images from ${IMAGE_USER_server}:/image/*/day1/${BATCH_BARCODE}/${FORM_BARCODE} to ${QIA_FOLDER}"
 
   mkdir -p ${FORM_IMAGE_FOLDER_PATH}
   scp -o StrictHostKeychecking=no -o UserKnownHostsFile=/dev/null -i ${KEY_FOLDER}/${QIA_KEY_FILE} -r ${IMAGE_USER_server}:/image/*/day1/${BATCH_BARCODE}/${FORM_BARCODE}/*.TIF ${QIA_FOLDER}
   

 else
   f_logInfo "${BATCH_BARCODE}${FORM_BARCODE} Already have processed images ${FORM_IMAGE_FOLDER_PATH} - skipping copy to QIA"
 fi
 
done

rm -f ${BARCODE_LIST}
