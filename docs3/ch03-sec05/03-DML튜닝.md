# 03. DML 튜닝



##  1) 인덱스 유지 비용

- 테이블 데이터 변경 -> 관련 인덱스 변경 발생
- 변경할 인덱스 레코드를 찾아가는 비용 + Redo, Undo를 생성하는 비용
- Update 수행시, 테이블 레코드는 직접 변경하지만 인덱스 레코드는 정렬 상태를 유지하기 위해
  - Delete & Insert 방식으로 처리됨. Undo 레코드도 2개씩 기록됨.
  - 따라서 변경 컬럼과 관련된 인덱스 개수에 따라 Update 성능이 좌우됨.
- Insert나 Delete 문일 때는 인덱스 모두에 변경을 가하므로 총 인덱스 개수에 따라 성능이 크게 달라짐.
- 인덱스 개수가 DML 성능에 큰 영향을 미치므로 대량의 데이터를 입력/수정/삭제할 때는 인덱스를 모두 Drop하거나 Unusable 상태로 변경한 다음 작업하는 것이 빠를 수 있음.



## 2) Insert 튜닝

#### 가. Oracle Insert 튜닝



###### Direct Path Insert

- 일반적인 힙 구조 테이블에서의 데이터 입력 방법
- 데이터 입력시 빈 공간을 가진 블록리스트를 관리하는 Freelist로 부터 블록을 할당받아 무작위로 값을 입력.
- Freelist에서 할당받은 블록을 버퍼 캐시에서 찾아보고, 없으면 데이터 파일에서 읽어 캐시에 적재한 후 데이터를 삽입.

- 대량의 데이터 입력시 위 방식은 비효율적임.
- Direct Path Insert : Freelist를 거치지 않고 HWM 바깥 영역에, 버퍼 캐시를 거치지 않고
  데이터 파일에 곧바로 입력하는 방식.
  Undo 데이터를 쌓지 않음.(사용자가 커밋할 때만 HWM 상향 조정하면 됨)

- Direct Path Insert 방식으로 데이터를 입력하는 방법
  - insert select 문장에 /*+ append */ 힌트 사용
  - 병렬 모드로 insert
  - direct 옵션을 지정하고 SQL*Loader(sqlldr)로 데이터를 로드
  - CTAS(create table ... as select) 문장을 수행



###### nologging 모드 Insert

- 테이블 속성을 nologging으로 바꿔주면 Redo 로그까지 최소화(데이터 딕셔너리 변경사항만 로깅)되므로 더 빠르게 insert 할 수 있음.
- Direct Path Insert 일 때만 작동.

- 주의) Direct Path Insert 방식으로 데이터 입력시 Exclusive 모드 테이블 Lock이 걸리므로,
  - 작업이 수행되는 동안 해당 테이블에 DML 수행 불가.
  - nologging 상태에서 입력한 데이터는 장애 발생시 복구 불가.
    **그러므로 insert 후 바로 백업 실시 or 언제든 재생 가능한 데이터를 insert할 때만 사용해야 함.



```sql
alter table t NOLOGGING;
```



#### 나. SQL Server Insert 튜닝



###### 최소 로깅(minimal nologging)

- 최소 로깅 기능을 사용하려면, 데이터베이스의 복구 모델(Recovery model)이 'Bulk-logged' 또는 'Simple'로 설정돼 있어야 함.

```
alter database SQLPRO set recovery SIMPLE
```



1) 파일 데이터를 읽어 DB로 로딩하는 Bulk Insert 구문을 사용할 때, With 옵션에 TABLOCK 힌트를 추가.

```sql
BULK INSERT Adventure Works.Sales.SalesOrderDetail
    FROM 'C:\orders\lineitem.txt'
    WITH
    (
        DATAFILETYPE = 'CHAR',
        FIELDTERMINATOR = ' |',
        ROWTERMINATOR = ' |\n',
        TABLOCK
    )
```



2) 복구 모델이 'Bulk-logged' 또는 'Simple'로 설정된 상태에서 select into 사용.

```sql
select * into target from source;
```



3) SQL Server 2008 버전부터 힙(Heap) 테이블에 Insert할 때 TABLOCK 힌트를 사용.

이때, X 테이블 Lock 때문에 여러 트랜잭션이 동시에 Insert 할 수 없게 됨.

```sql
insert into t_heap with (TABLOCK) select * from t_source
```

- B*Tree 구조 테이블(클러스터형 인덱스)에 Insert할 때도 최소 로깅 가능.
- 전제 조건은 소스 데이터를 목표 테이블 정렬(클러스터형 인덱스 정렬 키) 순으로 정렬해야 한다는 점.

- 필요한 다른 조건
  - 비어있는 B*Tree 구조에서 TABLOCK 힌트 사용
  - 비어있는 B*Tree 구조에서 TF-610을 활성화
  - 비어 있지 않은 B*Tree 구조에서 TF-610을 활성화하고, 새로운 키 범위만 입력



- TABLOCK 힌트가 반드시 필요하지 않으므로 입력하는 값 범위가 중복되지 않는다면 동시 Insert도 가능함.

```sql
use SQLPRO
go

alter database SQLPRO set recovery SIMPLE
DBCC TRACEON(610);

insert into t_idx
select * from t_source
order by col1  ------------ t_idx 테이블의 클러스터형 인덱스 키 순 정렬
```



## 3) Update 튜닝

#### 가. Truncate & Insert 방식 사용

- 대량의 데이터 변경시 오랜 시간이 걸릴 수 있음.

- 테이블 데이터 갱신 작업
- 인덱스 데이터 갱신
- 버퍼 캐시에 없는 블록인 경우 디스크에서 읽어 버퍼 캐시에 적재 후 갱신
- Redo, Undo 정보 생성
- 블록에 빈 공간 없으면 새 블록 할당(Row Migration 발생)



- Update문을 이용하는 것보다 아래 방식으로 처리하는 것이 더 빠를 수 있음.
  - 1. 대상테이블의 데이터로 temp 테이블 생성
  - 2. 대상테이블의 제약조건 및 인덱스 삭제
  - 3. 대상테이블 truncate
  - 4. temp 테이블에 있는 원본 데이터를 update 할 값으로 수정하여 대상테이블에 insert
  - 5. 대상테이블에 제약조건 및 인덱스 생성



#### 나. 조인을 내포한 Update 튜닝

- 조인을 내포한 Update 문 수행시 Update 자체 성능보다 조인 과정에서 발생하는 비효율 때문에 성능이 느려지는 경우가 더 많음.



###### 전통적인 방식의 Update문

```sql
update 고객
set   (최종거래일시, 최근거래금액) = (select max(거래일시), sum(거래금액)
                                      from   거래
                                      where  고객번호 = 고객.고객번호
                                      and    거래일시 >= trunc(add_months(sysdate, -1)))
where  exists (select 'x'
               from   거래
               where  고개번호 = 고객.고객번호
               and    거래일시 >= trunc(add_months(sysdate, -1))
               );
```

- 거래 테이블에 [고객번호 + 거래일시] 인덱스가 있어야 됨.
- Random 액세스 방식으로 조인을 수행하므로 쿼리가 빠르게 수행될 수 없음.
- 서브쿼리에 unnest, hash_sj 힌트 사용해서 해시 세미 조인 방식으로 유도하는 것이 효과적임.
- 거래 테이블 2번 액세스하는 비효율 있음.



###### Oracle 수정 가능 조인 뷰 활용

```sql
update /*+ bypass_ujvc */
      (select c.최종거래일시
            , c.최근거래금액
            , t.거래일시
            , t.거래금액
       from  (select 고객번호, max(거래일시) 거래일시, sum(거래금액) 거래금액
              from   거래
              where  거래일시 >= trunc(add_months(sysdate, -1))
              group by 고개번호) t
            , 고객 c
       where  c.고객번호 = t.고객번호)
set    최종거래일시 = 거래일시
     , 최근거래금액 = 거래금액
```

- 조인 뷰 : from절에 두 개 이상 테이블을 가진 뷰
- 조인 뷰를 통해 원본 테이블에 입력, 수정, 삭제가 가능함.
- 제약사항 : 키-보존 테이블에만 허용됨.



- 키-보존 테이블(Key-Preserved Table)
  - 조인된 결과집합을 통해서도 중복 없이 Unique하게 식별이 가능한 테이블



| 1 : M = M     | M쪽 테이블이 키-보존 테이블 |
| ------------- | --------------------------- |
| 1 : 1 = 1     | 1쪽 테이블이 키-보존 테이블 |
| M : N = M * N | 키-보존 테이블 없음         |
| M : 1 = M     | M쪽 테이블이 키-보존 테이블 |

- 고객(1) : 거래(M) 테이블. 고객 테이블을 업데이트 해야 되므로 고객 테이블이 키-보존 테이블이어야 됨.
- 1 : 1 관계가 되어야지만 고객 테이블이 키-보존 테이블이 될 수 있음.
- 거래 테이블이 고객번호로 group by 되어서 실제로는 1 : 1 관계가 되었지만,
- Oracle은 고객 테이블을 키-보존 테이블로 인정하지 않으므로 업데이트 할 수 없음.
- bypass_ujvc(Bypass Updatable Join View Check) 힌트로 이를 피해갈 수 있음.

```sql
drop table t1;

create table t1(c1 number, c2 varchar2(1));

insert into t1
select rownum
     , 'x'
from   dual
connect by level <= 10
;

create unique index idx1_t1 on t1(c1);

-- t1 테이블의 자식 테이블인 t2 생성
drop table t2;

create table t2(c1 number, c2 number, c3 varchar2(1));

insert into t2
select mod(rownum,10) + 1
     , rownum
     , 'x'
from   dual
connect by level <= 100
;

create unique index idx1_t2 on t2(c1, c2);

-- t1 컬럼 수정 => 키보존 테이블이 아니므로 수정 불가
update (select t1.c1, t1.c2, t2.c3
          from   t1
               , t2
          where  t1.c1 = t2.c1
          )
  set     c2 = 'A'
  ;
set     c2 = 'A'
        *
6행에 오류:
ORA-01779: 키-보존된것이 아닌 테이블로 대응한 열을 수정할 수 없습니다

-- t2 컬럼 수정 => 키보존 테이블이므로 수정 가능
update (select t1.c1, t1.c2, t2.c3
          from   t1
               , t2
          where  t1.c1 = t2.c1
          )
  set     c3 = 'A'
  ;

100 행이 갱신되었습니다.


-- t1 테이블 인덱스를 제거해서 M : N 관계로 만든 후 t2 컬럼 수정 => 수정 불가
drop index idx1_t1;

인덱스가 삭제되었습니다.

경   과: 00:00:00.00

update (select t1.c1, t1.c2, t2.c3
          from   t1
               , t2
          where  t1.c1 = t2.c1
          )
  set     c3 = 'A'
  ;
set     c3 = 'A'
        *
6행에 오류:
ORA-01779: 키-보존된것이 아닌 테이블로 대응한 열을 수정할 수 없습니다
```



###### Oracle Merge문 활용

- merge 문
  - insert, update, delete 작업을 한번에 처리 가능.
  - 9i 부터 제공.
  - 10g 부터 delete 작업, update/insert 선택적 처리 가능.



```sql
-- Updatable Join View 기능을 대체
merge into 고객 c
using (select 고객번호
            , max(거래일시) 거래일시
            , sum(거래금액) 거래금액
       from   거래
       where  거래일시 >= trunc(add_months(sysdate, -1))
       group by 고객번호) t
on    (c.고객번호 = t.고객번호)
when matched then update set c.최종거래일시 = t.거래일시
                           , c.최근거래금액 = t.거래금액
```
