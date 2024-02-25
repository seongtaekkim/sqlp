# 02. AutoTrace



- SQL 수행 시 실제 일량 측정 및 튜닝하는데 유용한 정보들을 많이 포함하는 도구

```sql
set autotrace on
SP2-0618: 세션 식별자를 찾을 수 없습니다. PLUSTRACE 롤이 사용으로 설정되었는지 점검하십시오
SP2-0611: STATISTICS 레포트를 사용 가능시 오류가 생겼습니다

SQL> conn /as sysdba
연결되었습니다.

SQL> @?/sqlplus/admin/plustrce.sql


SQL> grant plustrace to scott;
권한이 부여되었습니다.

SQL> conn scott/tiger
연결되었습니다.

SQL> set autotrace on
SQL> select * from emp where empno=7900;

     EMPNO ENAME      JOB              MGR HIREDATE        SAL       COMM     DEPTNO
---------- ---------- --------- ---------- -------- ---------- ---------- ----------
      7900 JAMES      CLERK           7698 81/12/03        950                    30


Execution Plan
----------------------------------------------------------
Plan hash value: 2949544139

--------------------------------------------------------------------------------------
| Id  | Operation		    | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT	    |	     |	   1 |	  38 |	   1   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP    |	   1 |	  38 |	   1   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN	    | PK_EMP |	   1 |	     |	   0   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("EMPNO"=7900)


Statistics
----------------------------------------------------------
	  0  recursive calls
	  0  db block gets
	  2  consistent gets
	  0  physical reads
	  0  redo size
	970  bytes sent via SQL*Net to client
	 41  bytes received via SQL*Net from client
	  1  SQL*Net roundtrips to/from client
	  0  sorts (memory)
	  0  sorts (disk)
	  1  rows processed
	  
	  
SQL> set autot off
```



### AutoTrace 옵션

- 아래와 같은 옵션에 따라 필요한 부분만 출력해 볼 수 있음

|                                 | 실제수행여부 | 수행결과 | 실행계획 | 실행통계 |
| :------------------------------ | :----------- | :------- | :------- | :------- |
| (0) set autot off               | O            | O        |          |          |
| (1) set autotrace on            | O            | O        | O        | O        |
| (2) set autotrace on explain    | O            | O        | O        |          |
| (3) set autotrace on statistics | O            | O        |          | O        |
| (4) set autotrace traceonly     | O            |          | O        | O        |
| (5) set autotrace trace exp     |              |          | O        |          |
| (6) set autotrace trace stat    | O            |          |          | O        |

- (1)~(3)수행 결과를 출력 해야 하므로 쿼리를 실제 수행
- (4),(6)실행 통계를 보여줘야 하므로 쿼리를 실제 수행
- (5) 번은 실행 계획만 출력하면 되므로 실제 수행하지 않음



### AutoTrace 필요 권한

- (1) Autotrace 기능을 실행계획 확인 용도로 사용한다면 Plan_Table만 생성 되어 있으면 가능
- (2) 실행통계 까지 확인 하려면 v$sesstat, v$statname, v$mystat 뷰에 대한 읽기 권한이 필요
- (3) dba, select_catalog_role 등의 롤을 부여받지 않은 사용자의 경우 별도의 권한 설정이 필요
- (4) plustrace 롤을 생성하고 롤을 부여하는 것이 편리

```sql
@?/sqlplus/admin/plustrace.sql
grant plustrace to scott;
```



| 구분       | 내용                                                         |
| :--------- | :----------------------------------------------------------- |
| Role       | dba, select_catalog                                          |
| 일반사용자 | 실행계획: plan_table  실행통계: v$sesstat, v$statname, v$mystat |



### AutoTrace 수행 방식

##### (1) statistics 모드로 AutoTrace를 활성화 시키면 새로운 세션이 하나 열리면서 현재 세션의 통계정보를 대신 쿼리해서 보여주는 방식

- 쿼리 실행전 현재 세션의 수행통계 정보를 저장했다가 쿼리 실행 후 수행통계와의 델타(Delta) 값을 계산해 보여주는 방식
- 만약 같은 세션에서 수행한다면 세션 통계를 쿼리 할때 수행통계까지 뒤섞이기 때문에 별도의 세션을 사용하는 것임

```sql
@session
USERNAME   PROGRAM     STATUS
--------- ------------ -------
SCOTT     sqlplus.exe  ACTIVE
```



##### (2)현재 위처럼 한개 세션이 존재 하는 상황에서 statistics 옵션을 활성하 하면 새로운 세션이 추가 되었음을 확인 할 수 있음

```sql
@session

USERNAME   PROGRAM     STATUS
--------- ------------ -------
SCOTT     sqlplus.exe  ACTIVE
SCOTT     sqlplus.exe  ACTIVE
```



##### (3) explain 모드로 변경 했을 경우 새롭게 열렸던 세센이 사라짐

```sql
set autotrace on explain
@session

USERNAME   PROGRAM     STATUS
--------- ------------ -------
SCOTT     sqlplus.exe  ACTIVE
```





????? @session 가 어떻게 실행되는건지 모르겠음;;
