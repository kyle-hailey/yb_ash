WITH time_series AS (
    SELECT generate_series(
        date_trunc('minute', current_timestamp - interval '30 minutes'),
        date_trunc('minute', current_timestamp),
        interval '1 minute'    
    ) AS time_bucket
)
select
      --  node, 
        TO_CHAR(ts.time_bucket, 'HH24:MI') AS tm,
        --  round(CAST(sum(sample_weight)/60.0 AS NUMERIC), 2) AS "AAS",
         round(CAST(sum(1)/60.0 AS NUMERIC), 2) AS "AAS",        
            wait_event_component,
            wait_event_class,
            wait_event_type,
            wait_event
FROM    
    time_series ts
LEFT JOIN
     GV$ASH ash
     --  yb_active_session_history ash
ON
    date_trunc('minute', ash.sample_time) = ts.time_bucket
WHERE
      sample_time >= current_timestamp - interval '30 minutes'
 --  and wait_event != 'QueryDiagnosticsMain'
GROUP BY
    ts.time_bucket,
    wait_event_component,
    wait_event_class,
    wait_event_type,
    wait_event 
   --  , node
ORDER BY
    ts.time_bucket
    ,wait_event_component ;


-- tm   | AAS  | wait_event_component | wait_event_class | wait_event_type |               wait_event               
-------+------+----------------------+------------------+-----------------+----------------------------------------
--  18:46 | 4.62 | TServer              | Common           | Cpu             | OnCpu_Active
--  18:46 | 0.72 | TServer              | Common           | Cpu             | OnCpu_Passive
--  18:46 | 0.03 | TServer              | Consensus        | DiskIO          | WAL_Sync
--  18:46 | 0.03 | TServer              | Consensus        | Network         | Raft_WaitingForReplication
--  18:46 | 0.13 | YSQL                 | TServerWait      | Network         | CatalogRead
--  18:46 | 2.18 | YSQL                 | TServerWait      | Network         | TableRead
--  18:46 | 0.10 | YSQL                 | TServerWait      | Network         | WaitingOnTServer
--  18:48 | 4.70 | TServer              | Common           | Cpu             | OnCpu_Active
--  18:48 | 0.43 | TServer              | Common           | Cpu             | OnCpu_Passive

