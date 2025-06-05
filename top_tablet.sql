SELECT
     -- SUM(ash.sample_weight) AS samples,
     SUM(1) AS samples,
     SUBSTRING(pgss.query, 1, 30) query_text,
     tablets.table_name,
     ash.wait_event_aux AS tabletid,
     wait_event
FROM
            yb_active_session_history ash
LEFT JOIN   pg_stat_statements pgss ON ash.query_id = pgss.queryid
JOIN        yb_local_tablets tablets ON ash.wait_event_aux = SUBSTRING(tablets.tablet_id, 1, 15)
WHERE
     ash.sample_time >= current_timestamp - interval '30 minutes'
     and wait_event_type='Cpu'
GROUP BY
     query_text,
     wait_event,
     tablets.table_name,
    ash.wait_event_aux 
Order by
     1 desc
;


--  samples |           query_text           |               table_name / index_name  |    tabletid     
---------+--------------------------------+----------------------------------------+-----------------
--       38 | insert into subscriptions (use | users                                  | 3d3edc85e8b4464
--       23 |                                | users                                  | 3d3edc85e8b4464
--       22 | insert into subscriptions (use | channels                               | ed556bb22197460
--       21 |                                | subscriptions_user_id_channel_id_idx   | 64acd8c0152f4dc
--       19 | insert into subscriptions (use | subscriptions                          | 9e7b2a89dc71484
