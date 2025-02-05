whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0
spool &spool_file

select a.account_username||' = '|| count(*)
from form_event f inner join account a on a.account_id = f.form_event_creator_id
where F.FORM_EVENT_TYPE_ID = 3 
and trunc(f.fORM_EVENT_OCCURRED) between add_months(trunc(sysdate,'mm'),-1) and  last_day(add_months(trunc(sysdate,'mm'),-1))
and exists (select 1 from form_event f2 where f2.form_event_form_id = f.form_event_form_id and form_event_Type_Id = 3)
group by a.account_username;

spool off

exit

