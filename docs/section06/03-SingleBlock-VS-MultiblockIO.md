# 03. SingleBlock-VS-MultiblockIO





```sql
call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.26       0.26          64        69          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.26       0.26          64        69          0           1
```

- 위 Call 통계를 보면, 버퍼 캐시에서 69개 블록을 읽으면서 그 중 64개는 디스크에서 읽었다.
- 버퍼 캐시 히트율은 7.24%(= 1 - (64 / 69) X 100)다.
- 디스크에서 읽은 블록 수가 64개라고 I/O Call까지 64번 발생했음을 의미하지는 않는다.
- 64번일 수도 있고, 그보다 작을 수도 있다.



###### 읽고자 하는 블록을 버퍼 캐시에서 찾지 못했을 때, I/O Call을 통해 데이터파일로부터 버퍼 캐시에 적재하는 방식에는 크게 두 가지가 있다.

- Single Block I/O

  - 한번의 I/O Call에 하나의 데이터 블록만 읽어 메모리에 적재하는 방법. 인덱스를 통한 Table Acess일 경우 인덱스와 테이블 모두 이방식을 사용

- Multiblock I/O

  -  Call이 필요한 시점에 인접한 블록들을 같이 읽어 메모리에 적재하는 방법. Extent 범위 단위에서 읽는다.db_file_muliblock_read_count 파라미터에 의해 결정된다.
  - 인접한 블록 : 하나의 익스텐트에 내에 속한 블록
  - 파라미터가 16이면 한 번에 최대 16개 블록을 버퍼 캐시에 적재한다.
  - 만약 db_block_size가 8,192 바이트면 한 번에 최대 131,072 바이트를 읽는 셈이 된다.
  - 대개 OS 레벨에서 I/O 단위가 1MB 이므로 db_block_size가 8,192 일 때는 최대 설정할 수 있는 값은 128이 된다.
  - 이 파라미터를 128 이상으로 설정하더라도 OS가 허용하는 I/O 단위가 1MB면 1MB씩만 읽는다.

  

##### 인덱스 스캔은 왜 한 블록씩 읽을까?

- 인덱스는 리프블록끼리 Double Linked List 구조로 연결되어 있어, 물리적으로 한 Extent에 속한 블록들을 I/O Calll발생 시점에 같이 적재하여 올렸을 때, 그 블록들이 논리적 순서로는 한참 뒤쪽에 위치할 수 있으므로, 실제 사용되지 못한 채 버퍼상에서 밀려 날 수도 있으므로 Singl Block I/O방식이 효율적이다.
- Index Range Scan 뿐 아니라 Index Full Scan시에도 논리적인 순서에 따라 Single Block I/O방식으로 읽는다.
- `Index Fast Full Scan`은 Multiblock I/O 방식을 사용하도록 강제하는 방식이다.





###### 서버 프로세스는 Disk에서 블록을 읽어야 하는 시점마다 I/O 서브시스템에 I/O 요청을 하고 대기 상태에 빠지는데 대표적인 대기 이벤트는 다음과 같다.

- db file sequential read 대기 이벤트 : Single Block I/O방식으로 I/O를 요청할 때 발생(index scan)
- db file scattered read 대기 이벤트 : Multiblock I/O방식으로 I/O를 요청할 때 발생(full scan)

```sql
-- sequential, scattered 평균 대기 시간
select a.average_wait "SEQ READ", b.average_wait "SCAT READ"
  from sys.v_$system_event a, sys.v_$system_event b
  where a.event = 'db file sequential read'
  and b.event = 'db file scattered read';

  SEQ READ  SCAT READ
---------- ----------
       .83       3.42
```



- 대량의 데이터를 Multiblock I/O 방식으로 읽을 때 Single Block I/O 보다 성능상 유리한 것은 I/O Call 발생횟수를 그만큼 줄여주기 때문이다.

```sql
drop table t purge;

create table t
as
select * from all_objects;

alter table t add
constraint t_pk primary key(object_id);

-- # Oracle 버전 : 10g(db_file_multiblock_read_count = 16)
select /*+ index(t) */ count(*)
from t where object_id > 0

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.01          0          3          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.02       0.01         84         90          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.03       0.03         84         93          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=90 pr=84 pw=0 time=17665 us)
  42672   INDEX RANGE SCAN T_PK (cr=90 pr=84 pw=0 time=42702 us)(object id 109394)

Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  db file sequential read                        84        0.00          0.00
  SQL*Net message from client                     2       12.00         12.00


-- db_file_multiblock_read_count = 128
select /*+ index(t) */ count(*)
from t where object_id > 0

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.01          0          3          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.01       0.03        142        147          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.02       0.04        142        150          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 85

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=147 pr=142 pw=0 time=0 us)
  70417   INDEX RANGE SCAN T_PK (cr=147 pr=142 pw=0 time=19552 us cost=160 size=986076 card=75852)(object id 84135)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  db file scattered read                         19        0.01          0.02
  db file sequential read                        10        0.00          0.00
  SQL*Net message from client                     2        0.00          0.00

-- # Oracle 버전 : 11g(db_file_multiblock_read_count = 128)
-------------------------------------------------p1------p2-----------p3----------------------------------
WAIT #17: nam='db file scattered read' ela= 57 file#=5 block#=316425 blocks=7 obj#=84135 tim=1342509778986042
WAIT #17: nam='db file scattered read' ela= 53 file#=5 block#=316433 blocks=7 obj#=84135 tim=1342509778986786
WAIT #17: nam='db file sequential read' ela= 13 file#=5 block#=316440 blocks=1 obj#=84135 tim=1342509778987499
WAIT #17: nam='db file scattered read' ela= 83 file#=5 block#=316441 blocks=7 obj#=84135 tim=1342509778987725
WAIT #17: nam='db file scattered read' ela= 55 file#=5 block#=316449 blocks=7 obj#=84135 tim=1342509778988423
WAIT #17: nam='db file sequential read' ela= 13 file#=5 block#=356608 blocks=1 obj#=84135 tim=1342509778989066
WAIT #17: nam='db file scattered read' ela= 53 file#=5 block#=356609 blocks=7 obj#=84135 tim=1342509778989246
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=356617 blocks=7 obj#=84135 tim=1342509778989937
WAIT #17: nam='db file sequential read' ela= 12 file#=5 block#=356624 blocks=1 obj#=84135 tim=1342509778990587
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=356625 blocks=7 obj#=84135 tim=1342509778990776
WAIT #17: nam='db file scattered read' ela= 53 file#=5 block#=356633 blocks=7 obj#=84135 tim=1342509778991467
WAIT #17: nam='db file sequential read' ela= 13 file#=5 block#=356640 blocks=1 obj#=84135 tim=1342509778992107
WAIT #17: nam='db file scattered read' ela= 52 file#=5 block#=356641 blocks=7 obj#=84135 tim=1342509778992291
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=356649 blocks=7 obj#=84135 tim=1342509778992984
WAIT #17: nam='db file sequential read' ela= 12 file#=5 block#=356656 blocks=1 obj#=84135 tim=1342509778993612
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=356657 blocks=7 obj#=84135 tim=1342509778993800
WAIT #17: nam='db file scattered read' ela= 53 file#=5 block#=356665 blocks=7 obj#=84135 tim=1342509778994489
WAIT #17: nam='db file sequential read' ela= 12 file#=5 block#=356672 blocks=1 obj#=84135 tim=1342509778995128
WAIT #17: nam='db file scattered read' ela= 52 file#=5 block#=356673 blocks=7 obj#=84135 tim=1342509778995307
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=356681 blocks=7 obj#=84135 tim=1342509778995996
WAIT #17: nam='db file sequential read' ela= 12 file#=5 block#=356688 blocks=1 obj#=84135 tim=1342509778996629
WAIT #17: nam='db file scattered read' ela= 55 file#=5 block#=356689 blocks=7 obj#=84135 tim=1342509778996819
WAIT #17: nam='db file scattered read' ela= 71 file#=5 block#=273538 blocks=6 obj#=84135 tim=1342509778997726
WAIT #17: nam='db file sequential read' ela= 13 file#=5 block#=273544 blocks=1 obj#=84135 tim=1342509778998293
WAIT #17: nam='db file scattered read' ela= 54 file#=5 block#=273545 blocks=7 obj#=84135 tim=1342509778998473
WAIT #17: nam='db file sequential read' ela= 13 file#=5 block#=273552 blocks=1 obj#=84135 tim=1342509778999111
WAIT #17: nam='db file scattered read' ela= 52 file#=5 block#=273553 blocks=7 obj#=84135 tim=1342509778999288
WAIT #17: nam='db file sequential read' ela= 12 file#=5 block#=273560 blocks=1 obj#=84135 tim=1342509778999923
WAIT #17: nam='db file scattered read' ela= 19127 file#=5 block#=273561 blocks=7 obj#=84135 tim=1342509779019176
----------------------------------------------------------------------------------------------------------
FETCH #17:c=15997,e=34646,p=142,cr=147,cu=0,mis=0,r=1,dep=0,og=1,plh=4152626091,tim=1342509779020141
```

- 위 트레이스(v.10g) 결과를 보면, 논리적으로 93개 블록을 읽는 동안 84개의 디스크 블록을 읽었다.
- 이벤트 발생 현황을 보면 db file sequential read 대기 이벤트가 84번 발생했다.
- 즉, 84개 인덱스 블록을 Disk에서 읽으면서 84번의 I/O Call이 발생한 것이다.



```sql
show parameter db_block_size

NAME                                 TYPE                   VALUE
------------------------------------ ---------------------- ---------------------
db_block_size                        integer                8192

show parameter db_file_multiblock_read_count

NAME                                 TYPE                   VALUE
------------------------------------ ---------------------- ---------------------
db_file_multiblock_read_count        integer                16


show parameter db_block_size

NAME                                 TYPE                   VALUE
------------------------------------ ---------------------- --------------------
db_block_size                        integer                8192

show parameter db_file_multiblock_read_count

NAME                                 TYPE                   VALUE
------------------------------------ ---------------------- --------------------
db_file_multiblock_read_count        integer                128
```

- db_block_size는 8,192이고, Multiblock I/O(db_file_multiblock_read_count) 단위는 16이다.
- 앞에서와 같은 양의 인덱스 블록을 Multiblock I/O 방식으로 읽도록 하기 위해 인덱스를 `index fast full scan` 방식으로 읽도록 유도해 보자. (`index_ffs` 힌트)
- Multiblock I/O 단위가 16이므로 데이터파일에서 똑같이 84개 블록을 읽었을 때 5(=84/16)번의 I/O Call이 발생할 것으로 예상된다.
- 디스크 I/O가 발생하도록 하려면 먼저 테이블과 인덱스를 Drop 했다가 다시 생성해야 한다.



```sql
select /*+ index_ffs(t) */ count(*)
from t where object_id > 0

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.01          0          3          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.02       0.01         84         96          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.03       0.02         84         99          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=96 pr=84 pw=0 time=13522 us)
  42672   INDEX FAST FULL SCAN T_PK (cr=96 pr=84 pw=0 time=42786 us)(object id 109396)

Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  db file scattered read                         12        0.00          0.00
  SQL*Net message from client                     2       13.12         13.12
```

- 똑같이 84개 블록을 디스크에서 읽었는데, I/O Call이 12번에 그쳤다.
- Single Block I/O 할 때보다는 크게 줄었지만 예상했던 5보다는 두 배 많은 수치다.
- 84/12 = 7 이므로 평균 7~8개씩 읽은 셈이다.
- OS에서 I/O 단위가 65,536(=8,192X8) 바이트인 것일까? 트레이스 파일을 열어 확인해 보자.



```sh
-- # Oracle 버전 : 10g(db_file_multiblock_read_count = 16)
EXEC #19:c=0,e=89,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=1,tim=5312766948262
WAIT #19: nam='SQL*Net message to client' ela= 2 driver id=1413697536 #bytes=1 p3=0 obj#=109394 tim=5312766948334
-------------------------------------------------p1------p2-----------p3----------------------------------
WAIT #19: nam='db file scattered read' ela= 74 file#=4 block#=1090 blocks=7 obj#=109396 tim=5312766949324
WAIT #19: nam='db file scattered read' ela= 99 file#=4 block#=1098 blocks=7 obj#=109396 tim=5312766950465
WAIT #19: nam='db file scattered read' ela= 56 file#=4 block#=1105 blocks=8 obj#=109396 tim=5312766951503
WAIT #19: nam='db file scattered read' ela= 80 file#=4 block#=1114 blocks=7 obj#=109396 tim=5312766952696
WAIT #19: nam='db file scattered read' ela= 70 file#=4 block#=1121 blocks=8 obj#=109396 tim=5312766953776
WAIT #19: nam='db file scattered read' ela= 89 file#=4 block#=1130 blocks=7 obj#=109396 tim=5312766954983
WAIT #19: nam='db file scattered read' ela= 66 file#=4 block#=1137 blocks=8 obj#=109396 tim=5312766956031
WAIT #19: nam='db file scattered read' ela= 103 file#=4 block#=1146 blocks=7 obj#=109396 tim=5312766957243
WAIT #19: nam='db file scattered read' ela= 71 file#=4 block#=1153 blocks=8 obj#=109396 tim=5312766958293
WAIT #19: nam='db file scattered read' ela= 74 file#=4 block#=1674 blocks=7 obj#=109396 tim=5312766959489
WAIT #19: nam='db file scattered read' ela= 78 file#=4 block#=1681 blocks=8 obj#=109396 tim=5312766960565
WAIT #19: nam='db file scattered read' ela= 28 file#=4 block#=1690 blocks=2 obj#=109396 tim=5312766961684
----------------------------------------------------------------------------------------------------------
FETCH #19:c=20000,e=13521,p=84,cr=96,cu=0,mis=0,r=1,dep=0,og=1,tim=5312766961918
WAIT #19: nam='SQL*Net message from client' ela= 585 driver id=1413697536 #bytes=1 p3=0 obj#=109396 tim=5312766962645
FETCH #19:c=0,e=1,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=0,tim=5312766962722
WAIT #19: nam='SQL*Net message to client' ela= 1 driver id=1413697536 #bytes=1 p3=0 obj#=109396 tim=5312766962782
*** 2012-07-10 10:52:27.291
WAIT #19: nam='SQL*Net message from client' ela= 13126184 driver id=1413697536 #bytes=1 p3=0 obj#=109396 tim=5312780089022
STAT #19 id=1 cnt=1 pid=0 pos=1 obj=0 op='SORT AGGREGATE (cr=96 pr=84 pw=0 time=13522 us)'
STAT #19 id=2 cnt=42672 pid=1 pos=1 obj=109396 op='INDEX FAST FULL SCAN T_PK (cr=96 pr=84 pw=0 time=42786 us)'
=====================
```

- db file scattered read 대기 이벤트가 실제 12번 발생한 것을 볼 수 있고, 세 번째 파라미터(p3)를 보면 마지막 것만 빼고 매번 7개 또는 8개씩을 읽었다.
- 테이블스페이스에 할당된 익스텐트 크기를 확인해 보면 그 이유를 쉽게 찾을 수 있다.

```sql
select extent_id, block_id, bytes, blocks
  from dba_extents
  where owner = USER
  and   segment_name = 'T_PK'
  and   tablespace_name = 'USERS'
  order by extent_id ;

 EXTENT_ID   BLOCK_ID      BYTES     BLOCKS
---------- ---------- ---------- ----------
         0       1081      65536          8
         1       1089      65536          8
         2       1097      65536          8
         3       1105      65536          8
         4       1113      65536          8
         5       1121      65536          8
         6       1129      65536          8
         7       1137      65536          8
         8       1145      65536          8
         9       1153      65536          8
        10       1673      65536          8
        11       1681      65536          8
        12       1689      65536          8

13 개의 행이 선택되었습니다.
```

- 모든 익스텐트가 8개 블록으로 구성돼 있는 것이 원인이었다.
- Multiblock I/O 방식으로 읽더라도 익스텐트 범위를 넘지는 못한다고 앞에서 설명했다.
- 예를 들어, 모든 익스텐트에 20개 블록이 있고 db_file_multiblock_read_count가 8이면, 익스텐트마다 8, 8, 4개씩 세 번에 걸쳐 읽는다.



###### 익스텐트 크기 때문에 예상보다 조금 더 많은 I/O Call이 발생하긴 했지만, Single Block I/O 때보다 훨씬 적은 양의 I/O Call이 발생하는 것을 알 수 있었다.

- 10g 부터는 테이블 액세스 없이 인덱스만 처리 할때는 Index Range Scan 또는 Index Full Scan 일 때도 Multiblock I/O 방식으로 읽는 경우가 있다.
- Singl Block I/O 방식으로 읽은 블록들은 LRU 리스트 상 MRU쪽 end로 연결되므로 한번 적재되면 버퍼 캐시에 비교적 오래 머문다.
- Multiblock I/O 방식으로 읽은 블록들은 LRU 리스트에서 LRU쪽 end로 연결되므로 적재되고 얼마 지나지 않아 버퍼캐시에서 밀려난다.