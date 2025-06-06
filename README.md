

## topsql.sql

top sql by aas with breakdown% of time by wait types

<pre>
                       sql_text                     |       query_id       | aas  |  Cpu%  | Network% | RAFT_REP% | DiskIO% | LOCK% | other% 
----------------------------------------------------+----------------------+------+--------+----------+-----------+---------+-------+--------
 SELECT sum(A.id) FROM AJOIN B ON A.category = B.f  |  7346864737869673583 | 2.76 |  12.09 |    83.68 |      0.00 |    4.23 |  0.00 |   0.00
 SELECT title FROM heavy_payload_text WHERE id +$2  |  -506067113979175153 | 2.62 |   7.50 |    75.48 |      0.00 |   17.03 |  0.00 |   0.00
 select count(*) from authors where id < ( select m |  5798349130830498739 | 0.81 |  45.68 |    54.32 |      0.00 |    0.00 |  0.00 |   0.00
</pre>



## top_node.sql

shows "total" AAS by node as well as  with breakdown% of time by wait types

<pre>
   node | total | Cpu%  | Lock% | Network% | RAFT_REP% | CatalogRead% | DiskIO% | other% |      mnt       |      mxt       
--------+-------+-------+-------+----------+-----------+--------------+---------+--------+----------------+----------------
   2    |  0.03 | 70.00 |  0.00 |     3.33 |      6.67 |        16.67 |    3.33 |   0.00 | 25-06-04 12:22 | 25-06-04 12:36
   3    |  0.03 | 62.07 |  0.00 |     0.00 |      0.00 |        37.93 |    0.00 |   0.00 | 25-06-04 12:22 | 25-06-04 12:36
   1    |  0.03 | 50.00 |  0.00 |     0.00 |      0.00 |        38.46 |    3.85 |   3.85 | 25-06-04 12:22 | 25-06-04 12:36
</pre>
