#!/bin/bash

local_image_dir=/apps/fes/qia/images
dps_image_dir=/apps/fes/qia/breaches/Work
image_user=${QIA_IMAGE_USER}
image_server=${QIA_IMAGE_SERVER}
image_user_server=${image_user}@${image_server}
db_query_script=./db_queryqia
db_query_output=/tmp/mw_unload
barcode_list=barcodes.out

cd /apps/fes/qia

# Obtain list of form barcodes that have not yet been through sort
date
echo "Querying for outstanding barcodes"
# TODO - use key file
ssh ${image_user_server} ${db_query_script}
scp ${image_user_server}:${db_query_output} ${barcode_list} 
sed -i 's/ $//g' ${barcode_list}
sed -i 's/ /:/g' ${barcode_list}

echo
date
echo "Query for outstanding barcodes completed"
wc -l ${barcode_list}

# Iterate through list - checking if we already have the images
for four_fields in `cat ${barcode_list}`
do

 batch_barcode=${four_fields%%:*}

 three_fields=${four_fields#*:}
 form_barcode=${three_fields%%:*}

 two_fields=${three_fields#*:}
 company_num=${two_fields%%:*}

 doc_type=${two_fields##*:}

 date
 echo "Processing batch ${batch_barcode} document ${form_barcode} company ${company_num} type ${doc_type}"


 # Ensure batch folder exists
 batch_folder=${local_image_dir}/${batch_barcode}
 mkdir -p ${batch_folder}
 qia_folder=${dps_image_dir}/${batch_barcode}_${form_barcode}_${company_num}_${doc_type}

 # Path to form image folder
 form_image_folder_path=${batch_folder}/${form_barcode}

 # Does form image folder exist - if not, copy images
 if [ ! -d ${form_image_folder_path} ]; then

   mkdir -p ${qia_folder}
   chmod 777 ${qia_folder}

   echo "${batch_barcode}${form_barcode}${company_num}${doc_type} Existing image folder not found: ${form_image_folder_path}"
   echo "${batch_barcode}${form_barcode}${company_num}${doc_type}  Getting image from ${image_user_server}:/image/*/day1/${batch_barcode}/${form_barcode}"
 
   mkdir -p ${form_image_folder_path}
   #scp -r ${image_user_server}:/image/*/day1/${batch_barcode}/${form_barcode}/*.TIF ${qia_folder}
   

 else
  echo "${batch_barcode}${form_barcode} Already have processed images ${form_image_folder_path} - skipping copy to QIA"
 fi

 
done

rm -f ${barcode_list}
