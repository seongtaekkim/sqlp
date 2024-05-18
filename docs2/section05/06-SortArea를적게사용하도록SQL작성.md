# 06. SortArea를적게사용하도록SQL작성

소트 연산이 불가피하다면 메모리 내에서 처리를 완료할 수 있도록 노력해야 하다. Sort Area 크기를 늘리는 방법도 있지만 그 전에 Sort Area를 적게 사용할 방법부터 찾는 것이 순서다.



## 1) 소트를 완료하고 나서 데이터 가공하기

특정 기간에 발생한 주문 상품 목록을 파일로 내리고자 한다. 아래 두 SQL 중 어느쪽이 Sort Area를 사용할까?

```sql
SELECT LPAD( 상품번호 , 30 ) || LPAD( 상품명 , 30 ) || LPAD( 고객id , 10 )
       || LPAD( 고객명 , 20 ) || TO_CHAR( 주문일시 , 'yyyymmdd hh24:mi:ss' )
FROM   주문상품
WHERE  주문일시 BETWEEN :start
AND    :end
ORDER  BY 상품번호
```

```sql
SELECT LPAD( 상품번호 , 30 ) || LPAD( 상품명 , 30 ) || LPAD( 고객id , 10 )
       || LPAD( 고객명 , 20 ) || TO_CHAR( 주문일시 , 'yyyymmdd hh24:mi:ss' )
FROM   주문상품
WHERE  주문일시 BETWEEN :start
AND    :end
ORDER  BY 상품번호
```

- 1번 SQL은 레코드당 105(30+30+10+20+15) 바이트(헤더 정보는 제외하고 데이터 값만)로 가공된 결과치를 Sort Area에 담는다.
- 반면 2번 SQL은 가공되지 않은 상태로 정렬을 완료하고 나서 최종 출력할 때 가공하므로 1번 SQL에 비해 Sort Area를 훨씬 적게 사용한다. 실제 테스트해 보면 Sort Area 사용량에 큰 차이가 나는 것을 관찰할 수 있다.



## 2) Top-N 쿼리

Top-N 퀴리 형태로 작성하면 소트 연산(=값 비교) 횟수를 최소함함은 물론 Sort Area 사용량을 줄일 수 있다. 우선 Top-N 쿼리 작성법부터 살펴보자.
SQL Server나 Sybase는 Top-N 쿼리를 아래와 같이 손쉽게 작성할 수 있다.

```sql
SELECT TOP 10
       거래일시 ,
       채결건수 ,
       체수량 ,
       거래대금
FROM   시간대별종목거래
WHERE  종목코드 = 'KR123456'
AND    거래일시 >= '20080304'
```

IBM DB2에서도 아래와 같이 쉽게 작성할 수 있다.

```sql
SELECT 거래일시 ,
       채결건수 ,
       체수량 ,
       거래대금
FROM   시간대별종목거래
WHERE  종목코드 = 'KR123456'
AND    거래일시 >= '20080304'
ORDER  거래일시
FETCH  FIRST 10 ROWS ONLY 
```

오라클에서는 아래처럼 인라인 뷰로 한번 감싸야 하는 불편함이 있다.

```sql
SELECT *
FROM   (
        SELECT 거래일시 ,
               채결건수 ,
               체수량 ,
               거래대금
        FROM   시간대별종목거래
        WHERE  종목코드 = 'KR123456'
        AND    거래일시 >= '20080304'
        ORDER  거래일시
       )
WHERE  ROWNUM <= 10
```

위 쿼리를 수행하는 시점에 `종목코드 + 거래일시` 순으로 구성된 인덱스가 존재한다면 옵티마이저는 그 인덱스를 이용함으로써 order by 연산을 대체할 수 있다. 아래 실행계획에서 sort order by 오퍼레이션이 나타나지 않은 것을 확인하기 바란다.

```sql
Execution Plan
------------------------------------------------------------------------------
0    SELECT STATEMENT Optimizer=ALL_ROWS
1  0   COUNT (STOPKEY)
2  1     VIEW
3  2       TABLE ACCESS (BY INDEX ROWID) OF '시간별종목거래' (TABLE)
4  3         INDEX (RANGE SCAN) OF '시간별종목거래_PK' (INDEX (UNIQUE))
```

그뿐만 아니라 rownum 조건을 사용해 N건에서 멈추도록 했으므로 조건절에 부합하는 레코드가 아무리 많아도 매우 빠른 수행속도를 낼 수 있다. 
(실행계획에 표시된 count stopkey가 그것을 의미한다.)



*Top-N 쿼리의 소트 부하 경감 원리
`종목코드 + 거래일시` 순으로 구성된 인덱스가 없을 때는 어떤가? 종목코드만을 선두로 갖는 다른 인덱스를 사용하거나 Full Table Scan 방식으로 처리할 텐데, 이때는 정렬 작업이 불가피하다. 하지만 Top-N 쿼리 알고리즘이 효과를 발휘해 sort order by 부하를 경감시켜준다.

- Top-N 쿼리 알고리즘에 대해 간단히 설명하면, rownum <= 10 이면 우선 10개 레코드를 담을 배열을 할당하고, 처음 읽은 10개 레코드를 정렬된 상태로 담는다.(위렝서 예시한 쿼리는 거래일시 순으로 정렬하고 있지만, 설명을 단순화하려고 숫자로 표현하였다.)





이후 읽는 레코드에 대해서는 맨 우측에 있는 값(=가장 큰 값)과 비교해서 그보다 작은 값이 나타날 때만 배열에서 다시 정렬을 시도한다. 물론 맨 우측에 있던 값은 버린다. 이 방식으로 처리하면 전체 레코드를 정렬하지 않고도 오름차순(ASC)으로 최소값을 갖는 10개 레코드를 정확히 찾아낼 수 있다. 이것이 Top-N 쿼리가 소트 연산 횟수와 Sort Area 사용량을 줄여주는 원리다.
실제 소트 부하 경감 효과를 측정해보자.

#### 효과 측정 : Top-N 쿼리가 작동할 때

```sql
CREATE TABLE t AS
SELECT *
FROM   all_objects ;

alter session set workarea_size_policy = manual;

alter session set sort_area_size = 524288;

set autotrace traceonly statistics
SELECT COUNT( * )
FROM   t ;

Statistics
----------------------------------------------------------
         28  recursive calls
          0  db block gets
        626  consistent gets
        569  physical reads
          0  redo size
        426  bytes sent via SQL*Net to client
        400  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
```

- 테이블을 스캔하면서 전체 레코드 개수를 구하는데 626개 블록을 읽었다.
  이제 Top-N 쿼리를 수행해 보자. Top-N 쿼리가 작동하지 않을 때와 비교하려고 위에서 **Sort Area 크기를 작게 설정한 것을 확인하기 바란다.**

```sql
SELECT *
FROM   (
      SELECT *
        FROM   t
       ORDER  BY object_name
      )
WHERE  ROWNUM <= 10 ;

10 개의 행이 선택되었습니다.


Statistics
----------------------------------------------------------
        270  recursive calls
          0  db block gets
        701  consistent gets
          0  physical reads
          0  redo size
       1804  bytes sent via SQL*Net to client
        400  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          1  sorts (memory)
          0  sorts (disk)
         10  rows processed
```

- 읽은 블록 수는 count(*) 쿼리일 때와 같다. 테이블 전체를 읽은 것이다. sorts 항목을 보면 메모리 소트 방식으로 정렬 작업을 한 번 수행하였다. 아래는 SQL 트레이스 결과인데, sort order by 옆에 stopkey가 표시되었고, physical write(=pw) 항목이 0인 것에 주목하자.

```sql
********************************************************************************

SELECT *
FROM   (
        SELECT *
        FROM   t
        ORDER  BY object_name
       )
WHERE  ROWNUM <= 10 

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.04       0.04          0        573          0          10
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.04       0.04          0        573          0          10

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
     10  COUNT STOPKEY (cr=573 pr=0 pw=0 time=46077 us)
     10   VIEW  (cr=573 pr=0 pw=0 time=46051 us)
     10    SORT ORDER BY STOPKEY (cr=573 pr=0 pw=0 time=46046 us)
  40787     TABLE ACCESS FULL T (cr=573 pr=0 pw=0 time=36 us)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  SQL*Net message from client                     2        0.08          0.08
********************************************************************************
```

*효과 측정 : Top-N 쿼리가 작동하지 않을 때

아래는 Top-N 쿼리 알고리즘이 작동하지 않는 경우다. 쿼리 결과는 동일하도록 작성하였다.

```sql
SELECT *
FROM   (
       SELECT a.* ,
               ROWNUM no
        FROM   (
               SELECT *
               FROM   t
               ORDER  BY object_name
              ) a
       )
WHERE  no <= 10 ;

10 개의 행이 선택되었습니다.


Statistics
----------------------------------------------------------
         13  recursive calls
        204  db block gets
        675  consistent gets
       2341  physical reads
          0  redo size
       1841  bytes sent via SQL*Net to client
        400  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          1  sorts (disk)
         10  rows processed
```

`sorts (disk)` 항목을 보고 정렬을 디스크 소트 방식으로 한 번 수행한 것을 알 수 있고, physical reads 항목이 2341인 것도 눈에 띈다. 아래는 SQL 트레이스 결과인데, sort order by 옆에 stopkey가 없고 physical write(=pw) 항목이 2341인 것을 확인하자.

```sql
********************************************************************************

SELECT *
FROM   (
        SELECT a.* ,
               ROWNUM no
        FROM   (
                SELECT *
                FROM   t
                ORDER  BY object_name
               ) a
       )
WHERE  no <= 10 

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.68       1.33       2341        573        204          10
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.68       1.33       2341        573        204          10

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
     10  VIEW  (cr=573 pr=2341 pw=2341 time=1334922 us)
  40787   COUNT  (cr=573 pr=2341 pw=2341 time=1295923 us)
  40787    VIEW  (cr=573 pr=2341 pw=2341 time=1255130 us)
  40787     SORT ORDER BY (cr=573 pr=2341 pw=2341 time=1255127 us)
  40787      TABLE ACCESS FULL T (cr=573 pr=0 pw=0 time=37 us)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  direct path write temp                        639        0.00          0.05
  direct path read temp                        1202        0.02          0.65
  SQL*Net message from client                     2        0.08          0.08
********************************************************************************
```

- 같은 양(573 블록)의 데이타를 읽고 정렬을 수행하였는데, 앞에서는 Top-N 쿼리 알고리즘이 작동해 메모리 내에서 정렬을 완료했지만 조금 전 쿼리는 디스크를 이용해야만 했다.



## 3) 분석함수에서의 Top-N 쿼리

- window sort 시에도 rank()나 row_number()를 쓰면 Top-N 쿼리 알고리즘이 작동해 max() 등 함수를 쓸 때보다 소트 부하를 경감시켜 준다. 테스트를 통해 같이 확인해 보자.
- 먼저 아래와 같이 테스트 데이터를 생성한다. 같은 ID가 10개씩 되도록 테이블을 만들고, Seq 컬럼을 두어 ID가 레코드를 식별할 수 있도록 하였다.

```sql
CREATE TABLE t AS
SELECT 1 id ,
       ROWNUM seq ,
       owner ,
        object_name ,
        object_type ,
       created ,
       status
FROM   all_objects ;

BEGIN
    FOR i IN 1..9
    LOOP
     INSERT
     INTO   t
     SELECT i + 1 id ,
             ROWNUM seq ,
            owner ,
            object_name ,
             object_type ,
             created ,
            status
     FROM   t
    WHERE  id = 1 ;
     COMMIT;
   END LOOP;
  END;
/


alter session set workarea_size_policy = manual;

alter session set sort_area_size = 1048576;

```

아래는 마지막 이력 레코드를 찾는 쿼리다

```sql
********************************************************************************

SELECT id ,
       seq ,
       owner ,
       object_name ,
       object_type ,
       created ,
       status
FROM   (
        SELECT id ,
               seq ,
               MAX( seq ) over( PARTITION BY id ) last_seq ,
               owner ,
               object_name ,
               object_type ,
               created ,
               status
        FROM   t
       )
WHERE  seq = last_seq 

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          1          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      3.21      11.63      16834       3847        165          10
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      3.21      11.63      16834       3848        165          10

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
     10  VIEW  (cr=3847 pr=16834 pw=13063 time=11633709 us)
 407870   WINDOW SORT (cr=3 
 847 pr=16834 pw=13063 time=11358985 us)
 407870    TABLE ACCESS FULL T (cr=3847 pr=0 pw=0 time=29 us)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  direct path write temp                       3664        0.05          2.04
  control file sequential read                   52        0.01          0.13
  db file sequential read                         8        0.00          0.02
  db file single write                            4        0.00          0.00
  control file parallel write                    12        0.00          0.00
  rdbms ipc reply                                 4        0.02          0.02
  local write wait                               16        0.00          0.00
  direct path read temp                       11995        0.11          4.92
  SQL*Net message from client                     2        0.08          0.08
********************************************************************************
```

디스크 소트가 발생하도록 하려고 sort_area_size를 줄여 테스트하였고, 실제 window sort 단계에서 16,834개의 physical read(=pr)와 13,063개의 physical write(=pr)가 발생했다.

```sql
********************************************************************************

SELECT id ,
       seq ,
       owner ,
       object_name ,
       object_type ,
       created ,
       status
FROM   (
        SELECT id ,
               seq ,
               RANK( ) over( PARTITION BY id
                             ORDER     BY seq DESC ) rnum ,
               owner ,
               object_name ,
               object_type ,
               created ,
               status
        FROM   t
       )
WHERE  rnum =1 

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.89       1.03        394       3847        525          10
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.89       1.03        394       3847        525          10

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
     10  VIEW  (cr=3847 pr=394 pw=394 time=1031300 us)
     46   WINDOW SORT PUSHED RANK (cr=3847 pr=394 pw=394 time=1031262 us)
 407870    TABLE ACCESS FULL T (cr=3847 pr=0 pw=0 time=39 us)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                       2        0.00          0.00
  direct path write temp                        131        0.00          0.02
  direct path read temp                         394        0.01          0.10
  SQL*Net message from client                     2        0.08          0.08
********************************************************************************
```

- 여기서도 physcal read와 physcal write가 각각 394개씩 발생하긴 했지만 앞에서보다 훨씬 줄었다. 10초 가량 시간이 덜 소요된 것도 이 때문이다.