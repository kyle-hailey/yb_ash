

WITH params AS (
    SELECT 7200.0::numeric AS scale
),
topsql AS (
  SELECT
      query_id,
      ROUND(count(*)/ MIN(p.scale) , 2) AS AAS,
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END),0) / count(*), 2 ) AS "Cpu%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' and ash.wait_event != 'Raft_WaitingForReplication' THEN 1 END), 0) / count(*), 2 ) AS "Network%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'Raft_WaitingForReplication' THEN 1 END), 0) / count(*), 2 ) AS "RAFT_REP%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0) / count(*), 2) AS "DiskIO%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'ConflictResolution_WaitOnConflictingTxns' THEN 1 END), 0) / count(*), 2) AS "LOCK%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO') THEN 1 END), 0) / count(*), 2) AS "other%"
  FROM 
      yb_active_session_history ash
      CROSS JOIN params p
  WHERE
     ash.sample_time >= current_timestamp - (p.scale * interval '1 second')
  GROUP BY 
     ash.query_id 
  ORDER BY 
      (ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END), 0), 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0), 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' THEN 1 END), 0), 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'WaitOnCondition' THEN 1 END), 0), 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Extension' THEN 1 END), 0), 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO') THEN 1 END), 0), 2)) DESC
  LIMIT 20
),
topwait as (
    SELECT query_id, wait_event
    FROM (
        SELECT 
            query_id,
            wait_event,
            COUNT(*) AS event_count,
            RANK() OVER (PARTITION BY query_id ORDER BY COUNT(*) DESC) AS rnk
        FROM yb_active_session_history ash
             CROSS JOIN params p
         WHERE
             ash.sample_time >= current_timestamp - (p.scale * interval '1 second')
        GROUP BY query_id, wait_event
    ) sub
    WHERE rnk = 1
),
sqltext AS (
     -- SELECT queryid, MAX(query) query, AVG(mean_exec_time) mean_time
     SELECT queryid, MAX(query) query, AVG(mean_time) mean_time
     FROM pg_stat_statements
     GROUP BY queryid
)
SELECT
      CASE 
        WHEN ash.query_id = '0' THEN '0'
        WHEN ash.query_id = '1' THEN 'LogAppender'
        WHEN ash.query_id = '2' THEN 'Flush'
        WHEN ash.query_id = '3' THEN 'Compaction'
        WHEN ash.query_id = '4' THEN 'RaftUpdateConsensus'
        WHEN ash.query_id = '5' THEN 'CatalogRequests'
        WHEN ash.query_id = '6' THEN 'LogBackgroundSync'
        ELSE REGEXP_REPLACE(REPLACE(REPLACE(SUBSTRING(pgss.query, 1, 50), E'\r', ''), E'\n', ''), '[ ]+', ' ', 'g')
    END AS sql_text, round(pgss.mean_time) avg_ms, ash.*, wait.wait_event
FROM topsql ash
LEFT JOIN sqltext pgss ON ash.query_id = pgss.queryid
LEFT JOIN topwait wait  ON ash.query_id = wait.query_id
ORDER BY ash.AAS DESC;


--                      sql_text                      | avg_ms |       query_id       | aas  |  Cpu%  | Network% | RAFT_REP% | DiskIO% | LOCK% | other% |    wait_event    
-- ----------------------------------------------------+--------+----------------------+------+--------+----------+-----------+---------+-------+--------+------------------
--  SELECT sum(A.id) FROM AJOIN B ON A.category = B.f  |  22520 |  7346864737869673583 | 1.90 |  15.03 |    81.86 |      0.00 |    3.10 |  0.00 |   0.00 | TableRead
--  SELECT titleFROM heavy_payload_textWHERE id +$2    |  37767 |  -506067113979175153 | 1.29 |  10.40 |    67.00 |      0.00 |   22.59 |  0.00 |   0.00 | TableRead
--                                                     |        |  8932599902396401559 | 0.45 |  88.81 |     0.00 |      0.00 |    0.00 |  0.00 |  11.19 | OnCpu_Active
--  0                                                  |        |                    0 | 0.11 |  90.13 |     0.00 |      9.87 |    0.00 |  0.00 |   0.00 | OnCpu_Passive
--  RaftUpdateConsensus                                |        |                    4 | 0.06 | 100.00 |     0.00 |      0.00 |    0.00 |  0.00 |   0.00 | OnCpu_Passive
--  CatalogRequests                                    |        |                    5 | 0.05 |   7.87 |    92.13 |      0.00 |    0.00 |  0.00 |   0.00 | CatalogRead

