# 07. OR Expansion



## 1)  OR-Expansion 이란

- OR연산자나 IN연산자를 사용하였을 때 내부적으로 Concatnation실행계획으로 처리되어 마치 2개 쿼리로 나누어져서 실행되는 쿼리변환기능



##### 힌트

- **USE_CONCAT : OR-Expansion 유도**
- **NO_EXPAND : OR-Expansion 방지**
- alter session set "_no_or_expansion"=true; 
  - 위 설정 후 USE_CONCAT설정을 해도 동작 안함

```sql
select * from emp
 where job='CLERK' or deptno=20;

Execution Plan
----------------------------------------------------------
Plan hash value: 3956160932

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     7 |   259 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| EMP  |     7 |   259 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------

select * from emp
where job='CLERK' 
union all
select * from emp
where deptno=20;

Execution Plan
----------------------------------------------------------
Plan hash value: 3447806485

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     8 |   296 |     4  (50)| 00:00:01 |
|   1 |  UNION-ALL                   |                |       |       |            |          |
|   2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     3 |   111 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_JOB_IDX    |     3 |       |     1   (0)| 00:00:01 |
|   4 |   TABLE ACCESS BY INDEX ROWID| EMP            |     5 |   185 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("JOB"='CLERK')
   5 - access("DEPTNO"=20)



--  옵티마이저에 의한 쿼리변환 
select /*+ use_concat */* from emp
where job='CLERK'  or  deptno=20;

Execution Plan
----------------------------------------------------------
Plan hash value: 668283641

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     8 |   304 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION               |                |       |       |            |          |
|   2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     4 |   152 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_JOB_IDX    |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   TABLE ACCESS BY INDEX ROWID| EMP            |     4 |   152 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     5 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("JOB"='CLERK')
   4 - filter(LNNVL("JOB"='CLERK'))
   5 - access("DEPTNO"=20)
```



- 분기된 쿼리가 각각 다른 인덱스를 사용하긴 하지만 emp 테이블의 엑세스가 두번일어난다. 
  중복엑세스되는 영역의 비중이 작을수록 효과적이고,그 반대의 경우라면 오히려 쿼리수행 비용이 증가한다. 
  (OR-Expansion 이 비용기반으로 작동하는 이유가 이때문이다.)
  중복엑세스 되더라도 결과집합에는 중복이 없게 하려고 내부적으로 LNNVL 함수를 사용한것을 확인할 수 있다.
  job<>'CLERK' 이거나 job is null 인 집합만 읽으려는 것이며 이 함수는 조건식이 false 이거나 알수없는 값일때 true를 리턴한다.

  ~~~sql
    LNNVL(1=1)    : FALSE
    LNNVL(1=2)    : TRUE
    LNNVL(Null=1) : TRUE
  ~~~

  

~~~sql
-- 힌트사용(no_expand)
 OR -Expansion 사용못하도록 방지
 alter session set "_no_or_expansion"=true; 로도 설정가능하다.

select /*+ no_expand */* from emp
where job='CLERK'  or  deptno=20;

Execution Plan
----------------------------------------------------------
Plan hash value: 3956160932

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     7 |   259 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| EMP  |     7 |   259 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("DEPTNO"=20 OR "JOB"='CLERK')
~~~





## 2) OR-Expansion 브랜치별 조인순서 최적화

```sql
create index emp_n3 on emp (sal);

create index dept_n1 on dept (loc);

exec dbms_stats.gather_index_stats (ownname => 'scott', indname => 'emp_n3' , degree => 1);

exec dbms_stats.gather_index_stats (ownname => 'scott', indname => 'dept_n1' , degree => 1);


select /*+ no_expand */ *
  from emp e, dept d
where d.deptno = e.deptno
 and e.sal >= 2000
 and (e.job = 'SALESMAN' or d.loc = 'CHICAGO');

Execution Plan
----------------------------------------------------------
Plan hash value: 275621146

------------------------------------------------------------------------------------------
| Id  | Operation                      | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |         |     2 |   116 |     5  (20)| 00:00:01 |
|   1 |  MERGE JOIN                    |         |     2 |   116 |     5  (20)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID  | DEPT    |     4 |    80 |     2   (0)| 00:00:01 |
|   3 |    INDEX FULL SCAN             | PK_DEPT |     4 |       |     1   (0)| 00:00:01 |
|*  4 |   FILTER                       |         |       |       |            |          |
|*  5 |    SORT JOIN                   |         |     6 |   228 |     3  (34)| 00:00:01 |
|   6 |     TABLE ACCESS BY INDEX ROWID| EMP     |     6 |   228 |     2   (0)| 00:00:01 |
|*  7 |      INDEX RANGE SCAN          | EMP_N3  |     6 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("E"."JOB"='SALESMAN' OR "D"."LOC"='CHICAGO')
   5 - access("D"."DEPTNO"="E"."DEPTNO")
       filter("D"."DEPTNO"="E"."DEPTNO")
   7 - access("E"."SAL">=2000)




-- USE_CONCAT 힌트 TEST
select /*+  use_concat */ *
  from emp e, dept d
where d.deptno = e.deptno
 and e.sal >= 2000
 and (e.job = 'SALESMAN' or d.loc = 'CHICAGO');


Execution Plan
----------------------------------------------------------
Plan hash value: 2632617833

-------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                |     3 |   174 |     6   (0)| 00:00:01 |
|   1 |  CONCATENATION                 |                |       |       |            |          |
|   2 |   NESTED LOOPS                 |                |       |       |            |          |
|   3 |    NESTED LOOPS                |                |     2 |   116 |     3   (0)| 00:00:01 |
|   4 |     TABLE ACCESS BY INDEX ROWID| DEPT           |     1 |    20 |     2   (0)| 00:00:01 |
|*  5 |      INDEX RANGE SCAN          | DEPT_N1        |     1 |       |     1   (0)| 00:00:01 |
|*  6 |     INDEX RANGE SCAN           | EMP_DEPTNO_IDX |     5 |       |     0   (0)| 00:00:01 |
|*  7 |    TABLE ACCESS BY INDEX ROWID | EMP            |     2 |    76 |     1   (0)| 00:00:01 |
|   8 |   NESTED LOOPS                 |                |       |       |            |          |
|   9 |    NESTED LOOPS                |                |     1 |    58 |     3   (0)| 00:00:01 |
|* 10 |     TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|* 11 |      INDEX RANGE SCAN          | EMP_JOB_IDX    |     4 |       |     1   (0)| 00:00:01 |
|* 12 |     INDEX UNIQUE SCAN          | PK_DEPT        |     1 |       |     0   (0)| 00:00:01 |
|* 13 |    TABLE ACCESS BY INDEX ROWID | DEPT           |     1 |    20 |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   5 - access("D"."LOC"='CHICAGO')
   6 - access("D"."DEPTNO"="E"."DEPTNO")
   7 - filter("E"."SAL">=2000)
  10 - filter("E"."SAL">=2000)
  11 - access("E"."JOB"='SALESMAN')
  12 - access("D"."DEPTNO"="E"."DEPTNO")
  13 - filter(LNNVL("D"."LOC"='CHICAGO')) -- 교집합 출력방지 
```



## 3) 같은 컬럼에 대한 OR-Expansion

```sql
-- OR절 
select  *
  from emp
where (deptno = 10 or deptno = 30)
  and ename = 'CLARK';

Execution Plan
----------------------------------------------------------
Plan hash value: 1707373705

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     1 |    38 |     2   (0)| 00:00:01 |
|   1 |  INLIST ITERATOR             |                |       |       |            |          |
|*  2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     9 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("ENAME"='CLARK')
   3 - access("DEPTNO"=10 OR "DEPTNO"=30)

-- OR OR-Expansion 유도
-- use_concat 힌트에 아래와 같이 인자를 제공하여  유도할수 있다 

select /*+  qb_name(MAIN) use_concat(@MAIN 1) */ *
  from emp e
where (deptno = 10 or deptno = 30)
 and ename = 'CLARK';

Execution Plan
----------------------------------------------------------
Plan hash value: 809118877

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     2 |    76 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION               |                |       |       |            |          |
|*  2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     3 |       |     1   (0)| 00:00:01 |
|*  4 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     6 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("ENAME"='CLARK')
   3 - access("DEPTNO"=10)
   4 - filter("ENAME"='CLARK')
   5 - access("DEPTNO"=30)



-- IN 절 
select  *
  from emp
where deptno in (10, 30)
 and ename = 'CLARK';



Execution Plan
----------------------------------------------------------
Plan hash value: 1707373705

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     1 |    38 |     2   (0)| 00:00:01 |
|   1 |  INLIST ITERATOR             |                |       |       |            |          |
|*  2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     9 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("ENAME"='CLARK')
   3 - access("DEPTNO"=10 OR "DEPTNO"=30)

-- IN 절  OR-Expansion 유도
select /*+  qb_name(MAIN) use_concat(@MAIN 1) */ *
  from emp
where deptno in (10, 30)
 and ename = 'CLARK';


Execution Plan
----------------------------------------------------------
Plan hash value: 809118877

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     2 |    76 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION               |                |       |       |            |          |
|*  2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     3 |       |     1   (0)| 00:00:01 |
|*  4 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     6 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("ENAME"='CLARK')
   3 - access("DEPTNO"=10)
   4 - filter("ENAME"='CLARK')
   5 - access("DEPTNO"=30)
```

- or-expansion을 유도해도 INLIST ITERATOR  보다 나아지는 점이 없으므로 굳이 그렇게 할 이유가 없다.





#### 주의

- 9i까지는 OR 조건이나 IN-list를 힌트를 이용해 OR-Expansion으로 유도하면 뒤쪽에 놓인 값이 항상 먼저 출력되었다
- 하지만 10g는 CPU 비용모델에서는 위와 같이 OR-Expantion을 유도 했을때 통계적으로 카디널리티가 작은 값을 먼저 출력하게 된다.
- 9i처럼 뒤쪽의 값을 먼저 출력되게 하려면 `ordered_predicates` 힌트를 사용하거나 IO 비용모델을 바꿔야 한다.
- 10g 이후버전에서는 비교연산자가 equal '=' d 이 아닐때는 일반적으로 use_concat 힌트만으로도 컬럼에 대한 OR-Expansion이 잘 작동한다.

```sql
select *
  from emp
 where (deptno = 10 or deptno >= 30)
   and ename = 'CLARK';

Execution Plan
----------------------------------------------------------
Plan hash value: 3956160932

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     1 |    38 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| EMP  |     1 |    38 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("ENAME"='CLARK' AND ("DEPTNO">=30 OR "DEPTNO"=10))

select /*+ use_concat */*
  from emp
 where (deptno = 10 or deptno >= 30)
   and ename = 'CLARK';

Execution Plan
----------------------------------------------------------
Plan hash value: 809118877

-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |     2 |    76 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION               |                |       |       |            |          |
|*  2 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     3 |       |     1   (0)| 00:00:01 |
|*  4 |   TABLE ACCESS BY INDEX ROWID| EMP            |     1 |    38 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_DEPTNO_IDX |     6 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("ENAME"='CLARK')
   3 - access("DEPTNO"=10)
   4 - filter("ENAME"='CLARK')
   5 - access("DEPTNO">=30)
       filter(LNNVL("DEPTNO"=10))
```





## 4) nvl/decode 조건식에 대한 OR-Expansion

- 사용자가 선택적으로 입력하는 조건절에 대해 nvl 또는 decode 함수를 이용할수 있다
- 아래의 쿼리는 deptno 검색조건을 사용자가 선택적으로 입력할 수 있는 경우를 대비하기 위한것이다.

```sql
-NVL
select *
  from emp
where deptno = nvl(:deptno, deptno)
	and ename like :ename || '%';

Execution Plan
-----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=4 Card=3 Bytes=114)
   1    0   CONCATENATION
   2    1     FILTER
   3    2       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=2 Bytes=76)
   4    3         INDEX (RANGE SCAN) OF 'SCOTT.EMP_N4' (INDEX) (Cost=1 Card=2)
   5    1     FILTER
   6    5       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=1 Bytes=38)
   7    6         INDEX (RANGE SCAN) OF 'SCOTT.EMP_DEPTNO_IDX' (INDEX) (Cost=1 Card=5)
-----------------------------------------------------------

Predicate information (identified by operation id):
-----------------------------------------------------------
   2 - filter(:DEPTNO IS NULL)
   3 - filter("DEPTNO" IS NOT NULL)
   4 - access("ENAME" LIKE :ENAME||'%')
   4 - filter("ENAME" LIKE :ENAME||'%')
   5 - filter(:DEPTNO IS NOT NULL)
   6 - filter("ENAME" LIKE :ENAME||'%')
   7 - access("DEPTNO"=:DEPTNO)
-----------------------------------------------------------

-- 위쪽 브랜치는 EMP_N4 사용
-- 아래 브랜치는 EMP_DEPTNO_IDX 사용

-= 위와 같은 형태로 쿼리를 작성하면 오라클 9i에서는 아래와 같은 OR-Expansion 쿼리 변환이 일어난다 
select * from emp
 where :deptno is null
   and deptno is not null
   and ename like :ename || '%'
 union all
select * from emp
 where :deptno is not null
   and deptno = :deptno
   and ename like :ename || '%';

Execution Plan
-----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=4 Card=3 Bytes=114)
   1    0   UNION-ALL
   2    1     FILTER
   3    2       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=2 Bytes=76)
   4    3         INDEX (RANGE SCAN) OF 'SCOTT.EMP_N4' (INDEX) (Cost=1 Card=2)
   5    1     FILTER
   6    5       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=1 Bytes=38)
   7    6         INDEX (RANGE SCAN) OF 'SCOTT.EMP_DEPTNO_IDX' (INDEX) (Cost=1 Card=5)
-----------------------------------------------------------

Predicate information (identified by operation id):
-----------------------------------------------------------
   2 - filter(:DEPTNO IS NULL)
   3 - filter("DEPTNO" IS NOT NULL)
   4 - access("ENAME" LIKE :ENAME||'%')
   4 - filter("ENAME" LIKE :ENAME||'%')
   5 - filter(:DEPTNO IS NOT NULL)
   6 - filter("ENAME" LIKE :ENAME||'%')
   7 - access("DEPTNO"=TO_NUMBER(:DEPTNO))
-----------------------------------------------------------

-- deptno 변수값의 null 여부에 따라 위 또는 아래쪽 브렌치만 수행하는것이다.
-- decode 함수를 사용하더라도 같은 처리가 일어난다

select * from emp
 where deptno = decode(:deptno, null, deptno, :deptno)
   and ename like :ename || '%';

Execution Plan
-----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=4 Card=3 Bytes=114)
   1    0   CONCATENATION
   2    1     FILTER
   3    2       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=2 Bytes=76)
   4    3         INDEX (RANGE SCAN) OF 'SCOTT.EMP_N4' (INDEX) (Cost=1 Card=2)
   5    1     FILTER
   6    5       TABLE ACCESS (BY INDEX ROWID) OF 'SCOTT.EMP' (TABLE) (Cost=2 Card=1 Bytes=38)
   7    6         INDEX (RANGE SCAN) OF 'SCOTT.EMP_DEPTNO_IDX' (INDEX) (Cost=1 Card=5)
-----------------------------------------------------------

Predicate information (identified by operation id):
-----------------------------------------------------------
   2 - filter(:DEPTNO IS NULL)
   3 - filter("DEPTNO" IS NOT NULL)
   4 - access("ENAME" LIKE :ENAME||'%')
   4 - filter("ENAME" LIKE :ENAME||'%')
   5 - filter(:DEPTNO IS NOT NULL)
   6 - filter("ENAME" LIKE :ENAME||'%')
   7 - access("DEPTNO"=:DEPTNO)
-----------------------------------------------------------

-- dbptno 변수값의 입력 여부에 따라 다른 인덱스를 사용한다
-- deptno 변수에 null 이 들어오면 위쪽 EMP_N4를 사용하고, null값이 아닌 값이 들어오면 EMP_DEPTNO_IDX를 사용하게 된다
```

- 제어 파라미터:  `_or_expand_nvl_predicate`이다. 
- 오래전부터 튜너들은 union all을 이용해서 위와 같은 튜닝기법을 사용하였는데,
  이제는 옵티마이저가 스스로 그런 처리를 함으로써 많이 편리해졌다
- 하지만 nvl 또는 decode 를 여러 컬럼에서 사용했을때는 그중 변별력이 가장 좋은 컬럼을 기준으로 한번만 분기가 일어난다.
  이러한 이유로 옵션조건이 복잡할때는 이방식에만 의존하기 어렵고 그럴때는 여전히 수동으로 union all 분기 해줘야 한다.
