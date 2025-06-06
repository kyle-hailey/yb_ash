

topsql.sql

top sql by aas with breakdown% of time by wait types

<pre>
                       sql_text                     |       query_id       | aas  |  Cpu%  | Network% | RAFT_REP% | DiskIO% | LOCK% | other% 
----------------------------------------------------+----------------------+------+--------+----------+-----------+---------+-------+--------
 SELECT sum(A.id) FROM AJOIN B ON A.category = B.f  |  7346864737869673583 | 2.76 |  12.09 |    83.68 |      0.00 |    4.23 |  0.00 |   0.00
 SELECT titleFROM heavy_payload_textWHERE id +$2    |  -506067113979175153 | 2.62 |   7.50 |    75.48 |      0.00 |   17.03 |  0.00 |   0.00
 select count(*) from authors where id < ( select m |  5798349130830498739 | 0.81 |  45.68 |    54.32 |      0.00 |    0.00 |  0.00 |   0.00
</pre>
