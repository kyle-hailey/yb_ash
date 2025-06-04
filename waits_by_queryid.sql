

select 
       TO_CHAR(sample_time, 'HH24:MI') AS tm,
       wait_event,
       wait_event_type
from
      -- GV$ASH ash
      yb_active_session_history
where 
      query_id=26576944318935142
order by 
sample_time;


--   tm   |             wait_event             | wait_event_type 
-------+------------------------------------+-----------------
--  13:15 | Raft_WaitingForReplication         | Network
--  13:16 | Raft_ApplyingEdits                 | Cpu
--  13:17 | Raft_WaitingForReplication         | Network
--  13:17 | Raft_WaitingForReplication         | Network
