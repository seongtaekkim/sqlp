# 03. 뷰 Merging



## 1) 뷰 Merging 이란?

- 사람의 눈으로 볼 때는 쿼리를 블록화하는 것이 더 읽기 편하지만 최적화를 수행하는 옵티마이저의 시각에서는 더 불편하다. 그러므로 옵티마이저는 쿼리 블록을 풀어내려는 습성을 갖는다.
- 힌트 : `merge`, `no_merge`



## 2) 단순 뷰(Simple View) Merging

- 조건절과 조인문만을 포함하는 단순 뷰는 `no_merge` 힌트를 사용하지 않는 한 언제든 Merging이 일어난다.

```sql
-- 뷰 생성
create or replace view emp_salesman
as
select empno, ename, job, mgr, hiredate, sal, comm, deptno
from emp
where job = 'SALESMAN';

-- 단순 뷰와 조인
select e.empno, e.ename, e.job, e.mgr, e.sal, d.dname
from   emp_salesman e, dept d
where  d.deptno = e.deptno
and    e.sal   >= 1500
;

-- 뷰 Merging 하지 않고 그대로 최적화시 실행계획
explain plan for
select /*+ no_merge */
      e.empno, e.ename, e.job, e.mgr, e.sal, d.dname
from   emp_salesman e, dept d
where  d.deptno = e.deptno
and    e.sal   >= 1500
;

@plan
select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------
Plan hash value: 3251065420

-------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name            | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                 |     2 |    84 |     4   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                 |                 |       |       |            |          |
|   2 |   NESTED LOOPS                |                 |     2 |    84 |     4   (0)| 00:00:01 |
|*  3 |    TABLE ACCESS BY INDEX ROWID| EMP             |     2 |    58 |     2   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN          | EMP_SAL_IDX     |     8 |       |     1   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN           | DEPT_DEPTNO_IDX |     1 |       |     0   (0)| 00:00:01 |
|   6 |   TABLE ACCESS BY INDEX ROWID | DEPT            |     1 |    13 |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("JOB"='SALESMAN')
   4 - access("SAL">=1500)
   5 - access("D"."DEPTNO"="DEPTNO")

20 개의 행이 선택되었습니다.
```

- no_merge 되었다면 emp 테이블 액세스 후 view 오퍼레이션이 있어야 한다.

```sql
-- 뷰 Merging 작동시 변환된 쿼리 모습 예상
select e.empno, e.ename, e.job, e.mgr, e.sal, d.dname
from   emp e, dept d
where  d.deptno = e.deptno
and    e.job    = 'SALESMAN'
and    e.sal   >= 1500
```



## 3) 복합 뷰(Complex View) Merging

- group by 절
- distinct 연산 포함
- 복합 뷰는 `_complex_view_merging `파라미터가 true 일때만 Merging이 일어남.



###### 버전별 파라미터 값

| 8i   | 기본값이 false. 복합 뷰 Merging 원할 때는 merge 힌트 사용해야 됨. |
| ---- | ------------------------------------------------------------ |
| 9i   | 기본값이 true. 동일 결과 보장시 항상 복합 뷰 Merging이 일어남. |
| 10g  | 일단 복합 뷰 Merging 시도. 원본 쿼리 비용도 같이 계산해서 Merging 했을 때의 비용이 더 낮을 때만 변환. 비용기반 쿼리 변환. |



##### _complex_view_merging 파라미터 값과 상관없이 아래 항목은 복합 뷰 Merging 불가

- 집합(set) 연산자(union, union all, intersect, minus)
- connect by 절
- ROWNUM pseudo 컬럼
- 집계함수(avg, count, max, min, sum) 사용 - group by 없이 전체 집계하는 경우
- 분석함수

```sql
-- 복합 뷰를 포함한 쿼리 - 뷰 Merging 함
explain plan for
select d.dname, avg_sal_dept
from   dept d
     ,(select /*+ merge */ deptno, avg(sal) avg_sal_dept
       from   emp
       group by deptno) e
where  d.deptno = e.deptno
and    d.loc    = 'CHICAGO'
;

경   과: 00:00:00.12
@plan
select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------------------
Plan hash value: 1182506179

-----------------------------------------------------------------------------------------
| Id  | Operation                     | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |         |     3 |    81 |     5  (20)| 00:00:01 |
|   1 |  HASH GROUP BY                |         |     3 |    81 |     5  (20)| 00:00:01 |
|   2 |   NESTED LOOPS                |         |       |       |            |          |
|   3 |    NESTED LOOPS               |         |     5 |   135 |     4   (0)| 00:00:01 |
|*  4 |     TABLE ACCESS FULL         | DEPT    |     1 |    20 |     3   (0)| 00:00:01 |
|*  5 |     INDEX RANGE SCAN          | EMP_IDX |     5 |       |     0   (0)| 00:00:01 |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP     |     5 |    35 |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("D"."LOC"='CHICAGO')
   5 - access("D"."DEPTNO"="DEPTNO")


-- 뷰 Merging 하면 아래와 같은 형태가 됨. 실행계획이 같음을 볼 수 있음.
select d.dname, avg(sal)
from   dept d, emp e
where  d.deptno = e.deptno
and    d.loc    = 'CHICAGO'
group by d.rowid, d.dname
;

-----------------------------------------------------------------------------------------
| Id  | Operation                     | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |         |     1 |    27 |     5  (20)| 00:00:01 |
|   1 |  HASH GROUP BY                |         |     1 |    27 |     5  (20)| 00:00:01 |
|   2 |   NESTED LOOPS                |         |       |       |            |          |
|   3 |    NESTED LOOPS               |         |     5 |   135 |     4   (0)| 00:00:01 |
|*  4 |     TABLE ACCESS FULL         | DEPT    |     1 |    20 |     3   (0)| 00:00:01 |
|*  5 |     INDEX RANGE SCAN          | EMP_IDX |     5 |       |     0   (0)| 00:00:01 |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP     |     5 |    35 |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------
```



##### 위 쿼리가 뷰 Merging 을 통해서 얻을 수 있는 이점

- dept.loc = 'CHICAGO' 인 데이터만 선택해서 조인하고, 조인에 성공한 집합만 group by 한다는데 있음.
- 뷰 Merging 을 하지 않는다면 emp 테이블의 모든 데이터를 group by 해서 조인하고 loc = 'CHICAGO' 조건을 필터링하게 되므로 emp 테이블을 스캔하는 과정에서 불필요한 레코드 액세스가 많이 발생됨.



## 4) 비용기반 쿼리 변환의 필요성

- 9i에서 무조건 Merging 되도록 되어 있었지만 10g에서는 비용기반으로 동작하게 되는데 이는 복합 뷰 merging이 성능이 더 안 좋을 때가 많기 때문이다.

- loc = 'CHICAGO' 조건에 의해 선택된 deptno 가 emp 테이블에서 많다면 오히려 Table Full Scan 을 감수하더라도 group by 로 먼저 집합을 줄이고 조인하는 편이 나을 수 있다.

- 비용기반 쿼리 변환 방식을 제어하기 위한 파라미터 : `_optimizer_cost_based_transformation`



## 5) Merging 되지 않은 뷰의 처리방식

- 뷰 Merging 시도 ~~(실패)~~> 조건절 Pushing 시도 ~~(실패)~~> 뷰 쿼리 블록을 개별적으로 최적화

```sql
-- 뷰 Merge 되었을 때 SQL 트레이스
select /*+ leading(e) use_nl(d) */
       *
from   dept d
     ,(select * from emp) e
where  e.deptno = d.deptno

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0         14          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.00          0         14          0          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
     14  NESTED LOOPS  (cr=14 pr=0 pw=0 time=0 us)
     14   NESTED LOOPS  (cr=12 pr=0 pw=0 time=32 us cost=17 size=798 card=14)
     14    TABLE ACCESS FULL EMP (cr=8 pr=0 pw=0 time=6 us cost=3 size=518 card=14)
     14    INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=4 pr=0 pw=0 time=0 us cost=0 size=0 card=1)(object id 91722)
     14   TABLE ACCESS BY INDEX ROWID DEPT (cr=2 pr=0 pw=0 time=0 us cost=1 size=20 card=1)


-- no_merge 힌트 사용했을 때 SQL 트레이스
select /*+ leading(e) use_nl(d) */
       *
from   dept d
     ,(select /*+ NO_MERGE */ * from emp) e
where  e.deptno = d.deptno

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0         14          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.00          0         14          0          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
     14  NESTED LOOPS  (cr=14 pr=0 pw=0 time=0 us)
     14   NESTED LOOPS  (cr=12 pr=0 pw=0 time=39 us cost=17 size=1498 card=14)
     14    VIEW  (cr=8 pr=0 pw=0 time=8 us cost=3 size=1218 card=14)
     14     TABLE ACCESS FULL EMP (cr=8 pr=0 pw=0 time=5 us cost=3 size=518 card=14)
     14    INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=4 pr=0 pw=0 time=0 us cost=0 size=0 card=1)(object id 91722)
     14   TABLE ACCESS BY INDEX ROWID DEPT (cr=2 pr=0 pw=0 time=0 us cost=1 size=20 card=1)
     
```

- 실행계획에 "VIEW" 라고 표시되지만 중간집합을 생성하는 것은 아니므로 부분범위 처리가 가능



```sql
-- 뷰가 NL 조인에서 Inner 테이블로 액세스될 때
select /*+ leading(d) use_nl(e) */
       *
from   dept d
     ,(select /*+ NO_MERGE */ * from emp) e
where  e.deptno = d.deptno

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.02          4         37          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.02          4         37          0          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
     14  NESTED LOOPS  (cr=37 pr=4 pw=4 time=0 us cost=15 size=1498 card=14)
      4   TABLE ACCESS FULL DEPT (cr=8 pr=4 pw=4 time=3 us cost=3 size=80 card=4)
     14   VIEW  (cr=29 pr=0 pw=0 time=3 us cost=3 size=348 card=4)
     56    TABLE ACCESS FULL EMP (cr=29 pr=0 pw=0 time=2 us cost=3 size=518 card=14)
     
```



- VIEW 처리 단계에서 중간 집합 생성하지 않는다. (드라이빙 테이블 dept에서 읽은 건수만큼 emp 테이블에 대한 Full Scan 을 반복한다)
- emp 테이블을 읽은 블록 개수(=29)와 출력된 결과 건수(4*14=56)으로 알 수 있다.

```sql
-- 인라인 뷰에 order by 절을 추가
select /*+ leading(d) use_nl(e) */
       *
from   dept d
     ,(select /*+ NO_MERGE */ * from emp ORDER BY ENAME) e
where  e.deptno = d.deptno

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0         15          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.00          0         15          0          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
     14  NESTED LOOPS  (cr=15 pr=0 pw=0 time=0 us cost=19 size=1498 card=14)
      4   TABLE ACCESS FULL DEPT (cr=8 pr=0 pw=0 time=10 us cost=3 size=80 card=4)
     14   VIEW  (cr=7 pr=0 pw=0 time=2 us cost=4 size=348 card=4)
     56    SORT ORDER BY (cr=7 pr=0 pw=0 time=2 us cost=4 size=518 card=14)
     14     TABLE ACCESS FULL EMP (cr=7 pr=0 pw=0 time=1 us cost=3 size=518 card=14)
```

- 건수(=14), 블록 I/O(=7) 를 보면 emp 테이블을 한번만 Full Scan 했고, 소트 수행 후 PGA에 저장된 중간집합을 반복 액세스한 것을 알 수 있다.
