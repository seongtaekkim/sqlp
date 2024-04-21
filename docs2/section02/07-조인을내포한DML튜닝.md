# 07. 조인을내포한DML튜닝



## 1) 수정 가능 조인 뷰 활용



### 1] 전통적인 방식의 UPDATE

```sql
-- 고객 테이블 및 데이터 생성

CREATE TABLE 고객 AS
SELECT LEVEL AS 고객번호
     , (SELECT SYSDATE - CEIL(DBMS_RANDOM.VALUE(1, 365)) FROM DUAL) AS 최종거래일시
     , 0 AS 최근거래횟수
     , 0 AS 최근거래금액
FROM DUAL
CONNECT BY LEVEL <= 1000000;

테이블이 생성되었습니다.

- 고객 테이블 인덱스 생성
ALTER TABLE 고객 ADD CONSTRAINT IDX_고객_PK PRIMARY KEY(고객번호);

테이블이 변경되었습니다.

- 거래 테이블 및 데이터 생성
CREATE TABLE 거래 AS
SELECT CEIL(LEVEL / 1000000) 고객번호
     , ADD_MONTHS(SYSDATE,-4) + FLOOR( DBMS_RANDOM.VALUE(1,120) ) AS 거래일시
     , (FLOOR( DBMS_RANDOM.VALUE(1,13) )*100) + 500 AS 거래금액
FROM DUAL
CONNECT BY LEVEL <= 10000000;

테이블이 생성되었습니다.
```



```sql
※ SQL TRACE
********************************************************************************
EXPLAIN PLAN FOR
UPDATE 고객 c
SET  최종거래일시 = ( SELECT MAX(거래일시) FROM 거래
                       WHERE 고객번호 = c.고객번호
                       AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
   , 최근거래횟수 = ( SELECT COUNT(*) FROM 거래
                      WHERE 고객번호 = c.고객번호
                       AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
    , 최근거래금액 = ( SELECT SUM(거래금액) FROM 거래
                       WHERE 고객번호 = c.고객번호
                        AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT 'x' FROM 거래
                  WHERE 고객번호 = c.고객번호
                 AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)));

해석되었습니다.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
Plan hash value: 240844059

------------------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | UPDATE STATEMENT    |      |    10 |   700 |       | 13553   (9)| 00:02:43 |
|   1 |  UPDATE             | 고객 |       |       |       |            |          |
|*  2 |   HASH JOIN SEMI    |      |    10 |   700 |    59M| 13553   (9)| 00:02:43 |
|   3 |    TABLE ACCESS FULL| 고객 |  1035K|    47M|       |   720   (6)| 00:00:09 |
|*  4 |    TABLE ACCESS FULL| 거래 |  1832K|    38M|       |  6852  (16)| 00:01:23 |
|   5 |   SORT AGGREGATE    |      |     1 |    22 |       |            |          |
|*  6 |    TABLE ACCESS FULL| 거래 | 18326 |   393K|       |  6135   (6)| 00:01:14 |
|   7 |   SORT AGGREGATE    |      |     1 |    22 |       |            |          |
|*  8 |    TABLE ACCESS FULL| 거래 | 18326 |   393K|       |  6135   (6)| 00:01:14 |
|   9 |   SORT AGGREGATE    |      |     1 |    35 |       |            |          |
|* 10 |    TABLE ACCESS FULL| 거래 | 18326 |   626K|       |  6135   (6)| 00:01:14 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("고객번호"="C"."고객번호")

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
   4 - filter("거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))
   6 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))
   8 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))
  10 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))

Note
-----
   - dynamic sampling used for this statement
```



한 달 이내 거래가 있던 고객을 두번 조회하는 것으로 변경, 총 고객 수와 한 달 이내 거래가 발생한 고객 수에 따라 성능이 좌우된다.

```sql
※ SQL TRACE
********************************************************************************
EXPLAIN PLAN FOR
UPDATE 고객 c
SET  ( 최종거래일시,  최근거래횟수, 최근거래금액 ) =
     ( SELECT MAX(거래일시), COUNT(*), SUM(거래금액)
   FROM 거래
         WHERE 고객번호 = c.고객번호
         AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT 'x' FROM 거래
               WHERE 고객번호 = c.고객번호
               AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)));

해석되었습니다.


SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
Plan hash value: 613077917

------------------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | UPDATE STATEMENT    |      |    10 |   700 |       | 13553   (9)| 00:02:43 |
|   1 |  UPDATE             | 고객 |       |       |       |            |          |
|*  2 |   HASH JOIN SEMI    |      |    10 |   700 |    59M| 13553   (9)| 00:02:43 |
|   3 |    TABLE ACCESS FULL| 고객 |  1035K|    47M|       |   720   (6)| 00:00:09 |
|*  4 |    TABLE ACCESS FULL| 거래 |  1832K|    38M|       |  6852  (16)| 00:01:23 |
|   5 |   SORT AGGREGATE    |      |     1 |    35 |       |            |          |
|*  6 |    TABLE ACCESS FULL| 거래 | 18326 |   626K|       |  6135   (6)| 00:01:14 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("고객번호"="C"."고객번호")
   4 - filter("거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))
   6 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))

Note

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
-----
   - dynamic sampling used for this statement
********************************************************************************

※ TKPROF LOG
********************************************************************************
UPDATE 고객 c
SET  ( 최종거래일시,  최근거래횟수, 최근거래금액 ) =
     ( SELECT MAX(거래일시), COUNT(*), SUM(거래금액)
	FROM 거래
         WHERE 고객번호 = c.고객번호
         AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT 'x' FROM 거래
                 WHERE 고객번호 = c.고객번호
                 AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.00          0          4          0           0
Execute      1     35.79      42.29       3937     292653         20          10
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2     35.81      42.30       3937     292657         20          10

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
      0  UPDATE  고객 (cr=292653 pr=3937 pw=4867 time=42291709 us)
     10   HASH JOIN SEMI (cr=29373 pr=3937 pw=4867 time=16552524 us)
1000000    TABLE ACCESS FULL 고객 (cr=3045 pr=0 pw=0 time=4000037 us)
2352766    TABLE ACCESS FULL 거래 (cr=26328 pr=0 pw=0 time=21174969 us)
     10   SORT AGGREGATE (cr=263280 pr=0 pw=0 time=25322376 us)
2352766    TABLE ACCESS FULL 거래 (cr=263280 pr=0 pw=0 time=29662943 us)
********************************************************************************
```



#### Semi Join (반조인)

선행 Table의 Row가 수행 Table의 Row와 Match되기만 하면 즉각 Join 조건이 만족된 것으로 간주하고 해당 Row에 대해서는 더 이상의 탐색을 진행하지 않는다. 따라서 보다 효율적이다.
Exists와 In Operation의 효율적인 처리를 위한 고안된 Join 방식이다.
주로 Hash Join(Hash Semi Join)의 형태나 Nested Loops Join(Nested Loops Semi Join)의 형태로 구현된다.
Sort Merge Semi Join 또한 이론적으로는 발생 가능하다.

~~~sql
********************************************************************************
※ TKPROF LOG
********************************************************************************
UPDATE 고객 c
SET  최종거래일시 = ( SELECT MAX(거래일시) FROM 거래
                       WHERE 고객번호 = c.고객번호
                       AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
   , 최근거래횟수 = ( SELECT COUNT(*) FROM 거래
                       WHERE 고객번호 = c.고객번호
                       AND 거래일시 >= TRUNC(ADD_MONTHet(SYSDATE, -1)))
   , 최근거래금액 = ( SELECT SUM(거래금액) FROM 거래
                       WHERE 고객번호 = c.고객번호
                       AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT 'x' FROM 거래
                 WHERE 고객번호 = c.고객번호
                 AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.18          0          7          0           0
Execute      1     87.45     115.94      29727     819213         23          10
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2     87.46     116.12      29727     819220         23          10

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
      0  UPDATE  고객 (cr=819213 pr=29727 pw=4867 time=115941430 us)
     10   HASH JOIN SEMI (cr=29373 pr=6550 pw=4867 time=24677884 us)
1000000    TABLE ACCESS FULL 고객 (cr=3045 pr=0 pw=0 time=5000047 us)
2352766    TABLE ACCESS FULL 거래 (cr=26328 pr=2613 pw=0 time=54130598 us)
     10   SORT AGGREGATE (cr=263280 pr=23177 pw=0 time=40484285 us)
2352766    TABLE ACCESS FULL 거래 (cr=263280 pr=23177 pw=0 time=37635492 us)
     10   SORT AGGREGATE (cr=263280 pr=0 pw=0 time=25108757 us)
2352766    TABLE ACCESS FULL 거래 (cr=263280 pr=0 pw=0 time=27684837 us)
     10   SORT AGGREGATE (cr=263280 pr=0 pw=0 time=25310851 us)
2352766    TABLE ACCESS FULL 거래 (cr=263280 pr=0 pw=0 time=27495547 us)

********************************************************************************
~~~





##### 총 고객수가 많다면 exists 서브 쿼리를 아래와 같이 해시 세미 조인으로 유도

```sql
※ SQL TRACE
********************************************************************************
EXPLAIN PLAN FOR
UPDATE 고객 c
SET  ( 최종거래일시,  최근거래횟수, 최근거래금액 ) =
    ( SELECT MAX(거래일시), COUNT(*), SUM(거래금액)
   FROM 거래
        WHERE 고객번호 = c.고객번호
        AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT /*+ unnest hash_sj */ 'x' FROM 거래
               WHERE 고객번호 = c.고객번호
               AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)));

해석되었습니다.

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
Plan hash value: 613077917

------------------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | UPDATE STATEMENT    |      |    10 |   700 |       | 13553   (9)| 00:02:43 |
|   1 |  UPDATE             | 고객 |       |       |       |            |          |
|*  2 |   HASH JOIN SEMI    |      |    10 |   700 |    59M| 13553   (9)| 00:02:43 |
|   3 |    TABLE ACCESS FULL| 고객 |  1035K|    47M|       |   720   (6)| 00:00:09 |
|*  4 |    TABLE ACCESS FULL| 거래 |  1832K|    38M|       |  6852  (16)| 00:01:23 |
|   5 |   SORT AGGREGATE    |      |     1 |    35 |       |            |          |
|*  6 |    TABLE ACCESS FULL| 거래 | 18326 |   626K|       |  6135   (6)| 00:01:14 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("고객번호"="C"."고객번호")
   4 - filter("거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))
   6 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))

Note

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------
-----
   - dynamic sampling used for this statement
********************************************************************************

※ TKPROF LOG
********************************************************************************
UPDATE 고객 c
SET  ( 최종거래일시,  최근거래횟수, 최근거래금액 ) =
     ( SELECT MAX(거래일시), COUNT(*), SUM(거래금액)
	FROM 거래
         WHERE 고객번호 = c.고객번호
         AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))
WHERE EXISTS ( SELECT /*+ unnest hash_sj */ 'x' FROM 거래
                 WHERE 고객번호 = c.고객번호
                 AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)))

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          4          0           0
Execute      1     36.57      42.91       3937     292653         20          10
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2     36.57      42.91       3937     292657         20          10

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54  

Rows     Row Source Operation
-------  ---------------------------------------------------
      0  UPDATE  고객 (cr=292653 pr=3937 pw=4867 time=42912267 us)
     10   HASH JOIN SEMI (cr=29373 pr=3937 pw=4867 time=16109592 us)
1000000    TABLE ACCESS FULL 고객 (cr=3045 pr=0 pw=0 time=4000038 us)
2352766    TABLE ACCESS FULL 거래 (cr=26328 pr=0 pw=0 time=21174967 us)
     10   SORT AGGREGATE (cr=263280 pr=0 pw=0 time=25995009 us)
2352766    TABLE ACCESS FULL 거래 (cr=263280 pr=0 pw=0 time=29817758 us)
********************************************************************************
```



한 달 이내 거래를 발생시킨 고객이 많아 update발생량이 많다면 아래와 같이 변경할 수 있으나, 
모든 고객 레코드에 lock이 발생하고 이전과 같은 값으로 갱신되는 비중이 높을수록 Redo 로그 발생량이 증가

```sql
※ SQL TRACE
********************************************************************************
EXPLAIN PLAN FOR
UPDATE 고객 c
SET  ( 최종거래일시,  최근거래횟수, 최근거래금액 ) =
      ( SELECT NVL(MAX(거래일시), c.최종거래일시)
              , DECODE( COUNT(*), 0, c.최근거래횟수, COUNT(*))
              , NVL(SUM(거래금액), c.최근거래금액)
       FROM 거래
       WHERE 고객번호 = c.고객번호
       AND 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1)));



SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
-----------------------------------------------------------------------------
Plan hash value: 1071116265

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | UPDATE STATEMENT    |      |  1035K|    47M|   720   (6)| 00:00:09 |
|   1 |  UPDATE             | 고객 |       |       |            |          |
|   2 |   TABLE ACCESS FULL | 고객 |  1035K|    47M|   720   (6)| 00:00:09 |
|   3 |   SORT AGGREGATE    |      |     1 |    35 |            |          |
|*  4 |    TABLE ACCESS FULL| 거래 | 18326 |   626K|  6135   (6)| 00:01:14 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("고객번호"=:B1 AND "거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))

Note
-----
   - dynamic sampling used for this statement
********************************************************************************
```

- 다른 테이블과 조인이 필요할때 전통적인 방식의 update문을 사용하면 비효율을 감수해야 한다.





### 2] 수정 가능 조인 뷰

1. 조인뷰는 from절에 두 개 이상 테이블을 가진 뷰를 가리키며, 수정 가능 조인 뷰는 입력, 수정, 삭제가 허용되는 조인 뷰를 말한다.
2. 1쪽 집합과 조인되는 M쪽 집합에만 입력, 수정, 삭제가 허용된다.
3. 수정 가능 조인 뷰를 활용하면 전통적인 방식의 update문에서 참조 테이블을 두번 조인하는 비효율을 없앨 수 있다.

```sql
EXPLAIN PLAN FOR
UPDATE /*+ bypass_ujvc */ --bypass_ujvc 힌트는 view update시에 키보존을 생략할수 있게 해주는 힌트이다.. 
( SELECT /*+ ordered use_hash(c) */	
         c.최종거래일시,  c.최근거래횟수, c.최근거래금액
          , t.거래일시,  t.거래횟수, t.거래금액
FROM ( SELECT 고객번호, MAX(거래일시) 거래일시, COUNT(*) 거래횟수, SUM(거래금액) 거래금액
         FROM 거래
         WHERE 거래일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1))
         GROUP BY 고객번호) t, 고객 c
WHERE  c.고객번호 = t.고객번호
)
SET 최종거래일시 = 거래일시
, 최근거래횟수 = 거래횟수
, 최근거래금액 = 거래금액 ;

해석되었습니다.

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------
Plan hash value: 1452902634

--------------------------------------------------------------------------------------
| Id  | Operation             | Name | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | UPDATE STATEMENT      |      |  1832K|   167M|       | 16119  (10)| 00:03:14 |
|   1 |  UPDATE               | 고객 |       |       |       |            |          |
|*  2 |   HASH JOIN           |      |  1832K|   167M|   104M| 16119  (10)| 00:03:14 |
|   3 |    VIEW               |      |  1832K|    83M|       |  7155  (19)| 00:01:26 |
|   4 |     SORT GROUP BY     |      |  1832K|    61M|       |  7155  (19)| 00:01:26 |
|*  5 |      TABLE ACCESS FULL| 거래 |  1832K|    61M|       |  6859  (16)| 00:01:23 |
|   6 |    TABLE ACCESS FULL  | 고객 |  1035K|    47M|       |   720   (6)| 00:00:09 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("C"."고객번호"="T"."고객번호")
   5 - filter("거래일시">=TRUNC(ADD_MONTHS(SYSDATE@!,-1)))

Note
-----

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------
   - dynamic sampling used for this statement
```



1. 1쪽 집합(dept)과 조인되는 M쪽 집합(emp)의 컬럼을 수정하므로 문제가 없어보이나, 수행하면 에러가 발생한다. 
2. delete, insert 문도 에러가 발생한다.
3. dept테이블에 unique 인덱스를 생성하지 않았기 때문에 생긴 에러이다.
4. 1쪽 집합에 PK제약을 설정하거나 unique 인덱스를 생성하해야 수정 가능 조인 뷰를 통합 입력, 수정, 삭제가 가능하다.
5. dept테이블에 PK제약을 설정하면 emp 테이블은 키 보존 테이블, dept 테이블은 비 키-보존 테이블이 된다.

```sql
CREATE TABLE EMP AS SELECT * FROM SCOTT.EMP;

CREATE TABLE EMP AS SELECT * FROM SCOTT.EMP
             *
1행에 오류:
ORA-00955: 기존의 객체가 이름을 사용하고 있습니다.


CONN / AS SYSDBA
연결되었습니다.
CREATE TABLE EMP AS SELECT * FROM SCOTT.EMP;

테이블이 생성되었습니다.

CREATE TABLE DEPT AS SELECT * FROM SCOTT.DEPT;

테이블이 생성되었습니다.

CREATE OR REPLACE VIEW EMP_DEPT_VIEW AS
SELECT E.ROWID EMP_RID, E.*, D.ROWID DEPT_RID, D.DNAME, D.LOC
FROM EMP E, DEPT D
WHERE E.DEPTNO = D.DEPTNO;

뷰가 생성되었습니다.

UPDATE EMP_DEPT_VIEW SET LOC = 'SEOUL' WHERE JOB = 'CLERK';
UPDATE EMP_DEPT_VIEW SET LOC = 'SEOUL' WHERE JOB = 'CLERK'
                         *
1행에 오류:
ORA-01779: 키-보존된것이 아닌 테이블로 대응한 열을 수정할 수 없습니다


SELECT EMPNO, ENAME, JOB, SAL, DEPTNO, DNAME, LOC
FROM EMP_DEPT_VIEW
ORDER BY JOB, DEPTNO;

     EMPNO ENAME      JOB              SAL     DEPTNO DNAME          LOC
---------- ---------- --------- ---------- ---------- -------------- -------------
      7902 FORD       ANALYST         3000         20 RESEARCH       DALLAS
      7788 SCOTT      ANALYST         3000         20 RESEARCH       DALLAS
      7934 MILLER     CLERK           1300         10 ACCOUNTING     NEW YORK
      7369 SMITH      CLERK            800         20 RESEARCH       DALLAS
      7876 ADAMS      CLERK           1100         20 RESEARCH       DALLAS
      7900 JAMES      CLERK            950         30 SALES          CHICAGO
      7782 CLARK      MANAGER         2450         10 ACCOUNTING     NEW YORK
      7566 JONES      MANAGER         2975         20 RESEARCH       DALLAS
      7698 BLAKE      MANAGER         2850         30 SALES          CHICAGO
      7839 KING       PRESIDENT       5000         10 ACCOUNTING     NEW YORK
      7654 MARTIN     SALESMAN        1250         30 SALES          CHICAGO
      7844 TURNER     SALESMAN        1500         30 SALES          CHICAGO
      7521 WARD       SALESMAN        1250         30 SALES          CHICAGO
      7499 ALLEN      SALESMAN        1600         30 SALES          CHICAGO

14 개의 행이 선택되었습니다.

UPDATE EMP_DEPT_VIEW SET COMM = NVL(COMM, 0) + (SAL * 0.1) WHERE SAL <= 1500;
UPDATE EMP_DEPT_VIEW SET COMM = NVL(COMM, 0) + (SAL * 0.1) WHERE SAL <= 1500
                         *
1행에 오류:
ORA-01779: 키-보존된것이 아닌 테이블로 대응한 열을 수정할 수 없습니다


DELETE FROM EMP_DEPT_VIEW WHERE JOB = 'CLERK';
DELETE FROM EMP_DEPT_VIEW WHERE JOB = 'CLERK'
            *
1행에 오류:
ORA-01752: 뷰으로 부터 정확하게 하나의 키-보전된 테이블 없이 삭제할 수 없습니다


ALTER TABLE DEPT ADD CONSTRAINT DEPT_PK PRIMARY KEY(DEPTNO);

테이블이 변경되었습니다.

UPDATE EMP_DEPT_VIEW SET COMM = NVL(COMM, 0) + (SAL * 0.1) WHERE SAL <= 1500;

7 행이 갱신되었습니다.

SQL> COMMIT;

커밋이 완료되었습니다.
```



### 키 보존 테이블이란?

- 키 보존 테이블이란, 조인된 결과 집합을 통해서도 중복 값 없이 unique하게 식별히 가능한 테이블
- 키 보존 테이블이란, 뷰에 rowid를 제공하는 테이블
- EMP_DEPT_VIEW 뷰에서 rowid를 출력해보면, dept_rid에 중복값이 발생하고, emp_rid는 중복값이 없으며 뷰의 rowid와 일치한다.
- dept테이블의 unique 인덱스를 제거하면 키 보존 테이블이 없기 때문에 뷰에서 rowid를 출력할 수 없다.



```sql
SELECT ROWID, EMP_RID, DEPT_RID, EMPNO, DEPTNO FROM EMP_DEPT_VIEW;

ROWID              EMP_RID            DEPT_RID                EMPNO     DEPTNO
------------------ ------------------ ------------------ ---------- ----------
AAANM6AABAAAOxaAAA AAANM6AABAAAOxaAAA AAANM7AABAAAOxiAAB       7369         20
AAANM6AABAAAOxaAAB AAANM6AABAAAOxaAAB AAANM7AABAAAOxiAAC       7499         30
AAANM6AABAAAOxaAAC AAANM6AABAAAOxaAAC AAANM7AABAAAOxiAAC       7521         30
AAANM6AABAAAOxaAAD AAANM6AABAAAOxaAAD AAANM7AABAAAOxiAAB       7566         20
AAANM6AABAAAOxaAAE AAANM6AABAAAOxaAAE AAANM7AABAAAOxiAAC       7654         30
AAANM6AABAAAOxaAAF AAANM6AABAAAOxaAAF AAANM7AABAAAOxiAAC       7698         30
AAANM6AABAAAOxaAAG AAANM6AABAAAOxaAAG AAANM7AABAAAOxiAAA       7782         10
AAANM6AABAAAOxaAAH AAANM6AABAAAOxaAAH AAANM7AABAAAOxiAAB       7788         20
AAANM6AABAAAOxaAAI AAANM6AABAAAOxaAAI AAANM7AABAAAOxiAAA       7839         10
AAANM6AABAAAOxaAAJ AAANM6AABAAAOxaAAJ AAANM7AABAAAOxiAAC       7844         30
AAANM6AABAAAOxaAAK AAANM6AABAAAOxaAAK AAANM7AABAAAOxiAAB       7876         20
AAANM6AABAAAOxaAAL AAANM6AABAAAOxaAAL AAANM7AABAAAOxiAAC       7900         30
AAANM6AABAAAOxaAAM AAANM6AABAAAOxaAAM AAANM7AABAAAOxiAAB       7902         20
AAANM6AABAAAOxaAAN AAANM6AABAAAOxaAAN AAANM7AABAAAOxiAAA       7934         10

14 개의 행이 선택되었습니다.

ALTER TABLE DEPT DROP PRIMARY KEY;

테이블이 변경되었습니다.

SELECT ROWID, EMP_RID, DEPT_RID, EMPNO, DEPTNO FROM EMP_DEPT_VIEW;
SELECT ROWID, EMP_RID, DEPT_RID, EMPNO, DEPTNO FROM EMP_DEPT_VIEW
                                                    *
1행에 오류:
ORA-01445: 키 보존 테이블이 없는 조인 뷰에서 ROWID를 선택할 수 없음
```



### *_UPDATABLE_COLUMNS 뷰 참조

- 비 키-보존 테이블로부터 온 컬럼은 입력, 갱신, 삭제가 허용되지 않으며, _UPDATABLE_COLUMNS 뷰를 통해 확인 할 수 있다.



```sql
ALTER TABLE DEPT ADD CONSTRAINT DEPT_PK PRIMARY KEY(DEPTNO);

테이블이 변경되었습니다.

INSERT INTO EMP_DEPT_VIEW
(EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO, LOC)
SELECT EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO, LOC
FROM EMP_DEPT_VIEW;

(EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO, LOC)
                                                      *
2행에 오류:
ORA-01776: 조인 뷰에 의하여 하나 이상의 기본 테이블을 수정할 수 없습니다.

SELECT COLUMN_NAME, INSERTABLE, UPDATABLE, DELETABLE
FROM USER_UPDATABLE_COLUMNS
WHERE TABLE_NAME = 'EMP_DEPT_VIEW';

COLUMN_NAME                    INS UPD DEL
------------------------------ --- --- ---
EMP_RID                        YES YES YES
EMPNO                          YES YES YES
ENAME                          YES YES YES
JOB                            YES YES YES
MGR                            YES YES YES
HIREDATE                       YES YES YES
SAL                            YES YES YES
COMM                           YES YES YES
DEPTNO                         YES YES YES
DEPT_RID                       NO  NO  NO
DNAME                          NO  NO  NO

COLUMN_NAME                    INS UPD DEL
------------------------------ --- --- ---
LOC                            NO  NO  NO

12 개의 행이 선택되었습니다.

INSERT INTO EMP_DEPT_VIEW
(EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO)
SELECT EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO
FROM EMP_DEPT_VIEW;

14 개의 행이 만들어졌습니다.

COMMIT;

커밋이 완료되었습니다.
```



### 수정 가능 조인 뷰 제약 회피

- **bypass_ujvc 힌트는 키 보존 테이블이 없더라도 update 수행이 가능하게 하는 힌트이다.**
- **update를 위해 참조하는 집합에 중복 레코드가 없을 때만 이 힌트를 사용해야 한다.**

- emp테이블에서 deptno로 group by한 결과는 unique하기 때문에 이 집합과 조인되는 dept 테이블은 키가 보존됨에도 에러가 발생한다.

```sql
ALTER TABLE DEPT ADD AVG_SAL NUMBER(7,2);

테이블이 변경되었습니다.

UPDATE
(SELECT D.DEPTNO, D.AVG_SAL D_AVG_SAL, E.AVG_SAL E_AVG_SAL
FROM (SELECT DEPTNO, ROUND(AVG(SAL), 2) AVG_SAL FROM EMP GROUP BY DEPTNO) E
      , DEPT D
WHERE D.DEPTNO = E.DEPTNO)
SET D_AVG_SAL = E_AVG_SAL;

SET D_AVG_SAL = E_AVG_SAL
    *
6행에 오류:
ORA-01779: 키-보존된것이 아닌 테이블로 대응한 열을 수정할 수 없습니다

UPDATE /*+ BYPASS_UJVC */
(SELECT D.DEPTNO, D.AVG_SAL D_AVG_SAL, E.AVG_SAL E_AVG_SAL
 FROM (SELECT DEPTNO, ROUND(AVG(SAL), 2) AVG_SAL FROM EMP GROUP BY DEPTNO) E
      , DEPT D
WHERE D.DEPTNO = E.DEPTNO)
SET D_AVG_SAL = E_AVG_SAL;

3 행이 갱신되었습니다.

SELECT * FROM DEPT;

    DEPTNO DNAME          LOC              AVG_SAL
---------- -------------- ------------- ----------
        10 ACCOUNTING     NEW YORK         2916.67
        20 RESEARCH       DALLAS              2175
        30 SALES          CHICAGO          1566.67
        40 OPERATIONS     BOSTON

※ SQL TRACE
********************************************************************************
EXPLAIN PLAN FOR
UPDATE /*+ BYPASS_UJVC */
(SELECT D.DEPTNO, D.AVG_SAL D_AVG_SAL, E.AVG_SAL E_AVG_SAL
FROM (SELECT DEPTNO, ROUND(AVG(SAL), 2) AVG_SAL FROM EMP GROUP BY DEPTNO) E
       , DEPT D
WHERE D.DEPTNO = E.DEPTNO)
SET D_AVG_SAL = E_AVG_SAL;

해석되었습니다.

SQL> SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

PLAN_TABLE_OUTPUT
-----------------------------------------------------------------------------------------
Plan hash value: 1287183684

-----------------------------------------------------------------------------------------
| Id  | Operation                     | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | UPDATE STATEMENT              |         |    28 |  1456 |     4  (25)| 00:00:01 |
|   1 |  UPDATE                       | DEPT    |       |       |            |          |
|   2 |   NESTED LOOPS                |         |    28 |  1456 |     4  (25)| 00:00:01 |
|   3 |    VIEW                       |         |    28 |   728 |     3  (34)| 00:00:01 |
|   4 |     SORT GROUP BY             |         |    28 |   728 |     3  (34)| 00:00:01 |
|   5 |      TABLE ACCESS FULL        | EMP     |    28 |   728 |     2   (0)| 00:00:01 |
|   6 |    TABLE ACCESS BY INDEX ROWID| DEPT    |     1 |    26 |     1   (0)| 00:00:01 |
|*  7 |     INDEX UNIQUE SCAN         | DEPT_PK |     1 |       |     0   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   7 - access("D"."DEPTNO"="E"."DEPTNO")
********************************************************************************

※ TKPROF LOG
********************************************************************************
UPDATE /*+ BYPASS_UJVC */
(SELECT D.DEPTNO, D.AVG_SAL D_AVG_SAL, E.AVG_SAL E_AVG_SAL
 FROM (SELECT DEPTNO, ROUND(AVG(SAL), 2) AVG_SAL FROM EMP GROUP BY DEPTNO) E
       , DEPT D
WHERE D.DEPTNO = E.DEPTNO)
SET D_AVG_SAL = E_AVG_SAL

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.03          0          3          0           0
Execute      1      0.00       0.00          0          8          1           3
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2      0.00       0.03          0         11          1           3

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: SYS

Rows     Row Source Operation
-------  ---------------------------------------------------
      0  UPDATE  DEPT (cr=8 pr=0 pw=0 time=476 us)
      3   NESTED LOOPS  (cr=8 pr=0 pw=0 time=382 us)
      3    VIEW  (cr=3 pr=0 pw=0 time=199 us)
      3     SORT GROUP BY (cr=3 pr=0 pw=0 time=172 us)
     28      TABLE ACCESS FULL EMP (cr=3 pr=0 pw=0 time=137 us)
      3    TABLE ACCESS BY INDEX ROWID DEPT (cr=5 pr=0 pw=0 time=134 us)
      3     INDEX UNIQUE SCAN DEPT_PK (cr=2 pr=0 pw=0 time=49 us)(object id 54078)
********************************************************************************
```







## 2. Merge문 활용

- **DW에서 데이터 적재 작업을 효과적으로 지원하게 위해 오라클 9i부터 merge into 문을 지원.**

1. 전일 발생한 변경 데이터를 기간계 시스템으로 부터 추출 (Extraction)
2. customer_delta 테이블을 DW시스템으로 전송 (Transportation)
3. DW 시스템으로 적재 (Loading)

```sql
MERGE INTO customer t USING customer_delta s ON (t.cust_id = s.cust_id)
WHEN MATCHED THEN UPDATE
  SET t.cust_id = s.cust_id, t.cust_nm = s.cust_nm, t.email = s.email, ...
WHEN NOT MATCHED THEN INSERT
  (cust_id, cust_nm, email, tel_no, region, addr, reg_dt) VALUES
  (s.cust_id, s.cust_nm, s.email, s.tel_no, s.region, s.addr, s.reg_dt);
```



### Optional Clauses

- 10g부터는 update와 insert를 선택적으로 처리할 수 있다.

```sql
MERGE INTO customer t USING customer_delta s ON (t.cust_id = s.cust_id)
WHEN MATCHED THEN UPDATE
  SET t.cust_id = s.cust_id, t.cust_nm = s.cust_nm, t.email = s.email, ...;

MERGE INTO customer t USING customer_delta s ON (t.cust_id = s.cust_id)
WHEN NOT MATCHED THEN INSERT
  (cust_id, cust_nm, email, tel_no, region, addr, reg_dt) VALUES
  (s.cust_id, s.cust_nm, s.email, s.tel_no, s.region, s.addr, s.reg_dt);
```

- merge문으로 수정 가능 조인 뷰의 기능을 대체.



```sql
MERGE INTO dept d
USING (select deptno, round(avg(sal), 2) avg_sal from emp group by deptno) e
ON (d.deptno = e.deptno)
WHEN MATCHED THEN UPDATE set d.avg_sal = e.avg_sal;
```



### Conditional Operations

- 10g에서는 on절에 기술한 조인문외에 추가로 조건절을 기술할 수 있다.

```sql
MERGE INTO customer t USING customer_delta s ON (t.cust_id = s.cust_id)
WHEN MATCHED THEN UPDATE
  SET t.cust_id = s.cust_id, t.cust_nm = s.cust_nm, t.email = s.email, ...
  WHERE reg_dt >= to_char('20000101','yyyymmdd')
WHEN NOT MATCHED THEN INSERT
  (cust_id, cust_nm, email, tel_no, region, addr, reg_dt) VALUES
  (s.cust_id, s.cust_nm, s.email, s.tel_no, s.region, s.addr, s.reg_dt)
  WHERE reg_dt < trunc(sysdate) ;
```



### DELETE Clauses

- 10g에서는 merge문을 이용하여 이미 저장된 데이터를 조건에 따라 지울 수 있다.
- update가 이루어진 결과로서 탈퇴일자가 null이 아닌 레코드만 삭제된다. 탈퇴일자가 null이 아니었어도 merge문을 수행한 결과가 null이면 삭제되지 않는다.



```sql
MERGE INTO customer t USING customer_delta s ON (t.cust_id = s.cust_id)
WHEN MATCHED THEN UPDATE
  SET t.cust_id = s.cust_id, t.cust_nm = s.cust_nm, t.email = s.email, ...
  DELETE WHERE t.withdraw_dt is not null --탈퇴일시가 null이 아닌 레코드 삭제
WHEN NOT MATCHED THEN INSERT
  (cust_id, cust_nm, email, tel_no, region, addr, reg_dt) VALUES
  (s.cust_id, s.cust_nm, s.email, s.tel_no, s.region, s.addr, s.reg_dt);
```



### Merge Into 활용

- 저장하려는 레코드가 기존에 있던 것이면 update를 수행하고, 그렇지 않으면 insert를 수행하는 경우, SQL이 항상 두번씩 수행된다. 
  (select 한번, insert 또는 update 한 번) merger문을 활용하면 SQL이 한번만 수행된다
- 논리I/O발생을 감소하여 SQL 수행 속도 개선





## 3) 다중 테이블 Insert 활용

- **오라클 9i부터는 조건에 따라 여러 테이블에 insert하는 다중 테이블 insert문을 제공한다.**

```sql
INSERT INTO 청구보험당사자 ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
SELECT ...
FROM 청구보험당사자_임시 a, 거래당사자 b
WHERE a,당사자ID =b.당사자ID;

INSERT INTO 자동차사고접수당사자 ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
SELECT ...
FROM 가사고접수당사자_임시 a, 거래당사자 b
WHERE b.당사자구분 NOT IN ( '4','5','6')
AND a,당사자ID =b.당사자ID;
```

- 다중 테이블 insert문을 활용하면 대용량 거래당사자 테이블을 한 번만 읽고 처리할 수 있다.



```sql
INSERT FIRST 
WHEN 구분 = 'A' THEN
  INTO 청구보험당사자 ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
  VALUES ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
WHEN 구분 = 'B' THEN
  INTO 자동차사고접수당사자 ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
  VALUES ( 당사자ID, 접수일자, 접수순번, 담보구분, 청구순번, ...)
SELECT a.당사자ID, a.접수일자, a.접수순번, a.담보구분, a.청구순번, ...
FROM (
	SELECT 'A' 구분
	FROM 청구보험당사자_임시
         UNION ALL
	SELECT 'B' 구분
	FROM 가사고접수당사자_임시
         WHERE 당사자구분 NOT IN ( '4','5','6')
      ) a, 거래당사자 b
WHERE a,당사자ID =b.당사자ID;
```