






WITH params AS (
    SELECT 3600.0::numeric AS scale_start ,
          3600.0::numeric AS scale_width
),
topsql as (
  SELECT
      query_id,
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
      -- GV$ASH  ash
        yb_active_session_history ash
      CROSS JOIN params p
  WHERE
     ash.sample_time >= current_timestamp - (p.scale_start * interval '1 second') and
     ash.sample_time <= current_timestamp - ((p.scale_start - p.scale_width) * interval '1 second')   
  GROUP BY 
     ash.query_id 
  ORDER BY 
      (ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Cpu' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'DiskIO' THEN 1 END), 0) / 1.0, 2) +
       ROUND(COALESCE(SUM(CASE WHEN ash.wait_event_type = 'Lock' THEN 1 END), 0) / 1.0, 2) +
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
 order by 3 DESC
      ;



--                       sql_text                      |       query_id       | total | Cpu%  | Lock% | Network% | RAFT_REP% | CatalogRead% | DiskIO% | other% |      mnt       |      mxt       
----------------------------------------------------+----------------------+-------+-------+-------+----------+-----------+--------------+---------+--------+----------------+----------------
--  SELECT sum(A.id) FROM AJOIN B ON A.category = B.f  |  7346864737869673583 |  2.76 | 13.50 |  0.00 |    84.89 |      0.00 |         0.00 |    1.60 |   0.00 | 25-06-04 23:22 | 25-06-05 00:22
--  SELECT titleFROM heavy_payload_textWHERE id +$2    |  -506067113979175153 |  2.34 |  7.94 |  0.00 |    70.09 |      0.00 |         0.00 |   21.97 |   0.00 | 25-06-04 23:22 | 25-06-05 00:22
--  select count(*) from authors where id < ( select m |  5798349130830498739 |  1.21 | 42.79 |  0.00 |    57.14 |      0.00 |         0.00 |    0.07 |   0.00 | 25-06-04 23:22 | 25-06-05 00:22
--  RaftUpdateConsensus                                |                    4 |  0.32 | 99.82 |  0.00 |     0.00 |      0.00 |         0.00 |    0.00 |   0.00 | 25-06-04 23:22 | 25-06-05 00:22
--  0                                                  |                    0 |  0.25 | 91.12 |  0.00 |     0.00 |      8.88 |         0.00 |    0.00 |   0.00 | 25-06-04 23:22 | 25-06-05 00:22
--  CatalogRequests                                    |                    5 |  0.10 |  6.18 |  0.00 |     8.71 |      0.00 |        85.11 |    0.00 |   0.00 | 25-06-04 23:22 | 25-06-05 00:21
--  SELECT now() as ts, schemaname, tablename,         |  9159551904200361675 |  0.10 |  1.14 |  0.00 |     0.57 |      0.00 |        98.29 |    0.00 |   0.00 | 25-06-04 23:24 | 25-06-05 00:19
