whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0
spool &spool_file


select a.account_username||' = '|| count(*)
from batch_event b inner join account a on a.account_id = b.batch_event_creator_id
where B.BATCH_EVENT_TYPE_ID = 6 and trunc(b.BATCH_EVENT_OCCURRED) = trunc(sysdate)-1
and account_id in ('130','1551','1951','127','128','88','991','126','269','1034')
group by a.account_username;



spool off

exit

