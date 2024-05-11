# 09. Outer 조인을 Inner 조인으로 변경



- Outer 조인문을 작성하면 일부 조건절에 Outer 기호(+)를 빠뜨리면 Inner 조인할 때와 같은 결과가 나온다.
- 이럴때 옵티마이저는 Outer 조인을 Inner 조인문으로 바꾸는 쿼리 변환을 시행하게 된다.

```sql
select *
    from   emp e, dept d
    where  d.deptno(+) = e.deptno
    and    d.loc = 'DALLAS'
    and    e.sal >= 1000;

(10g)
Execution Plan
----------------------------------------------------------
Plan hash value: 3493486646

------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                |     5 |   285 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS BY INDEX ROWID  | EMP            |     5 |   185 |     1   (0)| 00:00:01 |
|   2 |   NESTED LOOPS                |                |     5 |   285 |     3   (0)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID| DEPT           |     1 |    20 |     2   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN          | DEPT_IDX       |     1 |       |     1   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN           | EMP_DEPTNO_IDX |     5 |       |     0   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("E"."SAL">=1000)
   4 - access("D"."LOC"='DALLAS')
   5 - access("D"."DEPTNO"="E"."DEPTNO")



(11g)

Execution Plan
----------------------------------------------------------
Plan hash value: 844388907

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |     4 |   232 |     6  (17)| 00:00:01 |
|   1 |  MERGE JOIN                  |         |     4 |   232 |     6  (17)| 00:00:01 |
|*  2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     1 |    20 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |         |    12 |   456 |     4  (25)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | EMP     |    12 |   456 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("D"."LOC"='DALLAS')
   4 - access("D"."DEPTNO"="E"."DEPTNO")
       filter("D"."DEPTNO"="E"."DEPTNO")
   5 - filter("E"."SAL">=1000)
```

- 옵티마이저가 쿼리 변환을 시행하는 이유는 조인 순서를 자유롭게 결정하기 위함
- Outer NL조인 / Outer 소트머지 조인시 드라이빙 테이블은 항상 Outer 기호가 붙지 않은 쪽으로 고정됨.
- Outer 해시 조인시 자유롭게 조인순서가 바뀌도록 개선됨(10g부터)

- 만약 위의 쿼리에서 sal >=1000 조건에 부합하는 사원 레코드가 매우 많고, loc='DALLAS' 조건에 부합하는 부서에 속한 사원이 매우 적다면 dept 테이블을 먼저 드라이빙하는 것이 유리하다. 그럼에도 Outer 조인 때문에 항상 emp테이블을 드라이빙 해야 한다면 불리한 조건에서 최적화하는 것이 된다. 이러한 이유로 **불필요한 Outer 조인을 삼가** 해야한다.

- Outer 조인을 써야하는 상황이라면 Outer 기호를 정확히 구사해야 올바른 결과 집합을 얻을 수 있음에 유념하자
- ANSI Outer 조인문일때는 Outer 기호 대신 조건절 위치에 신경써야 한다.



- Outer 조인에서 Inner 쪽 테이블에 대한 필터 조건을 아래처럼 where 절에 기술한다면 Inner 조인할 때와 같은 결과 집합을 얻게 된다.
- 따라서 옵티마이저가 Outer 조인을 Inner 조인으로 변환해버린다.

```sql
select e.empno, e.deptno, e.sal, d.loc, d.dname, d.deptno
from dept d left outer join emp e on d.deptno = e.deptno
where e.sal > 1000;

(10g)책
Execution Plan
----------------------------------------------------------
Plan hash value: 3582342135

--------------------------------------------------------------------------------------------
| Id  | Operation                    | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |             |    13 |   403 |     3   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                |             |    13 |   403 |     3   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| EMP         |    13 |   143 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_SAL_IDX |    13 |       |     1   (0)| 00:00:01 |
|   4 |   TABLE ACCESS BY INDEX ROWID| DEPT        |     1 |    20 |     1   (0)| 00:00:01 |
|*  5 |    INDEX UNIQUE SCAN         | DEPT_PK     |     1 |       |     0   (0)| 00:00:01 |
--------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("E"."SAL">1000)
   5 - access("D"."DEPTNO"="E"."DEPTNO")

(10g)집
Execution Plan
----------------------------------------------------------
Plan hash value: 844388907

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |    13 |   403 |     6  (17)| 00:00:01 |
|   1 |  MERGE JOIN                  |         |    13 |   403 |     6  (17)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |         |    13 |   143 |     4  (25)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | EMP     |    13 |   143 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("D"."DEPTNO"="E"."DEPTNO")
       filter("D"."DEPTNO"="E"."DEPTNO")
   5 - filter("E"."SAL">1000)

(11g)
Execution Plan
----------------------------------------------------------
Plan hash value: 844388907

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |    12 |   372 |     6  (17)| 00:00:01 |
|   1 |  MERGE JOIN                  |         |    12 |   372 |     6  (17)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |         |    12 |   132 |     4  (25)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | EMP     |    12 |   132 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("D"."DEPTNO"="E"."DEPTNO")
       filter("D"."DEPTNO"="E"."DEPTNO")
   5 - filter("E"."SAL">1000)
```





- 제대로된 Outer 조인 결과 집합을 얻으려면 sal>1000조건을 아래와 같이 on 절에 추가해줘야 한다.

```sql
 select e.empno, e.deptno, e.sal, d.loc, d.dname, d.deptno
 from dept d left outer join emp e on d.deptno = e.deptno and e.sal > 1000

(10g)책
Execution Plan
----------------------------------------------------------
Plan hash value: 1350698460

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |    13 |   403 |     4   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER          |                |    13 |   403 |     4   (0)| 00:00:01 |
|   2 |   TABLE ACCESS FULL          | DEPT           |     4 |    80 |     3   (0)| 00:00:01 |
|*  3 |   TABLE ACCESS BY INDEX ROWID| EMP            |     3 |    33 |     1   (0)| 00:00:01 |
|*  4 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     0   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("E"."SAL"(+)>1000)
   4 - access("D"."DEPTNO"="E"."DEPTNO"(+))

(10g) 집
Execution Plan
----------------------------------------------------------
Plan hash value: 2251696546

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |    13 |   403 |     6  (17)| 00:00:01 |
|   1 |  MERGE JOIN OUTER            |         |    13 |   403 |     6  (17)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |         |    13 |   143 |     4  (25)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | EMP     |    13 |   143 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("D"."DEPTNO"="E"."DEPTNO"(+))
       filter("D"."DEPTNO"="E"."DEPTNO"(+))
   5 - filter("E"."SAL"(+)>1000)

(11g)
Execution Plan
----------------------------------------------------------
Plan hash value: 2251696546

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |    12 |   372 |     6  (17)| 00:00:01 |
|   1 |  MERGE JOIN OUTER            |         |    12 |   372 |     6  (17)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |         |    12 |   132 |     4  (25)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | EMP     |    12 |   132 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("D"."DEPTNO"="E"."DEPTNO"(+))
       filter("D"."DEPTNO"="E"."DEPTNO"(+))
   5 - filter("E"."SAL"(+)>1000)
```





- ANSI Outer 조인문에서 where 절을 기술한 Inner 쪽 필터 조건이 의미 있게 사용되는 경우는 아래처럼 is null 조건을 체크하는 경우뿐이며, 조인에 실패하는 레코드를 찾고자 할때 흔히 사용되는 SQL이다

```sql
select e.empno, e.deptno, e.sal, d.loc, d.dname, d.deptno
from  dept d left outer join emp e on d.deptno = e.deptno
where e.empno is null;

(10g)
Execution Plan
----------------------------------------------------------
Plan hash value: 4106494745

------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                |    14 |   434 |     4   (0)| 00:00:01 |
|*  1 |  FILTER                       |                |       |       |            |          |
|   2 |   NESTED LOOPS OUTER          |                |    14 |   434 |     4   (0)| 00:00:01 |
|   3 |    TABLE ACCESS FULL          | DEPT           |     4 |    80 |     3   (0)| 00:00:01 |
|   4 |    TABLE ACCESS BY INDEX ROWID| EMP            |     4 |    44 |     1   (0)| 00:00:01 |
|*  5 |     INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     0   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("E"."EMPNO" IS NULL)
   5 - access("D"."DEPTNO"="E"."DEPTNO"(+))

(10g) 집
Execution Plan
----------------------------------------------------------
Plan hash value: 457395871

-----------------------------------------------------------------------------------------
| Id  | Operation                     | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |         |    14 |   434 |     6  (17)| 00:00:01 |
|*  1 |  FILTER                       |         |       |       |            |          |
|   2 |   MERGE JOIN OUTER            |         |    14 |   434 |     6  (17)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   4 |     INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  5 |    SORT JOIN                  |         |    14 |   154 |     4  (25)| 00:00:01 |
|   6 |     TABLE ACCESS FULL         | EMP     |    14 |   154 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("E"."EMPNO" IS NULL)
   5 - access("D"."DEPTNO"="E"."DEPTNO"(+))
       filter("D"."DEPTNO"="E"."DEPTNO"(+))

(11g)
Execution Plan
----------------------------------------------------------
Plan hash value: 457395871

-----------------------------------------------------------------------------------------
| Id  | Operation                     | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |         |     1 |    31 |     6  (17)| 00:00:01 |
|*  1 |  FILTER                       |         |       |       |            |          |
|   2 |   MERGE JOIN OUTER            |         |     1 |    31 |     6  (17)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID| DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   4 |     INDEX FULL SCAN           | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  5 |    SORT JOIN                  |         |    14 |   154 |     4  (25)| 00:00:01 |
|   6 |     TABLE ACCESS FULL         | EMP     |    14 |   154 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("E"."EMPNO" IS NULL)
   5 - access("D"."DEPTNO"="E"."DEPTNO"(+))
       filter("D"."DEPTNO"="E"."DEPTNO"(+))
```
