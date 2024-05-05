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
