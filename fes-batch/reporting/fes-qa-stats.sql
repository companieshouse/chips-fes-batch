whenever sqlerror exit sql.sqlcode
set head off
set feed off
set veri off
set pages 0


spool &spool_file

select ACC.ACCOUNT_USERNAME,count(1)
from form_event fe inner join account acc on ACC.ACCOUNT_ID=FE.FORM_EVENT_CREATOR_ID
where fe.form_event_type_id in ('8','19','5')
and fe.form_event_form_id in
((select fe1.form_event_form_ID from form_event fe1
where fe1.form_event_type_id = '4' and trunc(fe1.fORM_EVENT_OCCURRED) = trunc(sysdate) - &report_type_id))
group by FE.FORM_EVENT_CREATOR_ID,ACC.ACCOUNT_USERNAME;


spool off

EXIT;

