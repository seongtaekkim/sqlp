# 04. 조건절 Pushing





## 1) 조건절 Pushing이란

- 뷰를 참조하는 쿼리블록의 조건절을 뷰 쿼리블록 안으로 pushing 하는 기능
- 옵티마이저는 뷰머징에 실패했을때 2차적으로 조건절 pushing을 시도 한다.



#### view-merginig 실패할 경우

- 복합뷰(Complex View) Merging기능이 비활성화
- 사용자가 No_merge힌트를 사용한 경우
- Non-mergeable Views : 뷰 Merging이 시행되면 부정확한 결과가 나올 경우
- 비용기반 쿼리 변환이 작동해 No Merging을 선택한 경우
- 뷰안에 Rownum Psedo컬럼이 있는 경우(조건절 Pushing도 되지 않음)
- 분석함수를 사용한 경우(조건절 Pushing도 되지 않음)



### 조건절 Pushing 종류

- 조건절(Predicate) Pushdown : 쿼리블록 밖에 있는 조건들을 쿼리 블록 안쪽으로 밀어 넣는 것을 말함
- 조건절(Predicate) Pullup : 쿼리블록 안에 있는 조건들을 쿼리 블록 밖으로 내보내서 다른 쿼리블록에 Pushdown 하는데 사용 (Predicate Move Around)
- 조인조건(Join Predicate) Pushdown : NL조인 수행 중에 드라이빙 테이블에서 읽은 값을 건건이 Inner쪽으로 밀어 넣는것을 말함



### 관련힌트와 파라미터

- /*+ push_pred(table_name/alias) */
- /*+ no_push_pred(table_name/alias) */
- /*+ opt_param('_optimizer_push_pred_cost_based', 'false') */
- /*+ opt_param('_push_join_predicate', 'false') */
- /*+ opt_param('_push_join_union_view', 'false') */
- /*+ opt_param('_push_join_union_view2', 'false') */



조건절Pushdown/Pullup은 항상 더 나은 성능을 보장한다

조인조건Pushdown은 NL조인을 전제로함, NL의 특성상 성능저하될 수 있어 제어힌트 제공하고 있다

조인조건Pushdown은 NL조인을 전제로 하기 때문에 굳이 use_nl힌트를 줄 필요는 없다

9i에서는 push_pred와 use_nl힌트를 함께 사용할 때 pushdown기능이 작동하지 않을 수 있다



## 2) 조건절 Pushdown

#### Group by 절을 포함한 뷰에 대한 조건절 Pushdown

```sql
-- no_merge 힌트사용 (조건절  pushdown)
select deptno, avg_sal
from  (select /*+ no_merge */ deptno, avg(sal) avg_sal from emp group by deptno) a
where  deptno = 30;

Execution Plan
----------------------------------------------------------
Plan hash value: 343798278

------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                |     1 |    26 |     2   (0)| 00:00:01 |
|   1 |  VIEW                         |                |     1 |    26 |     2   (0)| 00:00:01 |
|   2 |   SORT GROUP BY NOSORT        |                |     1 |    10 |     2   (0)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    50 |     2   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("DEPTNO"=30)


-- 힌트없이
Plan hash value: 3834901816

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     3 |    78 |     3   (0)| 00:00:01 |
|   1 |  VIEW               |      |     3 |    78 |     3   (0)| 00:00:01 |
|   2 |   HASH GROUP BY     |      |     3 |    30 |     3   (0)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("DEPTNO"=30)



-- 복합뷰 merging 기능 비활성화 (조건절 pushdown)

alter session set "_complex_view_merging"=false;

select deptno, avg_sal
from  (select deptno, avg(sal) avg_sal from emp group by deptno) a
where  deptno = 30;

Execution Plan
----------------------------------------------------------
Plan hash value: 343798278

------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                |     3 |    78 |     2   (0)| 00:00:01 |
|   1 |  VIEW                         |                |     3 |    78 |     2   (0)| 00:00:01 |
|   2 |   SORT GROUP BY NOSORT        |                |     3 |    30 |     2   (0)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    50 |     2   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("DEPTNO"=30)


-- 힌트없이
Execution Plan
----------------------------------------------------------

Plan hash value: 3834901816

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     3 |    78 |     3   (0)| 00:00:01 |
|   1 |  VIEW               |      |     3 |    78 |     3   (0)| 00:00:01 |
|   2 |   HASH GROUP BY     |      |     3 |    30 |     3   (0)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("DEPTNO"=30)



-- 복합뷰 merging 기능 활성화 (merging)

alter session set "_complex_view_merging"=true;

Execution Plan
----------------------------------------------------------
Plan hash value: 1032861127

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     1 |     7 |     2   (0)| 00:00:01 |
|   1 |  SORT GROUP BY NOSORT        |                |     1 |     7 |     2   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    35 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("DEPTNO"=30)

-- 힌트없이
Execution Plan
----------------------------------------------------------
Plan hash value: 2935116771

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     1 |     7 |     3   (0)| 00:00:01 |
|   1 |  SORT GROUP BY NOSORT|      |     1 |     7 |     3   (0)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL  | EMP  |     5 |    35 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("DEPTNO"=30)
```





### Group by 절을 포함한 뷰에 대한 조인문

```sql
-- 뷰 안쪽의 조건절 pushdown 발생 
select /*+ no_merge(a) */
       b.deptno, b.dname, a.avg_sal
from (select deptno, avg(sal) avg_sal from emp group by deptno) a, dept b
where a.deptno=b.deptno
and b.deptno = 30;


Execution Plan
----------------------------------------------------------
Plan hash value: 1644078573

-------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                |     1 |    28 |     3   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                  |                |     1 |    28 |     3   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID  | DEPT           |     1 |    13 |     1   (0)| 00:00:01 |
|*  3 |    INDEX UNIQUE SCAN           | PK_DEPT        |     1 |       |     0   (0)| 00:00:01 |
|   4 |   VIEW                         |                |     1 |    15 |     2   (0)| 00:00:01 |
|   5 |    SORT GROUP BY               |                |     1 |    10 |     2   (0)| 00:00:01 |
|   6 |     TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    50 |     2   (0)| 00:00:01 |
|*  7 |      INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("B"."DEPTNO"=30)
   7 - access("DEPTNO"=30)

-- 힌트없이

Execution Plan
----------------------------------------------------------

Plan hash value: 2808195971

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |     1 |    28 |     4   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                |         |     1 |    28 |     4   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     1 |    13 |     1   (0)| 00:00:01 |
|*  3 |    INDEX UNIQUE SCAN         | PK_DEPT |     1 |       |     0   (0)| 00:00:01 |
|   4 |   VIEW                       |         |     1 |    15 |     3   (0)| 00:00:01 |
|   5 |    SORT GROUP BY             |         |     1 |    10 |     3   (0)| 00:00:01 |
|*  6 |     TABLE ACCESS FULL        | EMP     |     5 |    50 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("B"."DEPTNO"=30)
   6 - filter("DEPTNO"=30)
```





### UNION 집합 연산자를 포함한 뷰에 대한 조건절 Pushdown

- union 집합 연산자를 포함한 뷰는 Non-mergeable View에 속하므로 뷰 merging에 실패하므로, 조건절 Pushing을 통해서만 최적화 가능

```sql
create index emp_x1 on emp(deptno, job);

select * 
from (select deptno, empno, ename, job, sal, sal*1.1 sal2, hiredate
       from emp
       where job='CLERK'
        union all
        select deptno, empno, ename, job, sal, sal*1.2 sal2, hiredate
        from emp
        where job='SALESMAN')V
 where v.deptno=30;

Execution Plan
----------------------------------------------------------
Plan hash value: 3488565791

----------------------------------------------------------------------------------------
| Id  | Operation                     | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |        |     2 |   148 |     4   (0)| 00:00:01 |
|   1 |  VIEW                         |        |     2 |   148 |     4   (0)| 00:00:01 |
|   2 |   UNION-ALL                   |        |       |       |            |          |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP    |     1 |    33 |     2   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN          | EMP_X1 |     2 |       |     1   (0)| 00:00:01 |
|   5 |    TABLE ACCESS BY INDEX ROWID| EMP    |     1 |    33 |     2   (0)| 00:00:01 |
|*  6 |     INDEX RANGE SCAN          | EMP_X1 |     2 |       |     1   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("DEPTNO"=30 AND "JOB"='CLERK')
   6 - access("DEPTNO"=30 AND "JOB"='SALESMAN')

-힌트없이
Execution Plan
----------------------------------------------------------
Plan hash value: 3759325023

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     2 |   148 |     6   (0)| 00:00:01 |
|   1 |  VIEW               |      |     2 |   148 |     6   (0)| 00:00:01 |
|   2 |   UNION-ALL         |      |       |       |            |          |
|*  3 |    TABLE ACCESS FULL| EMP  |     1 |    33 |     3   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |     1 |    33 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("JOB"='CLERK' AND "DEPTNO"=30)
   4 - filter("JOB"='SALESMAN' AND "DEPTNO"=30)



-- 조인조건을 타고 전이된 상수 조건이 뷰 쿼리 블록에 Pushing 된 경우
select /*+ ordered use_nl(e) */ d.dname, e.*
from dept d 
    ,(select deptno, empno, ename, job, sal, sal*1.1 sal2, hiredate from emp
      where job='CLERK'
      union all
      select deptno, empno, ename, job, sal, sal*1.2 sal2, hiredate from emp
      where job='SALESMAN') e
where e.deptno=d.deptno
and   d.deptno=30;

Execution Plan
----------------------------------------------------------
Plan hash value: 3523106777

------------------------------------------------------------------------------------------
| Id  | Operation                      | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |         |     2 |   174 |     5   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                  |         |     2 |   174 |     5   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID  | DEPT    |     1 |    13 |     1   (0)| 00:00:01 |
|*  3 |    INDEX UNIQUE SCAN           | PK_DEPT |     1 |       |     0   (0)| 00:00:01 |
|   4 |   VIEW                         |         |     2 |   148 |     4   (0)| 00:00:01 |
|   5 |    UNION-ALL                   |         |       |       |            |          |
|   6 |     TABLE ACCESS BY INDEX ROWID| EMP     |     1 |    33 |     2   (0)| 00:00:01 |
|*  7 |      INDEX RANGE SCAN          | EMP_X1  |     2 |       |     1   (0)| 00:00:01 |
|   8 |     TABLE ACCESS BY INDEX ROWID| EMP     |     1 |    33 |     2   (0)| 00:00:01 |
|*  9 |      INDEX RANGE SCAN          | EMP_X1  |     2 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("D"."DEPTNO"=30)
   7 - access("DEPTNO"=30 AND "JOB"='CLERK')
   9 - access("DEPTNO"=30 AND "JOB"='SALESMAN')


-- 힌트없이
Execution Plan
----------------------------------------------------------

Plan hash value: 2612257741

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |     2 |   174 |     7   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                |         |     2 |   174 |     7   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| DEPT    |     1 |    13 |     1   (0)| 00:00:01 |
|*  3 |    INDEX UNIQUE SCAN         | PK_DEPT |     1 |       |     0   (0)| 00:00:01 |
|   4 |   VIEW                       |         |     2 |   148 |     6   (0)| 00:00:01 |
|   5 |    UNION-ALL                 |         |       |       |            |          |
|*  6 |     TABLE ACCESS FULL        | EMP     |     1 |    33 |     3   (0)| 00:00:01 |
|*  7 |     TABLE ACCESS FULL        | EMP     |     1 |    33 |     3   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("D"."DEPTNO"=30)
   6 - filter("JOB"='CLERK' AND "DEPTNO"=30)
   7 - filter("JOB"='SALESMAN' AND "DEPTNO"=30)
```





## 3) 조건절 Pullup

- 조건들을 바깥 쪽으로 끄집어 내어 다른 쿼리들록에 Pushdown하는데 사용함(Predicate Move Around)

```sql
select * from 
   (select deptno, avg(sal) from emp where deptno=10 group by deptno) e1
   ,(select deptno, min(sal), max(sal) from emp group by deptno) e2
 where e1.deptno =e2.deptno;

Execution Plan
----------------------------------------------------------
Plan hash value: 1076936357

-------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                |     1 |    69 |     5  (20)| 00:00:01 |
|*  1 |  HASH JOIN                     |                |     1 |    69 |     5  (20)| 00:00:01 |
|   2 |   VIEW                         |                |     1 |    28 |     2   (0)| 00:00:01 |
|   3 |    HASH GROUP BY               |                |     1 |    10 |     2   (0)| 00:00:01 |
|   4 |     TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    50 |     2   (0)| 00:00:01 |
|*  5 |      INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
|   6 |   VIEW                         |                |     3 |   123 |     2   (0)| 00:00:01 |
|   7 |    HASH GROUP BY               |                |     3 |    30 |     2   (0)| 00:00:01 |
|   8 |     TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    50 |     2   (0)| 00:00:01 |
|*  9 |      INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("E1"."DEPTNO"="E2"."DEPTNO")
   5 - access("DEPTNO"=10)
   9 - access("DEPTNO"=10)

-- 힌트없이
Execution Plan
----------------------------------------------------------

Plan hash value: 4253239321

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     1 |    69 |     6   (0)| 00:00:01 |
|   1 |  NESTED LOOPS        |      |     1 |    69 |     6   (0)| 00:00:01 |
|   2 |   VIEW               |      |     1 |    28 |     3   (0)| 00:00:01 |
|   3 |    HASH GROUP BY     |      |     1 |    10 |     3   (0)| 00:00:01 |
|*  4 |     TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
|*  5 |   VIEW               |      |     1 |    41 |     3   (0)| 00:00:01 |
|   6 |    SORT GROUP BY     |      |     3 |    30 |     3   (0)| 00:00:01 |
|*  7 |     TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("DEPTNO"=10)
   5 - filter("E1"."DEPTNO"="E2"."DEPTNO")
   7 - filter("DEPTNO"=10)


-- predicate Move Around 기능이 작동하지 않을때

select /*+ opt_param('_pred_move_around','false') */ * from 
   (select deptno, avg(sal) from emp where deptno=10 group by deptno) e1
   ,(select deptno, min(sal), max(sal) from emp group by deptno) e2
 where e1.deptno =e2.deptno;

Execution Plan
----------------------------------------------------------
Plan hash value: 2943274104

-------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                |     1 |    65 |     7  (29)| 00:00:01 |
|*  1 |  HASH JOIN                     |                |     1 |    65 |     7  (29)| 00:00:01 |
|   2 |   VIEW                         |                |     1 |    26 |     2   (0)| 00:00:01 |
|   3 |    HASH GROUP BY               |                |     1 |     7 |     2   (0)| 00:00:01 |
|   4 |     TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    35 |     2   (0)| 00:00:01 |
|*  5 |      INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
|   6 |   VIEW                         |                |     3 |   117 |     4  (25)| 00:00:01 |
|   7 |    HASH GROUP BY               |                |     3 |    21 |     4  (25)| 00:00:01 |
|   8 |     TABLE ACCESS FULL          | EMP            |    14 |    98 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("E1"."DEPTNO"="E2"."DEPTNO")
   5 - access("DEPTNO"=10)

-- 힌트없이
Execution Plan
----------------------------------------------------------
Plan hash value: 4253239321

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     1 |    69 |     6   (0)| 00:00:01 |
|   1 |  NESTED LOOPS        |      |     1 |    69 |     6   (0)| 00:00:01 |
|   2 |   VIEW               |      |     1 |    28 |     3   (0)| 00:00:01 |
|   3 |    HASH GROUP BY     |      |     1 |    10 |     3   (0)| 00:00:01 |
|*  4 |     TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
|*  5 |   VIEW               |      |     1 |    41 |     3   (0)| 00:00:01 |
|   6 |    SORT GROUP BY     |      |     3 |    30 |     3   (0)| 00:00:01 |
|*  7 |     TABLE ACCESS FULL| EMP  |     5 |    50 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("DEPTNO"=10)
   5 - filter("E1"."DEPTNO"="E2"."DEPTNO")
   7 - filter("DEPTNO"=10)
```



## 4) 조인조건 Pushdown

- push_pred : 조인 조건 Pushdown 유도
- no_push_pred : 조인 조건 Pushdown 방지



#### 관련 파라미터

- _push_join_predicate : 뷰 merging에 실패한 뷰 안쪽으로 조인조건을 pushdown 하는 기능 활성화
- _push_join_union_view : union all을 포함하는 non-mergeable 뷰 안쪽으로 조인 조건을 pushdown 하는 기능 활성화
- _push_join_union_view2 : union 을 포함하는 non-mergeable 뷰 안쪽으로 조인조건을 pushdown 하는 기능 활성화 (9i 없음)



```sql
-- 조인을 수행하는 중에 드라이빙 집합에서 얻은 값을 뷰 쿼리 블록 안에 실시간으로 Pushing 하는 기능

select /*+ no_merge(e) push_pred(e) */ *
from dept d, (select empno, ename, deptno from emp) e
where e.deptno(+) = d.deptno
and d.loc='CHICAGO';


Execution Plan
----------------------------------------------------------
Plan hash value: 3116586712

------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                |     4 |   220 |     5   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER           |                |     4 |   220 |     5   (0)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL           | DEPT           |     1 |    20 |     3   (0)| 00:00:01 |
|   3 |   VIEW PUSHED PREDICATE       |                |     1 |    35 |     2   (0)| 00:00:01 |
|   4 |    TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    80 |     2   (0)| 00:00:01 |
|*  5 |     INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("D"."LOC"='CHICAGO')
   5 - access("DEPTNO"="D"."DEPTNO")

-- 힌트없이 
Execution Plan
----------------------------------------------------------
Plan hash value: 1436240027

--------------------------------------------------------------------------------
| Id  | Operation               | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------
|   0 | SELECT STATEMENT        |      |     4 |   220 |     6   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER     |      |     4 |   220 |     6   (0)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL     | DEPT |     1 |    20 |     3   (0)| 00:00:01 |
|   3 |   VIEW PUSHED PREDICATE |      |     1 |    35 |     3   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL    | EMP  |     5 |    65 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("D"."LOC"='CHICAGO')
   4 - filter("DEPTNO"="D"."DEPTNO")
```





### Group by 절을 포함한 뷰에 대한 조인 조건 pushdown(11g)

```sql
-- 조인조건 pushdown이 작동하지 않아 emp쪽 인덱스를 full scan 함.
-- dept 테이블에서 읽히는 deptno마다 emp 테이블  전체를 groupby 함.

select /*+ leading(d) use_nl(e) no_merge(e) push_pred(e) */
      d.deptno, d.dname, e.avg_sal
from dept d
     , (select deptno, avg(sal) avg_sal from emp group by deptno) e
where e.deptno(+) = d.deptno;

Execution Plan
----------------------------------------------------------
Plan hash value: 888758277

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     4 |   156 |    19  (22)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER  |      |     4 |   156 |    19  (22)| 00:00:01 |
|   2 |   TABLE ACCESS FULL  | DEPT |     4 |    52 |     3   (0)| 00:00:01 |
|*  3 |   VIEW               |      |     1 |    26 |     4  (25)| 00:00:01 |
|   4 |    SORT GROUP BY     |      |     3 |    21 |     4  (25)| 00:00:01 |
|   5 |     TABLE ACCESS FULL| EMP  |    14 |    98 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("E"."DEPTNO"(+)="D"."DEPTNO")


-- 힌트없이

Execution Plan
----------------------------------------------------------
Plan hash value: 3996696585

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     4 |   156 |    19  (22)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER  |      |     4 |   156 |    19  (22)| 00:00:01 |
|   2 |   TABLE ACCESS FULL  | DEPT |     4 |    52 |     3   (0)| 00:00:01 |
|*  3 |   VIEW               |      |     1 |    26 |     4  (25)| 00:00:01 |
|   4 |    SORT GROUP BY     |      |     3 |    21 |     4  (25)| 00:00:01 |
|   5 |     TABLE ACCESS FULL| EMP  |    14 |    98 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("E"."DEPTNO"(+)="D"."DEPTNO")


-- 11g 실행

Execution Plan
----------------------------------------------------------
Plan hash value: 2312958772

--------------------------------------------------------------------------------
| Id  | Operation               | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------
|   0 | SELECT STATEMENT        |      |    14 |   490 |    15   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER     |      |    14 |   490 |    15   (0)| 00:00:01 |
|   2 |   TABLE ACCESS FULL     | DEPT |     4 |    88 |     3   (0)| 00:00:01 |
|   3 |   VIEW PUSHED PREDICATE |      |     1 |    13 |     3   (0)| 00:00:01 |
|*  4 |    FILTER               |      |       |       |            |          |
|   5 |     SORT AGGREGATE      |      |     1 |    26 |            |          |
|*  6 |      TABLE ACCESS FULL  | EMP  |     1 |    26 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter(COUNT(*)>0)
   6 - filter("DEPTNO"="D"."DEPTNO")


-- 집계함수가 하나일때
select d.deptno, d.dname
      ,(select avg(sal) from emp where deptno=d.deptno)
from dept d;

Execution Plan
----------------------------------------------------------
Plan hash value: 2190379904

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     4 |    52 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE              |                |     1 |     7 |            |          |
|   2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     5 |    35 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
|   4 |  TABLE ACCESS FULL           | DEPT           |     4 |    52 |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("DEPTNO"=:B1)


-- 힌트없이
Execution Plan
----------------------------------------------------------
Plan hash value: 4111639169

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     4 |    52 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE    |      |     1 |     7 |            |          |
|*  2 |   TABLE ACCESS FULL| EMP  |     5 |    35 |     3   (0)| 00:00:01 |
|   3 |  TABLE ACCESS FULL | DEPT |     4 |    52 |     3   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("DEPTNO"=:B1)


-집계함수가 두개 이상일때

 - 필요한 컬럼값들을 모두 결합하고나서 
   바깥쪽 액세스 쿼리에서 substr함수로 다시 분리하거나 
   오브젝트 type을 사용하는 방식을 고려
```





### UNION 집합 연산을 포함한 뷰에 대한 조인 조건 pushdown(10g)

```sql
create index dept_idx on dept(loc);
create index emp_idx on emp(deptno, job);

select /*+ push_pred(e) */ d.dname, e.*
from dept d
    ,(select deptno, empno, ename, job, sal, sal*1.1 sal2, hiredate from emp
      where job='CLERK'
      union all 
      select deptno, empno, ename, job, sal, sal*1.2 sal2, hiredate from emp
      where job='SALESMAN') e
where e.deptno=d.deptno
and d.loc='CHICAGO';

Execution Plan
----------------------------------------------------------
Plan hash value: 4023361524

-------------------------------------------------------------------------------------------
| Id  | Operation                      | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |          |     2 |   200 |     6   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                  |          |     2 |   200 |     6   (0)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID  | DEPT     |     1 |    20 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN            | DEPT_IDX |     1 |       |     1   (0)| 00:00:01 |
|   4 |   VIEW                         |          |     1 |    80 |     4   (0)| 00:00:01 |
|   5 |    UNION ALL PUSHED PREDICATE  |          |       |       |            |          |
|   6 |     TABLE ACCESS BY INDEX ROWID| EMP      |     1 |    36 |     2   (0)| 00:00:01 |
|*  7 |      INDEX RANGE SCAN          | EMP_IDX  |     2 |       |     1   (0)| 00:00:01 |
|   8 |     TABLE ACCESS BY INDEX ROWID| EMP      |     1 |    36 |     2   (0)| 00:00:01 |
|*  9 |      INDEX RANGE SCAN          | EMP_IDX  |     2 |       |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("D"."LOC"='CHICAGO')
   7 - access("DEPTNO"="D"."DEPTNO" AND "JOB"='CLERK')
   9 - access("DEPTNO"="D"."DEPTNO" AND "JOB"='SALESMAN')


-- 힌트없이
Execution Plan
----------------------------------------------------------
Plan hash value: 1378159300

--------------------------------------------------------------------------------------
| Id  | Operation                     | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |      |     2 |   200 |     9   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                 |      |     2 |   200 |     9   (0)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL           | DEPT |     1 |    20 |     3   (0)| 00:00:01 |
|   3 |   VIEW                        |      |     1 |    80 |     6   (0)| 00:00:01 |
|   4 |    UNION ALL PUSHED PREDICATE |      |       |       |            |          |
|*  5 |     TABLE ACCESS FULL         | EMP  |     1 |    33 |     3   (0)| 00:00:01 |
|*  6 |     TABLE ACCESS FULL         | EMP  |     1 |    33 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("D"."LOC"='CHICAGO')
   5 - filter("JOB"='CLERK' AND "DEPTNO"="D"."DEPTNO")
   6 - filter("JOB"='SALESMAN' AND "DEPTNO"="D"."DEPTNO")
```





### Outer 조인 뷰에 대한 조인 조건 Pushdown(9i 부터)

```sql
-- 뷰 안에서 참조하는 테이블이 단 하나일 때, 뷰 merging 을 시도함
-- 뷰 내에서 참조하는 테이블이 두 개 이상일때 조인 조건식을 뷰 안쪽으로 Pushing 하려고 시도

select /*+ push_pred(b) */    
       a.empno, a.ename, a.sal, a.hiredate, b.deptno, b.dname, b.loc, a.job
from emp a
    ,(select e.empno, d.deptno, d.dname, d.loc
       from emp e , dept d
       where d.deptno=e.deptno
       and  e.sal>=1000
       and  d.loc in ('CHICAGO','NEW YORK')) b
where b.empno(+) = a.empno
and  a.hiredate >= to_date('19810901','yyyymmdd');


Execution Plan
----------------------------------------------------------
Plan hash value: 4171644824

------------------------------------------------------------------------------------------
| Id  | Operation                      | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |         |    14 |   952 |    31   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER            |         |    14 |   952 |    31   (0)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL            | EMP     |    14 |   476 |     3   (0)| 00:00:01 |
|   3 |   VIEW PUSHED PREDICATE        |         |     1 |    34 |     2   (0)| 00:00:01 |
|   4 |    NESTED LOOPS                |         |     1 |    35 |     2   (0)| 00:00:01 |
|*  5 |     TABLE ACCESS BY INDEX ROWID| EMP     |     1 |    15 |     1   (0)| 00:00:01 |
|*  6 |      INDEX UNIQUE SCAN         | PK_EMP  |     1 |       |     0   (0)| 00:00:01 |
|*  7 |     TABLE ACCESS BY INDEX ROWID| DEPT    |     2 |    40 |     1   (0)| 00:00:01 |
|*  8 |      INDEX UNIQUE SCAN         | PK_DEPT |     1 |       |     0   (0)| 00:00:01 |
------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("A"."HIREDATE">=TO_DATE('1981-09-01 00:00:00', 'yyyy-mm-dd
              hh24:mi:ss'))
   5 - filter("E"."SAL">=1000)
   6 - access("E"."EMPNO"="A"."EMPNO")
   7 - filter("D"."LOC"='CHICAGO' OR "D"."LOC"='NEW YORK')
   8 - access("D"."DEPTNO"="E"."DEPTNO")


-- 뷰안에서 참조하는 테이블이 하나일때에도  no_merge  힌트를 사용하면 뷰 merging을 방지하며 위와 같이 조인조건 pushdown이 작동함
```



