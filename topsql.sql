

WITH params AS (
    SELECT 300.0::numeric AS scale
),
topsql as (
  SELECT
      query_id,
      ROUND(count(*)/  MIN(p.scale), 2) AS AAS,
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END),0) /   count(*)*1.0, 2 ) AS "Cpu%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' and  ash.wait_event != 'Raft_WaitingForReplication' THEN 1 END), 0)  /   count(*)*1.0, 2 ) AS "Network%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'Raft_WaitingForReplication' THEN 1 END), 0)  /   count(*)*1.0, 2 ) AS "RAFT_REP%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0)  /  count(*)*1.0, 2) AS "DiskIO%",
      round(100.0*COALESCE(SUM(CASE WHEN ash.wait_event = 'ConflictResolution_WaitOnConflictingTxns'                            THEN 1 END), 0)  /  count(*)*1.0, 2) AS "LOCK%",
      ROUND(100.0*COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO') THEN 1 END), 0)  /  count(*)*1.0, 2) AS "other%"
  FROM 
      -- GV$ASH  ash
      yb_active_session_history ash
      CROSS JOIN params p
  WHERE
     ash.sample_time >= current_timestamp - (p.scale * interval '1 second')
  GROUP BY 
     ash.query_id 
  ORDER BY 
      (ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Network' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'WaitOnCondition' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Extension' THEN 1 END), 0) / 1.0, 2) +
        ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type NOT IN ('Cpu', 'WaitOnCondition', 'Network', 'Extension', 'DiskIO') THEN 1 END), 0) / 1.0, 2)) DESC
       limit 20
),
sqltext as (
     select queryid, max(query) query 
     from 
          -- GV$PGSS
          pg_stat_statements
      group by queryid order by queryid
)
 select
      CASE 
        WHEN ash.query_id = '0' THEN '0'
        WHEN ash.query_id = '1' THEN 'LogAppender'
        WHEN ash.query_id = '2' THEN 'Flush'
        WHEN ash.query_id = '3' THEN 'Compaction'
        WHEN ash.query_id = '4' THEN 'RaftUpdateConsensus'
        WHEN ash.query_id = '5' THEN 'CatalogRequests'
        WHEN ash.query_id = '6' THEN 'LogBackgroundSync'
        ELSE REGEXP_REPLACE(REPLACE(REPLACE(SUBSTRING(pgss.query, 1, 50), E'\r', ''), E'\n', ''), '[ ]+', ' ', 'g')
    END AS sql_text, 
           ash.* 
 from topsql   ash
        LEFT JOIN
      sqltext pgss ON ash.query_id = pgss.queryid
 order by ash.AAS desc
      ;




--                       sql_text                      |       query_id       | aas  |  Cpu%  | Network% | RAFT_REP% | DiskIO% | LOCK% | other% 
----------------------------------------------------+----------------------+------+--------+----------+-----------+---------+-------+--------
--  SELECT sum(A.id) FROM AJOIN B ON A.category = B.f  |  7346864737869673583 | 2.76 |  12.09 |    83.68 |      0.00 |    4.23 |  0.00 |   0.00
--  SELECT titleFROM heavy_payload_textWHERE id +$2    |  -506067113979175153 | 2.62 |   7.50 |    75.48 |      0.00 |   17.03 |  0.00 |   0.00
--  select count(*) from authors where id < ( select m |  5798349130830498739 | 0.81 |  45.68 |    54.32 |      0.00 |    0.00 |  0.00 |   0.00
--  RaftUpdateConsensus                                |                    4 | 0.24 | 100.00 |     0.00 |      0.00 |    0.00 |  0.00 |   0.00
--  0                                                  |                    0 | 0.19 |  86.21 |     0.00 |     13.79 |    0.00 |  0.00 |   0.00
--  CatalogRequests                                    |                    5 | 0.05 |  14.29 |    85.71 |      0.00 |    0.00 |  0.00 |   0.00
--  SELECT count($3), $4, count(*) FROM authors WHERE  |  6876035050223907055 | 0.04 |  45.45 |    54.55 |      0.00 |    0.00 |  0.00 |   0.00
--  SELECT $2, count(*) FROM authors WHERE id < $1     | -5998057323106334825 | 0.04 |  41.67 |    58.33 |      0.00 |    0.00 |  0.00 |   0.00
--  SELECT now() as ts, schemaname, tablename,         |  9159551904200361675 | 0.02 |   0.00 |   100.00 |      0.00 |    0.00 |  0.00 |   0.00
--  SELECT titleFROM heavy_payload_textWHERE id = $1   |  5534273837352717876 | 0.01 |   0.00 |   100.00 |      0.00 |    0.00 |  0.00 |   0.00
--  WITH cte AS ( SELECT id FROM authors               |  1828413131585624147 | 0.01 |   0.00 |   100.00 |      0.00 |    0.00 |  0.00 |   0.00
--  LogAppender                                        |                    1 | 0.00 |   0.00 |     0.00 |      0.00 |  100.00 |  0.00 |   0.00
--  select count(*) from authors where id = $1         | -3664898139977360778 | 0.00 |   0.00 |   100.00 |      0.00 |    0.00 |  0.00 |   0.00
--  select sample_time, root_request_id, rpc_request_i | -7720202351765392012 | 0.00 | 100.00 |     0.00 |      0.00 |    0.00 |  0.00 |   0.00
