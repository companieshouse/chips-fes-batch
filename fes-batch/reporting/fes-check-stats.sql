whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0
spool &spool_file

select BATCH_ID, BATCH_SCANNED, BATCH_NAME, BATCH_SCAN_PERSON  from batch
where BATCH_SCANNER_NAME IN (&batch_scanner_name) 
and batch_scanned > sysdate -1;   

spool off

exit


