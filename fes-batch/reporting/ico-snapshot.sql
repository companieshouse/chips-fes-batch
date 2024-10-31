whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0
set colsep ,

spool &spool_file


select form_barcode, form_barcode_date, batch_name
            from form f inner join envelope e on e.envelope_id = f.form_envelope_id
                        inner join batch b on b.batch_id = e.envelope_batch_id
                        inner join form_status_type fst on fst.form_status_type_id = f.form_status
            where form_status in (17)
            and BATCH_NAME not like  'EFS_%%%%%%_%%%%'
            and BATCH_NAME not like 'SC_%%%%%%_%%%%'
            and BATCH_NAME not like 'NI_%%%%%%_%%%%'
            order by form_barcode_date; 


spool off

exit

