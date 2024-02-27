# 04. DBMS_SPLAN 패키지



- DBMS_XPLAN 패키지를 통해 plan_table에 저장된 실행계획을 좀더 편리하게 볼수 있다.
- 오라클 10g부터는 라이브러리 캐시에 캐싱되어있는 SQL커서에 대한 실행계획뿐 아니라 Row Source별 수행통계까지 손쉽게 출력할수 있도록 기능이 확장되었다.
- AWR에 수집되었던 과거수행했던 SQL 실행계획을 확인하는 것도 가능하다.



## (1) 실행계획 출력하기

- 저장된 실행계획 보기위해 오라클에서 제공하는 UTLXPLS.SQL, UTLXPLP.SQL 스크립트를 이용하면 된다고 했는데, 이 스크립트 열어보면, DBMS_XPLAN 패키지에 있는 DISPLAY function을 호출하고 있다.
  (병렬쿼리에 대한 실행계획을 보려면, UTLXPLP.SQL를 이용)

```sql
select plan_table_output
from table(dbms_xplan.display('plan_table', null, 'serial'));



Plan hash value: 2949544139
--------------------------------------------------------------------------------------
| Id  | Operation		    | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT	    |	     |	   1 |	  87 |	   1   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP    |	   1 |	  87 |	   1   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN	    | PK_EMP |	   1 |	     |	   1   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------

   2 - access("EMPNO"=7900)

14 rows selected.
```

- 직접 DBMS_XPLAN.DISPLAY function을 호출하면 다양한 포맷 옵션을 선택할 수 있다.
  
- FORMAT을 아래와 함께 구사하면, 다양하게 이용가능
  ROWS, BYTES, COST, PARTITION, PARALLEL, PREDICATE, PROJECTION, ALIAS, REMOTE, NOTE

- 암것도 입력 안하면
  'PLAN_TABLE'에 담긴 실행계획정보중에서 마지막에 실행된 실행계획을 보여주는데, 출력포맷은 'TYPICAL'옵션으로 출력한다라는 의미\!







#### 예상 실행계획 출력

- Plan_Table에 저장된 실행계획을 좀 더 쉽게 출력, 10g부터는 실행계획과 Row Source별 수행 통계까지 출력 가능

```sql
-- args: 실행 계획이 저장된 Plan_Table 명, NULL일 경우 가장 마지막 explain_plan 출력, 포맷 옵션:Basic, Typical, All, Outline, Advanced
select plan_table_output
from table (dbms_xplan.display('plan_table',null,'all'));
                  

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Plan hash value: 2949544139

--------------------------------------------------------------------------------------
| Id  | Operation		    | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT	    |	     |	   1 |	  87 |	   1   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP    |	   1 |	  87 |	   1   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN	    | PK_EMP |	   1 |	     |	   1   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Query Block Name / Object Alias (identified by operation id):

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------

   1 - SEL$1 / EMP@SEL$1
   2 - SEL$1 / EMP@SEL$1

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("EMPNO"=7900)

Column Projection Information (identified by operation id):

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------

   1 - "EMPNO"[NUMBER,22], "EMP"."ENAME"[VARCHAR2,10],
       "EMP"."JOB"[VARCHAR2,9], "EMP"."MGR"[NUMBER,22], "EMP"."HIREDATE"[DATE,7],
       "EMP"."SAL"[NUMBER,22], "EMP"."COMM"[NUMBER,22], "EMP"."DEPTNO"[NUMBER,22]
   2 - "EMP".ROWID[ROWID,10], "EMPNO"[NUMBER,22]

28 rows selected.
```







## (2) 캐싱된 커서의 실제 실행계획 출력

- 커서한 하드파싱과정을 거쳐서 메모리에 적재된 SQL과 Parse Tree, 실행계획, 그리고 그것을 실행하는데 필요한 정보를 담은 SQL Area를 말한다.
- 오라클은 라이브러리 캐시에 캐싱되어 있는 각 커서에 대한 수행통계를 볼 수 있도록 v$sql 뷰를 제공.
- 이와 함께 sql_id 값과 조인에서 사용할 수 있도록 v$sql_plan, v$sql_plan_statistics, v$sql_plan_statistics_all 등의 뷰를 제공
- v$sql_plan 뷰를 일반 plan_table처럼 쿼리해서 조회할 수 있으나, dbms_xplan.display_cursor함수를 이용하면 편리.

- dbms_xplan.display_cursor함수 - 단일 SQL문에 대해 실제 수행된 실행계획을 보여주는 Function
  
- 참고로, dbms_xplan.display_awr함수를 이용하면 AWR에 수집된 과거 수행되었던SQL에 대해서도 같은 분석작업을 진행할 수 있다.





- #### 캐싱된 커서의 실제 실행계획 출력

  - 커서: 하드파싱 과정을 거쳐 메모리에 적재된 SQL과 Parse Tree,실행 계획 그리고 그것을 실행하는데 필요한 정보를 담은 SQL Area
  - 오라클은 라이브러리 캐시에 캐싱되어 있는 수행 통계를 볼 수 있도록 v$sql 뷰를 제공

~~~sql
set serveroutput off

select *
from emp e, dept d
  where d.deptno = e.deptno
  and e.sal >= 1000;


column prev_sql_id new_value sql_id
column prev_chi1d_number new_value child_no

select prev_sql_id, prev_child_number
  from v$session
  where sid=userenv('sid')
  and username is not null
  and prev_hash_value <> 0;
  
  
PREV_SQL_ID   PREV_CHILD_NUMBER
------------- -----------------
8zydhqq80qyh8		      0
  
  
  select *
from table (dbms_xplan.display_cursor('8zydhqq80qyh8'
                                             ,0
                                             ,'ALLSTATS LAST'));
                                             
PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SQL_ID	8zydhqq80qyh8, child number 0
-------------------------------------
select * from emp e, dept d   where d.deptno = e.deptno   and e.sal >=
1000

Plan hash value: 615168685

-----------------------------------------------------------------------
| Id  | Operation	   | Name | E-Rows |  OMem |  1Mem | Used-Mem |
-----------------------------------------------------------------------
|   0 | SELECT STATEMENT   |	  |	   |	   |	   |	      |

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
|*  1 |  HASH JOIN	   |	  |	12 |  1000K|  1000K|  762K (0)|
|   2 |   TABLE ACCESS FULL| DEPT |	 4 |	   |	   |	      |
|*  3 |   TABLE ACCESS FULL| EMP  |	12 |	   |	   |	      |
-----------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("D"."DEPTNO"="E"."DEPTNO")
   3 - filter("E"."SAL">=1000)


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Note
-----
   - dynamic sampling used for this statement (level=2)
   - Warning: basic plan statistics not available. These are only collected when:
       * hint 'gather_plan_statistics' is used for the statement or
       * parameter 'statistics_level' is set to 'ALL', at session or system level


29 rows selected.
~~~







## (3) 캐싱된 커서의 Row Source별 수행통계 출력

- SQL문에 gather_plan_statistics 힌트를 사용하거나, 시스템 또는 세션레벨에서 statistics_level파라미터를 all로 설정하면,
  오라클은 실제 SQL을 수행하는 동안의 실행계획 각 오퍼레이션 단계(Row Source)로 수행통계를 수집한다.
  (참고로, '_rowsource_execution_statistics'파라미터를 true로 설정하거나, SQL트레이스를 걸어도 Row Source별 수행통계가 수집된다.)



- #### 캐싱된 커서의 Row Source별 수행 통계 출력

  - /*\+ gather_plan_statistics \*/ 힌트를 사용 (set serveroutput off)
  - 시스템 또는 세션 레벨에서 statisticts_level 파라미터를 All로 설정(운영DB에서는 삼가)

~~~sql
set serveroutput off
select /*+ gather_plan_statistics */ *
  from emp e, dept d
  where d.deptno = e.deptno
  and e.sal >= 1000;

column prev_sql_id new_value sql_id
column prev_chi1d_number new_value child_no
select prev_sql_id, prev_child_number
  from v$session
  where sid=userenv('sid')
  and username is not null
  and prev_hash_value <> 0;
  
PREV_SQL_ID   PREV_CHILD_NUMBER
------------- -----------------
07z3bazhvzxm2		      0
  
select *
from table (dbms_xplan.display_cursor('07z3bazhvzxm2'
                                             ,0
                                             ,'ALLSTATS LAST'));
                                             
PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SQL_ID	07z3bazhvzxm2, child number 0
-------------------------------------
select /*+ gather_plan_statistics */ *	 from emp e, dept d   where
d.deptno = e.deptno   and e.sal >= 1000

Plan hash value: 615168685

----------------------------------------------------------------------------------------------------------------
| Id  | Operation	   | Name | Starts | E-Rows | A-Rows |	 A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
----------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |	  |	 1 |	    |	  12 |00:00:00.01 |	  7 |	    |	    |	       |

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
|*  1 |  HASH JOIN	   |	  |	 1 |	 12 |	  12 |00:00:00.01 |	  7 |  1000K|  1000K|  754K (0)|
|   2 |   TABLE ACCESS FULL| DEPT |	 1 |	  4 |	   4 |00:00:00.01 |	  3 |	    |	    |	       |
|*  3 |   TABLE ACCESS FULL| EMP  |	 1 |	 12 |	  12 |00:00:00.01 |	  4 |	    |	    |	       |
----------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("D"."DEPTNO"="E"."DEPTNO")
   3 - filter("E"."SAL">=1000)


PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Note
-----
   - dynamic sampling used for this statement (level=2)


26 rows selected.
~~~

- E-Rows는 SQL을 수행하기 전 옵티마이저가 각 Row Source별 예상했던 로우 수(v$sql_plan)
- A-Rows는 실제 수행 시 읽었던 로우 수(v$sql_plan_statistics)
- 기본적으로 누적값을 보여주며, 위 예제 처럼 Format에 last를 추가해주면 마지막 수행했을 때의 일량















