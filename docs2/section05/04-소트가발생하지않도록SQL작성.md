# 04. 소트가발생하지않도록SQL작성

- 데이터 모델 측면에서는 이상이 없으나, 불필요한 소트가 발생하도록 SQL을 작성하는 경우



### UNION ALL VS UNION

- union all : 중복을 확인하지 않고 두 집합을 단순히 결합하므로 소트 부하가 없음
- union : 중복을 제거하므로 정렬(SORT) 발생



#### union 쿼리

```sql
SELECT empno, job, mgr FROM emp WHERE deptno = 10
UNION
SELECT empno, job, mgr FROM emp WHERE deptno = 20
;

Execution Plan
----------------------------------------------------------
Plan hash value: 3774834881

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |    10 |   190 |     8  (63)| 00:00:01 |
|   1 |  SORT UNIQUE        |      |    10 |   190 |     8  (63)| 00:00:01 |
|   2 |   UNION-ALL         |      |       |       |            |          |
|*  3 |    TABLE ACCESS FULL| EMP  |     5 |    95 |     3   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |     5 |    95 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("DEPTNO"=10)
   4 - filter("DEPTNO"=20)
```



#### union all 쿼리

```sql
SELECT empno, job, mgr FROM emp WHERE deptno = 10
UNION ALL
SELECT empno, job, mgr FROM emp WHERE deptno = 20
;

Execution Plan
----------------------------------------------------------
Plan hash value: 1301082189

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |    10 |   190 |     6  (50)| 00:00:01 |
|   1 |  UNION-ALL         |      |       |       |            |          |
|*  2 |   TABLE ACCESS FULL| EMP  |     5 |    95 |     3   (0)| 00:00:01 |
|*  3 |   TABLE ACCESS FULL| EMP  |     5 |    95 |     3   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("DEPTNO"=10)
   3 - filter("DEPTNO"=20)
```



### DISTINCT

- DISTINCT : exists 서브쿼리로 대체함으로써 sort 연산을 없앨 수 있음
- exists 서브쿼리의  : 메인 쿼리로부터 건건이 입력 받은 값에 대한 조건을 만족하는 첫 번째 레코드를 만나는 순간 true를 반환하고 서브쿼리 수행 마치므로 성능 이점이 있다.



#### 튜닝 전 쿼리

아래 쿼리의 경우 "과금 테이블에 `과금연월 + 지역` 순으로 인덱스 구성하면 최적으로 수행됨

- sort 발생시키지 않고 더 적은 블록을 읽고 수행시간도 짧음

```sql
SELECT DISTINCT 과금연월
FROM   과금
WHERE  과금연월 <= :yyyymm
AND    지역 LIKE :reg || '%'

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        4     27.65      98.38      32648    1586208          0          35
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        6     27.65      98.38      32648    1586208          0          35

Rows     Row Source Operation
-------  --------------------------------------------------------------------------
     35  HASH UNIQUE (cr=1586208 pr=32648 pw=0 time=98704640 us)
9845517   PARTITION RANGE ITERATOR PARTITION: 1 KEY  (cr=1586208 pr=32648 ...)
9845517    TABLE ACCESS FULL 과금 (cr=1586208 pr=32648 pw=0 time=70155864 us)
```



#### 튜닝 후 쿼리

- 연월 테이블을 먼저 드라이빙 하자. (existss는 True 확인한 순간 서브쿼리 수행을 마친다)

```sql
SELECT 연월
FROM   연월테이블 a
WHERE  연월 <= :yyyymm
AND    EXISTS (
           SELECT 'x'
           FROM   과금
           WHERE  과금연월 = a.연월
           AND    지역 LIKE :reg || '%'
       )

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        4      0.00       0.01          0         82          0          35
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        6      0.00       0.01          0         82          0          35

Rows     Row Source Operation
-------  -----------------------------------------------------------------------------
     35  NESTED LOOPS SEMI (cr=82 pr=32648 pw=0 time=19568 us)
     36   TABLE ACCESS FULL 연월테이블 (cr=6 pr=0 pw=0 time=557 us)
     35   PARTITION RANGE ITERATOR PARTITION: KEY KEY  (cr=76 pr=0 pw=0 time=853 us)
     35    INDEX RANGE SCAN 과금_N1 (cr=76 pr=0 pw=0 time=683 us)
```



### 사례

![스크린샷 2024-05-17 오전 7.28.35](../../img/175.png)

- 과금연월 콤보박스에서 과금이 발생했던 연월만 보여지게 할 때, 아래의 방법을 활용하자.

```sql
CREATE TABLE day_tb AS
SELECT TO_CHAR( ymd , 'yyyymmdd' ) ymd ,
       TO_CHAR( ymd , 'yyyy' ) year ,
       TO_CHAR( ymd , 'mm' ) month ,
       TO_CHAR( ymd , 'dd' ) day ,
       TO_CHAR( ymd , 'dy' ) weekday ,
       TO_CHAR(next_day(ymd,'MONDAY')-7,'w') week_monthly,
       TO_NUMBER( TO_CHAR( NEXT_DAY( ymd , 'MONDAY' ) - 7 , 'ww' ) ) week_yearly
FROM   (
        SELECT TO_DATE( '19691231' , 'yyyymmdd' ) + ROWNUM ymd
        FROM   dual
        CONNECT BY LEVEL <= 365*100
       ) ;

Table created.


CREATE TABLE yyyymm_tb AS
SELECT SUBSTR( ymd , 1 , 6 ) yyyymm ,
       MIN( ymd ) first_day ,
       MAX( ymd ) LAST_DAY ,
       MIN( year ) year ,
       MIN( month ) month
FROM   day_tb
GROUP  BY SUBSTR( ymd , 1 , 6 ) ;
Table created.
```
