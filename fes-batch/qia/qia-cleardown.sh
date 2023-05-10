#!/bin/bash

# This script forms part of the manual QIA sanity checking process where certain scanned images are reviewed by humans. 
# Images needing review are placed in a Work folder automatically by the qia-run.sh script.
# After those images are reviewed and if no issues are found, they are manually moved to a Release folder.
# If an issue is found, the images are manually moved to an Identified_Breach folder. 
# 
# This script removes files in the /apps/fes/qia/breaches/Release folder.  The folder /apps/fes/qia/breaches is
# a filesystem location external to the chips-fes-batch container that has been bind mounted into the container as /apps/fes/qia/breaches
# The files are removed only inside the Release subfolder, as that is the location where files have been moved after manual checking.
#
# This script is expected to run in the evening to clear down files in Release ready for the next day.

cd /apps/fes/qia

# load variables created from setCron script
source /apps/fes/env.variables

# set up logging
LOGS_DIR=../logs/qia-cleardown
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-qia-cleardown-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/fes/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting qia-cleardown"

rm -r /apps/fes/qia/breaches/Release/1*
rm -r /apps/fes/qia/breaches/Release/2*
rm -r /apps/fes/qia/breaches/Release/3*
rm -r /apps/fes/qia/breaches/Release/4*
rm -r /apps/fes/qia/breaches/Release/5*
rm -r /apps/fes/qia/breaches/Release/6*
rm -r /apps/fes/qia/breaches/Release/7*
rm -r /apps/fes/qia/breaches/Release/8*
rm -r /apps/fes/qia/breaches/Release/9*

f_logInfo "qia-cleardown completed"
