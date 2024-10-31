whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0
spool &spool_file

select BATCH_NAME from batch
where (BATCH_SCANNER_NAME = 'scan_sim_1'
or BATCH_SCANNER_NAME = 'scan_sim_2'
or BATCH_SCANNER_NAME = 'scan_sim_3')
and batch_scanned > sysdate -1
order by batch_name;

spool off

exit

