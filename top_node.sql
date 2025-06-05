WITH params AS (
    SELECT 43400.0::numeric AS scale_start ,
         900.0::numeric AS scale_width
)
  SELECT
      node,
      ROUND(count(*)/  MIN(p.scale_width)   , 2) AS Total,
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END),0) /   count(*)*1.0, 2 ) AS "Cpu%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Lock' THEN 1 END), 0)  /  count(*)*1.0, 2) AS "Lock%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' and  ash.wait_event != 'Raft_WaitingForReplication'  and ash.wait_event != 'CatalogRead' THEN 1 END), 0)  /   count(*)*1.0, 2 ) AS "Network%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'Raft_WaitingForReplication' THEN 1 END), 0)  /   count(*)*1.0, 2 ) AS "RAFT_REP%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'CatalogRead' THEN 1 END), 0)  /   count(*)*1.0, 2 ) AS "CatalogRead%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0)  /  count(*)*1.0, 2) AS "DiskIO%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO','Lock') THEN 1 END), 0)  /  count(*)*1.0, 2) AS "other%"
    ,to_char(min(sample_time), 'YY-MM-DD HH24:MI') mnt,
     to_char(max(sample_time), 'YY-MM-DD HH24:MI') mxt
  FROM 
      GV$ASH  ash
       -- yb_active_session_history ash
      CROSS JOIN params p
  WHERE
     ash.sample_time >= current_timestamp - (p.scale_start * interval '1 second') and
     ash.sample_time <= current_timestamp - ((p.scale_start - p.scale_width) * interval '1 second')   
  GROUP BY 
     ash.node
  ORDER BY 
      (ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Lock' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'WaitOnCondition' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Extension' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO') THEN 1 END), 0) / 1.0, 2)) DESC
      ;


--  node | total | Cpu%  | Lock% | Network% | RAFT_REP% | CatalogRead% | DiskIO% | other% |      mnt       |      mxt       
------+-------+-------+-------+----------+-----------+--------------+---------+--------+----------------+----------------
--  2    |  0.03 | 70.00 |  0.00 |     3.33 |      6.67 |        16.67 |    3.33 |   0.00 | 25-06-04 12:22 | 25-06-04 12:36
--  3    |  0.03 | 62.07 |  0.00 |     0.00 |      0.00 |        37.93 |    0.00 |   0.00 | 25-06-04 12:22 | 25-06-04 12:36
--  1    |  0.03 | 50.00 |  0.00 |     0.00 |      0.00 |        38.46 |    3.85 |   3.85 | 25-06-04 12:22 | 25-06-04 12:36

