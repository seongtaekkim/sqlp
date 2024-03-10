# 10. DynamicSQL사용기준



##### Static SQL 사용을 기본 원칙으로 하자.

1. PreCompile시 안정적인 빌드가 가능하다.
2. Dynamic SQL 어플리케이션 커서 캐싱 기능을 정상적으로 사용 하지 못하므로 성능이 나빠짐





## 1) Dynamic SQL 사용에 관한 기본 원칙( + 예외)



1. PreCompile 과정에서 에러가 발생하는 구문을 사용 하는 경우(ex) 스칼라, 분석함수, 서브쿼리, ANSI조인등..)

2. Static SQL로 작성시 SQL 개수가 많아져 개발에 관한 생산성의 저하로 유지 보수 비용이 많아지는 경우

3. 위의 2에 한해서 Dynamic SQL을 사용 하더라도 조건 절에는 바인드 변수를 사용 (사용 빈도가 높고 값을 종류가 많은 경우)

4. 바인드 변수 사용 원칙을 준수 하되 예외적인 경우

   - Long Running 쿼리 및 쿼리의 파싱 소요 시간, 쿼리 총 소요 시간에서 차지 하는 비중이 매우 낮고 수행 빈도가 낮아 하드 파싱에 의한 라이브러리 캐시 부하가 적은 경우
     - ex> 배치 프로그램 , 마감 프로그램, DW, OLAP

   - OLTP성의 프로그램이라 하더라도 사용 빈도가 낮아 하드 파싱에 의한 라이브러리 캐시 부하를 주지 않는 경우

   - 조건절에 대한 컬럼 값 종류가 적은 경우(소수 일경우): 데이터의 분포가 균일 하지 않아 옵티마이저의 히스토그램 정보를 활용하도록 유도할 경우



- Static SQL이 지원 하지 않는 환경 이라면 모든 SQL은 Dynamic SQL이지만 런타임시 동적으로 SQL이 바뀌는 것을 삼가 해야 한다.
- 그런 환경에서 Static과 Dynamic SQL을 편의상 Repository에 재 정의하고, 위에서 제시한 기본 원칠을 동일하게 적용할 것 을 권고한다.
- Static SQL : Repository에서 완성된 형태로 관리
- Dynamic SQL : Repository에서 불완전한 상태로 관리 되며, 런타임시 필요에 따라 동적으로 조건을 넣어 쿼리를 생성이 가능







## 2) 기본 원칙이 잘 지켜지지 않는 첫 번째 이유, 선택적 검색 조건

- 현업과의 충분한 협의를 통하지 하지 않고 다양한 검색 조건으로 화면을 설계 하여 사용자에 따라 검색조건이 동적으로 바뀌는 경우

- (대량의 데이터 일 경우 문제가 발생될 우려가 있음: 동적으로 쿼리가 바뀌며 라이브러 캐쉬를 제대로 활용 하지 못하게 되며, 심지어는 필수 입력과 검색기간이 무제한으로 인해 검색 성능에 제약을 가져오게 만듬)

  => 해결 방안 : 검색 조건을 단순화 하여 라이브러리 캐시를 최대한 활용 할 수 있도록 유도(반복 사용을 유도함)



##### 사례 1) 조건을 추가 함에 따라 실행계획이 바뀌며, 라이브러리의 캐시에는 별도를 쿼리로 인식 하여 하드 파싱이 번번히 일어 나는 경우

```sql
SELECT EMPNO
     ,ENAME
     ,JOB
FROM   EMP
WHERE HIREDATE BETWEEN :START_DATE AND :END_DATE
%WHERE_SENTENCE%

 필요 선택 조건에 따라 쿼리 조건절이 동적으로 추가됨
 %WHERE_SENTENCE% = "AND DEPTNO='10' ";

 SELECT EMPNO
       ,ENAME
       ,JOB
 FROM   EMP
 WHERE HIREDATE BETWEEN :START_DATE AND :END_DATE
 AND DEPTNO='10'
```



##### 사례 2) 같은 실행 계획을 공유하여 라이브러리 캐쉬를 재사용

-  날짜에 제한이 없이 없거나, 데이터의 분포가 적절하지 않으면 인덱스를 못탈 우려가 발생 할수 있음
  - Null이면 filter한다.

```sql
 SELECT EMPNO
       ,ENAME
       ,JOB
 FROM   EMP
 WHERE HIREDATE BETWEEN START_DATE AND END_DATE
 AND DEPTNO= NVL(:부서코드, DEPNO)
 AND ENAME = NVL(:이름, ENAME)
```



##### 사례 3) 검색 조건이 여러개일 경우(DEPTNO, EMPNO 에 인덱스가 있다는 가정)

- SQL마다 최적의 인덱스 구성전략을 고민 하면서 개발 하는데 어려움이 있다. (조건에 따른 쿼리 개수가 너무 많은 경우)
- 아래 UnionAll 이 고민을 어느정도 해소시켜준다. (혹은 IF분기처리도 활용 가능)

```sql
 SELECT EMPNO
       ,ENAME
       ,JOB
 FROM   EMP
 WHERE HIREDATE BETWEEN START_DATE AND END_DATE
 AND DEPTNO= :DEPTNO
 UNION ALL
 SELECT EMPNO
       ,ENAME
       ,JOB
 FROM   EMP
 WHERE HIREDATE BETWEEN START_DATE AND END_DATE
 AND EMPNO= :EMPNO
 
```



## 3) 선택적 검색 조건에 대한 현실적인 대안

1. Static SQL사용을 윈칙으로함
2. 조건에 따른 SQL 생성 개수가 많은 경우 Dynamic SQL을 사용(일부에 대해서만 사용되서 하드 파싱에 대한 부하가 없음)
3. Dynamic SQL은 바인드 변수 사용을 원칙적으로 준수 해야함.(단 인덱스를 설계시 불편한 단점이 있다)



##### if 조건을 이용한 Dynamic 쿼리 예제

```sql
SQLStmt := 'SELECT ENAME, JOB, SAL, COMM '
       || 'FROM 일별종목거래 '
        || 'WHERE 거래일자 BETWEEN :1 AND :2 ';
IF :EMPNO IS NULL Then
SQLStmt := SQLStmt || 'AND :EMPNO IS NULL ';
Else
SQLStmt := SQLStmt || 'AND EMPNO = :EMPNO ';
End If;

If :DEPTNO IS NULL Then
  SQLStmt := SQLStmt || 'AND :DEPTNO IS NULL ';
Else
SQLStmt := SQLStmt || 'AND DEPTNO =:DEPTNO ';
End If;

EXECUTE IMMEDIATE SQLStmt
INTO :A, :B, :C, :D, :E, :F, :G
USING :시작일자, :종료일자, :종목코드, :투자자유형코드;
```



Static SQL을 작성을 기본으로 하고 방법이 없거나 SQL이 복잡한 경우에는 Dynamic SQL을 사용 하도록 한다.







## 4) 선택적 검색 조건에 사용 할 수 있는 기법 성능 비교

```sql
CREATE INDEX EMP_ENAME_IDX ON EMP(ENAME);
SET AUTOTRACE ON;
```



##### A. OR 조건을 사용 하는 경우

```sql
1) NULL을 사용하지 않는 경우
VARIABLE ename varchar2(20);
exec :ename :='SMITH'
SELECT * FROM EMP WHERE (:ename IS NULL OR ename = :ename);

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     1 |    87 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| EMP  |     1 |    87 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------


2) NULL을 사용한 경우
exec :ename :=NULL
SELECT * FROM EMP WHERE (:ename IS NULL OR ename = :ename);

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     1 |    87 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| EMP  |     1 |    87 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------
```

- 항상 TABLE FULL SCAN으로 처리가되므로 인덱스를 활용 할 경우는 이 방식을 사용해서는 안된다.



##### B. LIKE 연산자를 사용한 경우

- 2번과 3번은 분명 TABLE FULL SCAN임에도 불구하고 비정상적으로 인덱스를 타고 있어 성능에 문제가 발생될 우려가 있다.

```sql
VARIABLE ename varchar2(20);
exec :ename :='SMITH'
SELECT * FROM EMP WHERE ENAME LIKE :ename||'%';

---------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |     2 |    74 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP           |     2 |    74 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | EMP_ENAME_IDX |     2 |       |     1   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("ENAME" LIKE :ENAME||'%')
       filter("ENAME" LIKE :ENAME||'%')

2)NULL을 사용한 경우
VARIABLE ename varchar2(20);
exec :ename :=NULL
SELECT * FROM EMP WHERE ENAME LIKE :ename||'%';

---------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |     2 |    74 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP           |     2 |    74 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | EMP_ENAME_IDX |     2 |       |     1   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("ENAME" LIKE :ENAME||'%')
       filter("ENAME" LIKE :ENAME||'%')

3) ''을 사용 한경우
VARIABLE ename varchar2(20);
exec :ename :=''
SELECT * FROM EMP WHERE ENAME LIKE :ename||'%';

---------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |     2 |    74 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP           |     2 |    74 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | EMP_ENAME_IDX |     2 |       |     1   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("ENAME" LIKE :ENAME||'%')
       filter("ENAME" LIKE :ENAME||'%')
```



##### C NVL함수를 사용한 경우

```sql
1) 값이 있는 경우
VARIABLE ename varchar2(20);
exec :ename :='SMITH'

SELECT * FROM EMP WHERE ENAME = NVL(:ename, ENAME);

-----------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |    15 |   555 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION                |               |       |       |            |          |
|*  2 |   FILTER                      |               |       |       |            |          |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP           |    14 |   518 |     2   (0)| 00:00:01 |
|*  4 |     INDEX FULL SCAN           | EMP_ENAME_IDX |    14 |       |     1   (0)| 00:00:01 |
|*  5 |   FILTER                      |               |       |       |            |          |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  7 |     INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   4 - filter("ENAME" IS NOT NULL)
   5 - filter(:ENAME IS NOT NULL)
   7 - access("ENAME"=:ENAME)


2)NULL 값인 경우
VARIABLE ename varchar2(20);
exec :ename :=NULL
SELECT * FROM EMP WHERE ENAME = NVL(:ename, ENAME);

-----------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |    15 |   555 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION                |               |       |       |            |          |
|*  2 |   FILTER                      |               |       |       |            |          |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP           |    14 |   518 |     2   (0)| 00:00:01 |
|*  4 |     INDEX FULL SCAN           | EMP_ENAME_IDX |    14 |       |     1   (0)| 00:00:01 |
|*  5 |   FILTER                      |               |       |       |            |          |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  7 |     INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   4 - filter("ENAME" IS NOT NULL)
   5 - filter(:ENAME IS NOT NULL)
   7 - access("ENAME"=:ENAME)
```



##### D. DECODE를 사용한경우

```sql
1) 값이 있는 경우
VARIABLE ename varchar2(20);
exec :ename :='SMITH'
SELECT * FROM EMP WHERE ENAME = DECODE(:ename, NULL, ENAME, :ename);

-----------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |    15 |   555 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION                |               |       |       |            |          |
|*  2 |   FILTER                      |               |       |       |            |          |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP           |    14 |   518 |     2   (0)| 00:00:01 |
|*  4 |     INDEX FULL SCAN           | EMP_ENAME_IDX |    14 |       |     1   (0)| 00:00:01 |
|*  5 |   FILTER                      |               |       |       |            |          |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  7 |     INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   4 - filter("ENAME" IS NOT NULL)
   5 - filter(:ENAME IS NOT NULL)
   7 - access("ENAME"=:ENAME)

2) 값이 NULL 인 경우
VARIABLE ename varchar2(20);
exec :ename :=NULL
SELECT * FROM EMP WHERE ENAME = DECODE(:ename, NULL, ENAME, :ename);

-----------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |    15 |   555 |     4   (0)| 00:00:01 |
|   1 |  CONCATENATION                |               |       |       |            |          |
|*  2 |   FILTER                      |               |       |       |            |          |
|   3 |    TABLE ACCESS BY INDEX ROWID| EMP           |    14 |   518 |     2   (0)| 00:00:01 |
|*  4 |     INDEX FULL SCAN           | EMP_ENAME_IDX |    14 |       |     1   (0)| 00:00:01 |
|*  5 |   FILTER                      |               |       |       |            |          |
|   6 |    TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  7 |     INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   4 - filter("ENAME" IS NOT NULL)
   5 - filter(:ENAME IS NOT NULL)
   7 - access("ENAME"=:ENAME)
```

- 바인드 변수의 입력 여부에 따라 TABLE의 FULL SCAN 혹은 INDEX SCAN으로 실행 계획이 자동 분기가 된다.
- 단 NVL, DECODE 함수를 사용 할 경우는 해당 컬럼이 반드시 NOT NULL이어야 하며, NULL이 허용 되면 결과의 집합이 달라지므로 주의가 필요하다.(DBMS 마다 NULL 값 끼리의 비교가 될수 있기 때문이다)
- ENAME NOT NULL 혹은 NULL로 테스트한 결과 동일한 실행 결과를 보여주고 있다.



##### E. UNION ALL을 사용한 경우

```sql
VARIABLE ename varchar2(20);
exec :ename :='SMITH'

SELECT * FROM EMP WHERE :ename IS NULL
UNION ALL
SELECT * FROM EMP WHERE ENAME = :ename


----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |               |    15 |   555 |     5  (40)| 00:00:01 |
|   1 |  UNION-ALL                   |               |       |       |            |          |
|*  2 |   FILTER                     |               |       |       |            |          |
|   3 |    TABLE ACCESS FULL         | EMP           |    14 |   518 |     3   (0)| 00:00:01 |
|   4 |   TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   5 - access("ENAME"=:ENAME)

VARIABLE ename varchar2(20);
exec :ename := NULL
SELECT * FROM EMP WHERE :ename IS NULL
UNION ALL
SELECT * FROM EMP WHERE ENAME = :ename


----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |               |    15 |   555 |     5  (40)| 00:00:01 |
|   1 |  UNION-ALL                   |               |       |       |            |          |
|*  2 |   FILTER                     |               |       |       |            |          |
|   3 |    TABLE ACCESS FULL         | EMP           |    14 |   518 |     3   (0)| 00:00:01 |
|   4 |   TABLE ACCESS BY INDEX ROWID| EMP           |     1 |    37 |     2   (0)| 00:00:01 |
|*  5 |    INDEX RANGE SCAN          | EMP_ENAME_IDX |     1 |       |     1   (0)| 00:00:01 |
----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(:ENAME IS NULL)
   5 - access("ENAME"=:ENAME)
```



##### 위 5가지 방식의 선택 기준

1. NOT NULL 일경우는 NVL, DECODE를 사용 하는 것이 좋다. (단 위의 실행 계획을 보면 INDEX를 설정 할 경우, 범위스캔이 들어가므로 TABLE FULL SCAN보다 느려질 수 있다)
2. NULL 값을 허용 하고 있는 검색 조건이라면 UNION ALL를 사용 하여 명시적으로 분기해야 한다.
3. 인덱스 엑세스 조건으로 참여 하지 않는 경우, 즉 인덱스 필터 또는 테이블 필터 조건으로만 사용 되는 컬럼이라면 A와 B 방식중 어떤 방식을 사용 해도 무방하다.
