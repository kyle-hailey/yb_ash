WITH time_series AS (
    SELECT generate_series(
        date_trunc('minute', current_timestamp - interval '30 minutes'),
        date_trunc('minute', current_timestamp),
        interval '1 minute'    
    ) AS time_bucket
)
select
    node,
        TO_CHAR(ts.time_bucket, 'HH24:MI') AS time_bucket,
         round(count(*)/ 60.0, 2) as AAS,
    round(coalesce(sum(case when ash.wait_event_type = 'Cpu' THEN 1 END), 0) / 60.0, 2) AS Cpu,
    round(coalesce(sum(case when ash.wait_event_type = 'DiskIO' THEN 1 END), 0) /  60.0, 2) AS DiskIO,
    round(coalesce(sum(case when ash.wait_event_type = 'Network' THEN 1 END), 0) /  60.0, 2) AS Network,
     round(coalesce(sum(case when ash.wait_event_type = 'Lock' THEN 1 END), 0) /  60.0, 2) AS Lock,
    round(coalesce(sum(case when ash.wait_event_type = 'WaitOnCondition' THEN 1 END), 0) /  60.0, 2) AS WaitOnCondition,
    round(coalesce(sum(case when ash.wait_event_type = 'Extension' THEN 1 END), 0) /  60.0, 2) AS Extension,
    round(coalesce(sum(case when ash.wait_event_type NOT IN ('Cpu', 
                                                        'WaitOnCondition',
                                                        'Network',
                                                        'Extension',
                                                        'DiskIO' 
                                                        ) THEN 1 END), 0) /  60.0, 2) AS other
FROM    
    time_series ts
LEFT JOIN
      GV$ASH  ash
     -- yb_active_session_history ash
ON
    date_trunc('minute', ash.sample_time) = ts.time_bucket
WHERE
      sample_time >= current_timestamp - interval '30 minutes'
GROUP BY
    ts.time_bucket
    , node
ORDER BY
    ts.time_bucket, node;
    
    
-- node | time_bucket |  aas  | cpu  | diskio | network | waitoncondition | extension | other 
------+-------------+-------+------+--------+---------+-----------------+-----------+-------
--  1    | 15:57       |  5.35 | 1.65 |   0.53 |    3.17 |            0.00 |      0.00 |  0.00
--  2    | 15:57       |  5.12 | 1.65 |   0.53 |    2.93 |            0.00 |      0.00 |  0.00
--  3    | 15:57       |  5.35 | 1.65 |   0.53 |    3.17 |            0.00 |      0.00 |  0.00
--  4    | 15:57       |  5.12 | 1.65 |   0.53 |    2.93 |            0.00 |      0.00 |  0.00
--  5    | 15:57       |  5.12 | 1.65 |   0.53 |    2.93 |            0.00 |      0.00 |  0.00
--  6    | 15:57       |  4.32 | 1.00 |   0.38 |    2.92 |            0.02 |      0.00 |  0.00
--  1    | 15:58       |  9.35 | 1.92 |   0.87 |    6.57 |            0.00 |      0.00 |  0.00
--  2    | 15:58       | 11.50 | 3.23 |   1.15 |    7.12 |            0.00 |      0.00 |  0.00
--  3    | 15:58       |  9.35 | 1.92 |   0.87 |    6.57 |            0.00 |      0.00 |  0.00
--  4    | 15:58       | 11.50 | 3.23 |   1.15 |    7.12 |            0.00 |      0.00 |  0.00
--  5    | 15:58       | 11.50 | 3.23 |   1.15 |    7.12 |            0.00 |      0.00 |  0.00
--  6    | 15:58       |  9.12 | 2.12 |   0.83 |    6.17 |            0.00 |      0.00 |  0.00

  
