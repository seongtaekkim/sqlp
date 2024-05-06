# 02. 서브쿼리 Unnesting





## 1) 서브쿼리의 분류

| 인라인 뷰(Inline View)           | from 절에 나타나는 서브쿼리                                  |
| -------------------------------- | ------------------------------------------------------------ |
| 중첩된 서브쿼리(Nested Subquery) | where 절에 사용된 서브쿼리. 특히, 서브쿼리가 메인쿼리에 있는 컬럼을 참조하는 형태는 '상관관계 있는(Correlated) 서브쿼리'라고 함. |
| 스칼라 서브쿼리(Scalar Subquery) | 한 레코드당 하나의 컬럼 값만을 리턴하는 서브 쿼리.           |



- 옵티마이저는 쿼리 블록 단위로 최적화를 수행하고, 각 서브쿼리를 최적화했다고 쿼리 전체가 최적화됐다고 할 순 없음.
- 서브쿼리 Unnesting 은 중첩된 서브쿼리(Nested Subquery), 뷰 Merging 은 인라인 뷰와 관련이 있음.



## 2) 서브쿼리 Unnesting의 의미

- 중첩된 서브쿼리를 풀어내는 것을 말함.
- 중첩된 서브쿼리는 메인쿼리와 부모와 자식이라는 종속적이고 계층적인 관계.
- 처리과정은 필터 방식. 즉, 메인 쿼리에서 읽히는 레코드마다 서브쿼리를 반복 수행하면서 조건에 맞지 않는 데이터를 골라내는 것.
- 필터 방식이 항상 최적의 수행속도를 보장하지 못하므로 옵티마이저는 두가지 방식 중 하나를 선택함.



- 동일한 결과를 보장하는 조인문으로 변환하고 나서 최적화. 서브쿼리 Unnesting 임.
- 일반 조인문처럼 다양한 최적화 기법을 사용할 수 있게 됨.
- 원래 상태에서 최적화 수행. 메인쿼리와 서브쿼리 각각 최적화 수행. 이때 서브쿼리에 필터 오퍼레이션이 나타남.
- 각각의 최적이 쿼리문 전체의 최적을 달성하지 못할 때가 많음.



#### 서브쿼리의 또 다른 최적화 기법

- where 조건절에 사용된 서브쿼리가 
  1) 메인쿼리와 상관관계에 있지 않으면서 2) 단일 로우를 리턴하는 형태의 서브쿼리를 처리할 때 나타나는 방식.
- Fetch가 아닌 Execute 시점에 먼저 수행됨. 그 결과 값을 메인 쿼리에 상수로 제공.



## 3) 서브쿼리 Unnesting의 이점

- 서브쿼리를 메인쿼리와 같은 레벨로 풀어낸다면 다양한 액세스 경로와 조인 메소드를 평가할 수 있다.
- 서브쿼리 Unnesting과 관련한 힌트 : `unnest`, `no_unnest`



## 4) 서브쿼리 Unnesting 기본 예시

```sql
-- 원래 쿼리
select * from emp
where  deptno in (select deptno from dept)
;

-- no_unnest

explain plan for
select * from emp
where  deptno in (select /*+ no_unnest */ deptno from dept)
;

해석되었습니다.

경   과: 00:00:00.14
@plan

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------
Plan hash value: 1783302997

------------------------------------------------------------------------------
| Id  | Operation          | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |         |     5 |   185 |     3   (0)| 00:00:01 |
|*  1 |  FILTER            |         |       |       |            |          |
|   2 |   TABLE ACCESS FULL| EMP     |    14 |   518 |     3   (0)| 00:00:01 |
|*  3 |   INDEX UNIQUE SCAN| PK_DEPT |     1 |     3 |     0   (0)| 00:00:01 |
------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter( EXISTS (SELECT /*+ NO_UNNEST */ 0 FROM "DEPT" "DEPT"
              WHERE "DEPTNO"=:B1))
   3 - access("DEPTNO"=:B1)

21 개의 행이 선택되었습니다.

경   과: 00:00:00.11
```

- 옵티마이저가 서브쿼리 `Unnesting`을 선호하므로 `no_unnest` 힌트 사용
- 필터 방식으로 수행된 서브쿼리의 조건절이 바인드 변수로 처리됨("DEPTNO"=:B1).
- 이것을 통해 서브쿼리를 별도로 최적화한다는 것을 알 수 있음.
- Unnesting하지 않은 서브쿼리를 수행할 때는 메인 쿼리에서 읽히는 레코드마다 값을 넘기면서 서브쿼리를 반복 수행함.

```sql
-- unnest

explain plan for
select * from emp
where  deptno in (select /*+ unnest */ deptno from dept)
;

해석되었습니다.

경   과: 00:00:00.03
@plan

PLAN_TABLE_OUTPUT
----------------------------------------------------------------------------------
Plan hash value: 3074306753

------------------------------------------------------------------------------
| Id  | Operation          | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |         |    14 |   560 |     3   (0)| 00:00:01 |
|   1 |  NESTED LOOPS      |         |    14 |   560 |     3   (0)| 00:00:01 |
|   2 |   TABLE ACCESS FULL| EMP     |    14 |   518 |     3   (0)| 00:00:01 |
|*  3 |   INDEX UNIQUE SCAN| PK_DEPT |     1 |     3 |     0   (0)| 00:00:01 |
------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("DEPTNO"="DEPTNO")

19 개의 행이 선택되었습니다.

경   과: 00:00:00.03
```



## 5) Unnesting된 쿼리의 조인 순서 조정

- Unnesting에 의해 일반 조인문으로 변환된 후에는 emp, dept 어느 쪽이든 드라이빙 집합으로 선택될 수 있다.
- 메인 쿼리 집합을 먼저 드라이빙 하려면 : leading(emp) 힌트 사용
- 서브 쿼리 집합을 먼저 드라이빙 하려면 : 서브쿼리에서 메인 쿼리에 있는 테이블을 참조할 수는 있지만, 메인 쿼리에서 서브쿼리 쪽 테이블을 참조하지는 못 함.

```sql
select /*+ leading(dept) */ * from emp
where  deptno in (select /*+ unnest */ deptno from dept)
```

- 10g 부터는 이상하게도 위처럼 해도 조인 순서가 조정된다고 함.
- leading 힌트 대신 ordered 힌트 사용. 이것을 통해 Unnesting 된 서브쿼리가 from 절에서 앞쪽에 위치함을 알 수 있음.

```sql
select /*+ ordered */ * from emp
where  deptno in (select /*+ unnest */ deptno from dept)
```

- 10g부터는 qb_name 힌트 사용하면 됨.

```sql
select /*+ leading(dept@qb1) */ * from emp
where  deptno in (select /*+ unnest qb_name(qb1) */ deptno from dept)
```



## 6) 서브쿼리가 M쪽 집합이거나 Nonunique 인덱스일 때

- 메인 쿼리에 서브쿼리가 종속적인 관계이므로 일반 조인문으로 바뀌더라도 메인 쿼리의 집합이 보장되어야 옵티마이저가 안심하고 쿼리 변환을 실시 할 수 있음.

- 지금까지 예제는 메인 쿼리의 emp 테이블과 서브쿼리의 dept 테이블이 M:1 관계라는 것을 옵티마이저가 dept 테이블의 deptno 컬럼에 PK 제약이 설정되어 있는 것을 보고 알 수 있으므로 조인을 하더라도 메인 쿼리의 집합이 보장되므로 쿼리 변환을 실시.



##### Ex1 - 서브쿼리가 M쪽 집합일 때

```sql
select * from dept
where  deptno in (select deptno from emp)
```

- dept 테이블 기준으로 집합이 만들어져야 되므로 결과집합은 1 집합이 되야함.
- 아래와 같은 일반 조인문으로 변환한다면 emp 단위의 결과집합(M * 1 = M)이 만들어지므로 결과 오류가 생김

```sql
select *
from  (select deptno from emp) a, dept b
where  b.deptno = a.deptno
```

##### Ex2 - 테이블 간의 관계를 알 수 없을 때

```
select * from emp
where  deptno in (select deptno from dept)
```

- M쪽 집합을 드라이빙해 1쪽 집합을 서브쿼리로 필터링하므로 조인문으로 바꾸더라도 결과 오류 생기지 않음.
- 하지만 dept 테이블 deptno 컬럼에 PK/Unique 제약 또는 Unique 인덱스가 없다면 두 테이블간의 관계를 알 수 없으므로 옵티마이저는 일반 조인문으로 쿼리 변환을 시도하지 않음.



##### 서브쿼리 쪽 집합을 1집합으로 만들기 위한 옵티마이저는 두가지 방식 중 하나를 선택

1. 1쪽 집합임을 확신할 수 없는 서브쿼리 쪽 테이블이 드라이빙된다면, 먼저 sort unique 오퍼레이션 수행함으로써 1쪽 집합으로 만든 다음 조인.
2. 메인 쿼리 쪽 테이블이 드라이빙 된다면 세미 조인(Semi Join) 방식으로 조인.





## 7)  필터 오퍼레이션과 세미조인의 캐싱 효과

- 서브쿼리를 Unnesting 하지 않으면 필터 오퍼레이션을 사용할 수 밖에 없는데 다행히 오라클은 서브쿼리의 수행결과를 내부 캐시에 저장했다가 같은 입력값이 들어오면 저장된 값을 출력하는 필터 최적화 기법을 가지고 있음.

```sql
-- emp 테이블을 100번 복제한 t_emp 테이블 생성
create table t_emp
as
select *
from   emp
     ,(select rownum no from dual connect by level <= 100)
;

-- 필터 방식으로 수행
select count(*)
from   t_emp t
where  exists (select /*+ no_unnest */
                      'x'
               from   dept
               where  deptno = t.deptno
               and    loc is not null)

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.01          0          2          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0         18          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.01          0         20          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=18 pr=0 pw=0 time=0 us)
   1400   FILTER  (cr=18 pr=0 pw=0 time=18 us)
   1400    TABLE ACCESS FULL T_EMP (cr=12 pr=0 pw=0 time=4 us cost=5 size=18200 card=1400)
      3    TABLE ACCESS BY INDEX ROWID DEPT (cr=6 pr=0 pw=0 time=0 us cost=2 size=11 card=1)
      3     INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=3 pr=0 pw=0 time=0 us cost=1 size=0 card=1)(object id 91722)
      
```

- dept 테이블에 대한 필터링을 1,400번 수행했어도 읽은 블록수는 인덱스 3개, 테이블 3개 총 6개뿐임. 리턴 건수도 3개임.
- t_emp 테이블 deptno에 10, 20, 30 세개의 값(입력값)만 있으므로, 서브쿼리도 3번만 수행하고 같은 입력값이 들어오면 캐시에서 저장된 출력값을 읽어서 재사용함.



- 9i 에서는 필터 캐싱 효과 없음

```sql
1400 NESTED LOOPS SEMI (cr=1414 r=O w=O time=46453 us)
1400  TABLE ACCESS FULL T_EMP (cr=12 r=O w=O time=6613 us)
1400  TABLE ACCESS BY INDEX ROWID DEPT (cr=1402 r=O w=O time=20490 us)
1400   INDEX UNIQUE SCAN DETP_PK (cr=2 r=O w=O timee=6948 us) (object id 39130)
```

- NL 조인에서 Inner 쪽 인덱스 루트 블록에 대한 버퍼 Pinning 효과가 나타남을 알 수 있음. (rows 가 1400개인데 cr=2 밖에 안됨) 위 필터 방식에서는 안 나타남.



- 10g 부터는 NL 세미 조인도 캐싱효과를 가짐.

```sql
select count(*)
from   t_emp t
where  exists (select /*+ unnest nl_sj */
                      'x'
               from   dept
               where  deptno = t.deptno
               and    loc is not null)

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          1          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0         15          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.00          0         16          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=15 pr=0 pw=0 time=0 us)
   1400   NESTED LOOPS SEMI (cr=15 pr=0 pw=0 time=18 us cost=1406 size=33600 card=1400)
   1400    TABLE ACCESS FULL T_EMP (cr=12 pr=0 pw=0 time=6 us cost=5 size=18200 card=1400)
      3    TABLE ACCESS BY INDEX ROWID DEPT (cr=3 pr=0 pw=0 time=0 us cost=1 size=44 card=4)
      3     INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=2 pr=0 pw=0 time=0 us cost=0 size=0 card=1)(object id 91722)
      
```



## 8) Anti 조인

- not exists, not in 서브쿼리도 Unnesting 하지 않으면 필터 방식으로 처리됨.
- 조인에 성공하는 레코드가 하나도 없을 때만 결과집합에 포함됨.

```sql
-- Unnesting 하지 않아서 필터 처리됨
explain plan for
select *
from   dept d
where not exists(select /*+ no_unnest */
                 'x'
                 from   emp
                 where  deptno = d.deptno)
;

해석되었습니다.

경   과: 00:00:00.07
@plan
select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------------
Plan hash value: 3547749009

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     3 |    60 |     7   (0)| 00:00:01 |
|*  1 |  FILTER            |      |       |       |            |          |
|   2 |   TABLE ACCESS FULL| DEPT |     4 |    80 |     3   (0)| 00:00:01 |
|*  3 |   TABLE ACCESS FULL| EMP  |     2 |     6 |     2   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter( NOT EXISTS (SELECT /*+ NO_UNNEST */ 0 FROM "EMP" "EMP"
              WHERE "DEPTNO"=:B1))
   3 - filter("DEPTNO"=:B1)

17 개의 행이 선택되었습니다.

-- Unnesting 하면 Anti 조인 방식으로 처리됨.
explain plan for
select *
from   dept d
where not exists(select /*+ unnest nl_aj */
                 'x'
                 from   emp
                 where  deptno = d.deptno)
;

해석되었습니다.

경   과: 00:00:00.00
@plan
select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
-----------------------------------------------------------------------------
Plan hash value: 1522491139

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     3 |    69 |    10   (0)| 00:00:01 |
|   1 |  NESTED LOOPS ANTI |      |     3 |    69 |    10   (0)| 00:00:01 |
|   2 |   TABLE ACCESS FULL| DEPT |     4 |    80 |     3   (0)| 00:00:01 |
|*  3 |   TABLE ACCESS FULL| EMP  |     5 |    15 |     2   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("DEPTNO"="D"."DEPTNO")

15 개의 행이 선택되었습니다.

-- merge_aj
select *
from   dept d
where not exists(select /*+ unnest merge_aj */
                        'x'
                 from   emp
                 where  deptno = d.deptno)
;

-- hash_aj
select *
from   dept d
where not exists(select /*+ unnest hash_aj */
                        'x'
                 from   emp
                 where  deptno = d.deptno)
;
```

- NL Anti 조인과 머지 Anti 조인은 기본 처리루틴이 not exists 필터와 같지만, 해시 Anti 조인은 다름.

1. dept를 해시 테이블로 빌드
2. emp를 스캔하면서 해시 테이블 탐색, 조인 성공 엔트리에 표시해놓음.
3. 마지막으로 해시 테이블을 스캔하면서 표시가 없는 엔트리만 결과집합에 담음.



## 9) 집계 서브쿼리 제거

- 집계 함수를 포함하는 서브쿼리를 Unnesting 하고 분석함수로 대체. 10g 부터 도입됨.

```sql
-- 집계 서브쿼리가 있는 쿼리
select d.deptno, d.dname, e.empno, e.ename, e.sal
from   emp e, dept d
where  d.deptno = e.deptno
and    e.sal >= (select avg(sal) from emp where deptno = d.deptno)
```

- Unnesting 하면 1차적으로 서브쿼리가 인라인뷰로 변환되는데, 옵티마이저는 인라인 뷰를 Merging 하거나 그대로 둔 채 최적화할 수 있음.
- 10g 부터는 인라인 뷰를 제거하고 분석함수를 사용하는 형태로 변환이 가능해짐.
- 비용기반으로 작동함.

```sql
-- 분석함수를 사용하는 형태로 변환된 쿼리
select deptno, dname, empno, ename, sal
from  (select d.deptno, d.dname, e.empno, e.ename, e.sal
            ,(case when e.sal >= avg(sal) over (partition by d.deptno) 
                   then e.rowid end) max_sal_rowid
       from   emp e, dept d
       where  d.deptno = e.deptno)
where  max_sal_rowid is not null
```



```sql
-- 분석함수를 사용하는 형태로 변환되었을 때 실행계획
explain plan for
select d.deptno, d.dname, e.empno, e.ename, e.sal
from   emp e, dept d
where  d.deptno = e.deptno
and    e.sal >= (select avg(sal) from emp where deptno = d.deptno)
 ;

해석되었습니다.

경   과: 00:00:00.00
@plan
select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------
Plan hash value: 3722278325

--------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name            | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                 |    14 |   938 |     6  (17)| 00:00:01 |
|*  1 |  VIEW                          | VW_WIF_1        |    14 |   938 |     6  (17)| 00:00:01 |
|   2 |   WINDOW BUFFER                |                 |    14 |   686 |     6  (17)| 00:00:01 |
|   3 |    MERGE JOIN                  |                 |    14 |   686 |     6  (17)| 00:00:01 |
|   4 |     TABLE ACCESS BY INDEX ROWID| DEPT            |     4 |    52 |     2   (0)| 00:00:01 |
|   5 |      INDEX FULL SCAN           | DEPT_DEPTNO_IDX |     4 |       |     1   (0)| 00:00:01 |
|*  6 |     SORT JOIN                  |                 |    14 |   504 |     4  (25)| 00:00:01 |
|   7 |      TABLE ACCESS FULL         | EMP             |    14 |   504 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("VW_COL_6" IS NOT NULL)
   6 - access("D"."DEPTNO"="E"."DEPTNO")
       filter("D"."DEPTNO"="E"."DEPTNO")

21 개의 행이 선택되었습니다.
```

- 쿼리에서는 emp 테이블 두 번 참조했지만 실행계획상으로는 한번, 대신 window buffer 오퍼레이션 추가됨.



## 10) Pushing 서브쿼리

- Unnesting 되지 않은 서브쿼리는 항상 필터 방식으로 처리되며, 대개 마지막 단계에서 처리됨.
- 서브쿼리를 먼저 처리하여 다음 수행 단계로 넘어가는 로우 수를 줄일 수 있다면 성능 향상이 될 수 있음.
- Pushing 서브쿼리는 실행계획상 가능한 앞 단계에서 서브쿼리 필터링이 처리되도록 강제하는 것을 말함.
- 힌트 : push_subq
- Unnesting 되지 않은 서브쿼리에만 작동함. no_unnest 힌트와 같이 기술하는 것이 올바름.

```sql
-- emp 테이블을 1000번 복제한 emp1, emp2 테이블 생성
create table emp1 as
select * from emp, (select rownum no from dual connect by level <= 1000);

create table emp2 as select * from emp1;

alter table emp1 add constraint emp1_pk primary key(no, empno);

alter table emp2 add constraint emp2_pk primary key(no, empno);

-- no_push_subq
select /*+ leading(e1) use_nl(e2) */
       sum(e1.sal)
     , sum(e2.sal)
from   emp1 e1
     , emp2 e2
where  e1.no    = e2.no
and    e1.empno = e2.empno
and    exists (select /*+ NO_UNNEST NO_PUSH_SUBQ */ 'x'
               from   dept
               where  deptno = e1.deptno
               and    loc    = 'NEW YORK')

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.03          0         10          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.04       0.11         37      14348          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.06       0.14         37      14358          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=14348 pr=37 pw=37 time=0 us)
   3000   FILTER  (cr=14348 pr=37 pw=37 time=462 us)
  14000    NESTED LOOPS  (cr=14342 pr=35 pw=35 time=519 us)
  14000     NESTED LOOPS  (cr=342 pr=35 pw=35 time=286 us cost=12719 size=2002 card=22)
  14000      TABLE ACCESS FULL EMP1 (cr=95 pr=0 pw=0 time=56 us cost=29 size=758472 card=14586)
  14000      INDEX UNIQUE SCAN EMP2_PK (cr=247 pr=35 pw=35 time=0 us cost=0 size=0 card=1)(object id 91815)
  14000     TABLE ACCESS BY INDEX ROWID EMP2 (cr=14000 pr=0 pw=0 time=0 us cost=1 size=39 card=1)
      1    TABLE ACCESS BY INDEX ROWID DEPT (cr=6 pr=2 pw=2 time=0 us cost=2 size=11 card=1)
      3     INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=3 pr=1 pw=1 time=0 us cost=1 size=0 card=1)(object id 91722)

-- push_subq
select /*+ leading(e1) use_nl(e2) */
       sum(e1.sal)
     , sum(e2.sal)
from   emp1 e1
     , emp2 e2
where  e1.no    = e2.no
and    e1.empno = e2.empno
and    exists (select /*+ NO_UNNEST PUSH_SUBQ */ 'x'
               from   dept
               where  deptno = e1.deptno
               and    loc    = 'NEW YORK')

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          8          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.01       0.01          0       3348          0           1
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.01       0.02          0       3356          0           1

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 91  

Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=3348 pr=0 pw=0 time=0 us)
   3000   NESTED LOOPS  (cr=3348 pr=0 pw=0 time=157 us)
   3000    NESTED LOOPS  (cr=348 pr=0 pw=0 time=95 us cost=663 size=91 card=1)
   3000     TABLE ACCESS FULL EMP1 (cr=101 pr=0 pw=0 time=37 us cost=29 size=37908 card=729)
      1      TABLE ACCESS BY INDEX ROWID DEPT (cr=6 pr=0 pw=0 time=0 us cost=2 size=11 card=1)
      3       INDEX RANGE SCAN DEPT_DEPTNO_IDX (cr=3 pr=0 pw=0 time=0 us cost=1 size=0 card=1)(object id 91722)
   3000     INDEX UNIQUE SCAN EMP2_PK (cr=247 pr=0 pw=0 time=0 us cost=0 size=0 card=1)(object id 91815)
   3000    TABLE ACCESS BY INDEX ROWID EMP2 (cr=3000 pr=0 pw=0 time=0 us cost=1 size=39 card=1)
```



#### 서브쿼리 필터와 Pushing 서브쿼리와의 결과 비교

- 필터는 emp1과 emp2의 조인 시도 횟수가 14,000번, Pushing 서브쿼리는 서브쿼리를 먼저 수행해서
- emp1의 결과건수가 3,000건이 됐고 emp2 테이블과의 조인 횟수도 3,000번으로 줌.
- 읽은 블록수도 14000정도에서 에서 3000 정도로 로 줄었다.





## 뒤에 퀴즈 2회독 때 풀자$$$$$$$$$$$$















