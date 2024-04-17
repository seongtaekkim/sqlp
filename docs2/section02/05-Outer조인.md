# 05. Outer조인

- NL조인는 그 특성상 Outer 조인할 때 방향이 한쪽으로 고정되며, Outer 기호(+)가 붙지 않은 테이블이 항상 드라이빙 테이블로 선택한다.
- leading 힌트를 사용해서 순서를 바꿔 보려 해도 소용이 없다.

```sql
SELECT /*+ USE_NL( D E )  LEADING( E ) */  *
FROM SCOTT.DEPT D, SCOTT.EMP E
WHERE E.DEPTNO(+) = D.DEPTNO;

 ...
15 개의 행이 선택되었습니다.

@XPLAN


-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |록
|   0 | SELECT STATEMENT   |      |      1 |        |     15 |00:00:00.01 |      37 |
|   1 |  NESTED LOOPS OUTER|      |      1 |     14 |     15 |00:00:00.01 |      37 |
|   2 |   TABLE ACCESS FULL| DEPT |      1 |      4 |      4 |00:00:00.01 |       8 |
|*  3 |   TABLE ACCESS FULL| EMP  |      4 |      4 |     14 |00:00:00.01 |      29 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("E"."DEPTNO"="D"."DEPTNO")
```





![스크린샷 2024-04-17 오전 9.34.35](../../img/135.png)



- 그림 2-27에서는 사원이 전형 없는 유령 부서가 등록될 수 있다.( null )
- 따라서 사원 유무와 상관업이 모든 부서가 출력되도록 하려면 사원 쪽 모든 조건절에 Outer 기호(+)를 반드시 붙여 줘야 한다.

```sql
DESC SCOTT.EMP;
 이름                                                                                                      널?      유형
 ----------------------------------------------------------------------------------------------------------------- -------- -----

 EMPNO                                                                                                     NOT NULL NUMBER(4)
 ENAME                                                                                                              VARCHAR2(10)
 JOB                                                                                                                VARCHAR2(9)
 MGR                                                                                                                NUMBER(4)
 HIREDATE                                                                                                           DATE
 SAL                                                                                                                NUMBER(7,2)
 COMM                                                                                                               NUMBER(7,2)
 DEPTNO                                                                                                             NUMBER(2)

SELECT * FROM SCOTT.EMP ORDER BY EMPNO ASC;

     EMPNO ENAME      JOB              MGR HIREDATE        SAL       COMM     DEPTNO
---------- ---------- --------- ---------- -------- ---------- ---------- ----------
      7369 SMITH      CLERK           7902 80/12/17        800                    20
      7499 ALLEN      SALESMAN        7698 81/02/20       1600        300         30
      7521 WARD       SALESMAN        7698 81/02/22       1250        500         30
      7566 JONES      MANAGER         7839 81/04/02       2975                    20
      7654 MARTIN     SALESMAN        7698 81/09/28       1250       1400         30
      7698 BLAKE      MANAGER         7839 81/05/01       2850                    30
      7782 CLARK      MANAGER         7839 81/06/09       2450                    10
      7788 SCOTT      ANALYST         7566 87/04/19       3000                    20
      7839 KING       PRESIDENT            81/11/17       5000                    10
      7844 TURNER     SALESMAN        7698 81/09/08       1500          0         30
      7876 ADAMS      CLERK           7788 87/05/23       1100                    20

     EMPNO ENAME      JOB              MGR HIREDATE        SAL       COMM     DEPTNO
---------- ---------- --------- ---------- -------- ---------- ---------- ----------
      7900 JAMES      CLERK           7698 81/12/03        950                    30
      7902 FORD       ANALYST         7566 81/12/03       3000                    20
      7934 MILLER     CLERK           7782 82/01/23       1300                    10



INSERT INTO SCOTT.EMP VALUES( '7935', 'MILLER', 'CLERK', '7782', '82/01/23', '1300', NULL, NULL );

1 개의 행이 만들어졌습니다.

COMMIT;

커밋이 완료되었습니다.

SELECT * FROM SCOTT.EMP ORDER BY EMPNO ASC;

     EMPNO ENAME      JOB              MGR HIREDATE        SAL       COMM     DEPTNO
---------- ---------- --------- ---------- -------- ---------- ---------- ----------
      7369 SMITH      CLERK           7902 80/12/17        800                    20
      7499 ALLEN      SALESMAN        7698 81/02/20       1600        300         30
      7521 WARD       SALESMAN        7698 81/02/22       1250        500         30
      7566 JONES      MANAGER         7839 81/04/02       2975                    20
      7654 MARTIN     SALESMAN        7698 81/09/28       1250       1400         30
      7698 BLAKE      MANAGER         7839 81/05/01       2850                    30
      7782 CLARK      MANAGER         7839 81/06/09       2450                    10
      7788 SCOTT      ANALYST         7566 87/04/19       3000                    20
      7839 KING       PRESIDENT            81/11/17       5000                    10
      7844 TURNER     SALESMAN        7698 81/09/08       1500          0         30
      7876 ADAMS      CLERK           7788 87/05/23       1100                    20

     EMPNO ENAME      JOB              MGR HIREDATE        SAL       COMM     DEPTNO
---------- ---------- --------- ---------- -------- ---------- ---------- ----------
      7900 JAMES      CLERK           7698 81/12/03        950                    30
      7902 FORD       ANALYST         7566 81/12/03       3000                    20
      7934 MILLER     CLERK           7782 82/01/23       1300                    10
      7935 MILLER     CLERK           7782 82/01/23       1300                         <== 이게 바로 유령부서임 ;;

15 개의 행이 선택되었습니다.

SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE  FROM DBA_CONSTRAINTS
WHERE OWNER = 'SCOTT';

TABLE_NAME                     CONSTRAINT_NAME                C
------------------------------ ------------------------------ -
EMP                            FK_DEPTNO                      R
DEPT                           PK_DEPT                        P
EMP                            PK_EMP                         P
```



![스크린샷 2024-04-17 오전 9.35.05](../../img/136.png)

- 사원이 없는 부서는 등록 될수 없다. ( 식별자 )

- 따라서 모든 부서가 출력되도록 하려겨고 굳이 Outer 조인할 필요가 없음에도 Outer 기호(+)를 붙인다면 성능이 나빠질 수 있다.



### ERD 표기를 따르는 SQL 개발의 중요성 결론

- 위 예제 모두 사원 쪽 부서번호가 필수컬럼이다.

- 소속 부서없이는 사원이 존재할 수 없다는 뜻이므로 테이블을 생성할 때 Not Null 제약을 두어야 한다.