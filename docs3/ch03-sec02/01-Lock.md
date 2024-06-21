# 01. Lock



## 1) Lock



### 가. Lock이란?

- 같은 자원을 액세스하려는 다중 트랜잭션 환경에서 데이터베이스의 일관성과 무결성을 유지하기 위해 트랜잭션의 순차적 진행을보장할 수 있는 직렬화(Serialization) 장치&nbsp;



### 나. 공유 Lock과 배타적 Lock

###### 1) 공유 Lock

- 공유(Shared) Lock은 데이터를 읽고자 할 때 사용
- 다른 공유 Lock과는 호환되지만 배타적 lock과는 호환되지 않음



###### 2) 배타적 Lock

- 배타적(Exclusive) Lock은 데이터를 변경하고자 할 대 사용되며, 트랜잭션이 완료될 때까지 유지
- 해당 Lock이 해제될 때까지 다른 트랜잭션은 해당 Resource에 접근할 수 없음



### 다. 블로킹과 교착상태



###### 1) 블로킹

- Lock경합이 발생해 특정 세션이 작업을 진행하지 못하고 멈춰 선 상태
- 공유 Lock과 배타적 Lock은 함께 설정될 수 없으므로 Blocking 이 발생
- Blocking을 해소 할 수 있는 방법은 Commit(또는 Rollback) 뿐이다.
- Lock 경합이 발생하면 먼저 Lock이 완료될 때까지 후행 트랜잭션을 기다려야 한다
- Lock에 의한 성능 저하를 최소화 하는 방법
  - 트랜잭션의 원자성을 훼손하지 않는 선에서 트랜잭션을 가능한 짧게 정의
  - (Oracle은 데이터를 읽을 때 Shared Lock을 사용하지 않기 때문에 상대적으로 Lock 경합이 적음)
  - 같은 데이터를 갱신하는 트랜잭션이 동시에 수행되지 않도록 설계
  - 주간에 대용량 갱신 작업이 불가피하다면, 블로킹 현상에 의해 사용자가 무한정 기다리지 않도록 적절한&nbsp; 프로그램 기법을 도입



**Blocking을 무한정 기다리지 않는 방법**

- SQL Server
  set lock_timeout 2000

- Oracle
  SELECT * FROM T WHERE NO=1 FOR UPDATE NOWAIT \--> 대기없이 Exception을 던짐
  SELECT * FROM T WHERE NO=1 FOR UPDATE WAIT 3 \--> 3초 대기 후 Exception을 던짐



- 트랜잭션 격리성 수준(Isolation Level)를 불필요하게 상향 조정하지 않는다.
- SQL문장이 가장 빠른 시간 내에 처리를 완료하도록 하는 것이 Lock 튜닝의 기본이고 효과도 가장 좋다.



###### 2) 교착상태

- 두 세션이 각각 Lock을 설정한 리소스를 서로 액세스하려고 마주보며 진행하는 상황, 둘 중 하나가 뒤로 물러나지 않으면 영영 풀릴 수 없다.
  (Oracle의 경우 하나의 Transaction을 Rollback하고 Alert파일에 기록됨)
- 여러 테이블을 액세스하면서 발생하는 교착상태는 테이블 접근 순서를 같게 처리하여 회피 한다.
- SQL Server라면 갱신(Update) Lock을 사용함으로써 교착상태 발생 가능성을 줄일 수 있음



## 2) SQL Server Lock

### 가. Lock 종류



###### 1) 공유 Lock

- SQL Server의 공유 Lock은 트랜잭션이나 쿼리 수행이 완료될 때까지 유지되는 것이 아니라 다음 레코드가 읽히면 곧바로 해제 된다. (Isolation Level이 Read Committed일 경우만)
- Isolation Level을 변경하지 않고 트랜잭션 내에서 공유 Lock이 유 지되도록 하려면 테이블 힌트로 {*}holdlock을{*} 지정하면 된다.



```sql
begin tran

select 적립포인트, 방문횟수, 최근방문일시, 구매실적
 from 고객 with(holdlock)
where 고객번호 = :cust_num

-- 새로운 적립포인트 계사

update 고객 set 적립포인트 = :적립포인트 where 고객번호 = :cust_num

commit;
```

- 나중에 변경할 목적으로 레코드를 읽을 경우는 반드시 위와 같은 패턴으로 트랜잭션을 처리 해야 함.



###### 2) 배타적 Lock

- 데이터를 변경시 사용



###### 3) 갱신 Lock

- 위의 예제에서 만약 두 트랜잭션이 동시에 같은 고객에 대해서&nbsp; Update를 수행시 두 트랜잭션 모두 처음에는 공유 Lock을 설정했다가 적립포인트를 변경하기 직전에 배타적 Lock을 설정하려고 한다.
- 이럴 경우 두 트랜잭션은 상태편 트랜잭션에 의한 공유 Lock이 해제되기만을 기다리는 교착상태에 빠지 된다.
- 이런 잠재적인 교착상태를 방지하려고 SQL Server는 갱신(Update)Lock을 사용 할 수 있다.

```sql
begin tran

select 적립포인트, 방문횟수, 최근방문일시, 구매실적
 from 고객 with(updlock)
where 고객번호 = :cust_num

-- 새로운 적립포인트 계사

update 고객 set 적립포인트 = :적립포인트 where 고객번호 = :cust_num

commit;
```

- 한 자원에 대한 갱신 Lock은 한 트랜잭션만 설정할 수 있다



###### 4) 의도 Lock

- 특정 로우에 Lock을 설정하면 그와 동시에 상위 레벨 개체(페이지, 익스텐트, 테이블)에 내부적으로 의도(Intent) Lock이 설정된다.
- Lock을 설정하려는 개체의 하위 레벨에서 선행 트랜잭션이 어떤 작업을 수행 중인지를 알리는 용도로 사용되며, 일종의 푯말(Flag)라고 할 수 있다.
- 예를 들어, 구조를 변경하기 위해 테이블을 잠그려 할 때 그 하위의 모든 페이지나 익스텐트, 로우레 어떤 Lock이 설정돼 있는지 검사할 경우 오래 소요 될 수 있으므로 해당 테이블에 어떤 모드의 의도 Lock이 설정돼 있는지만 보고도 작업을 진행할지 아니면 기다릴지를 결정할 수 있다.



###### 5) 스키마 Lock

- Sch-S(Schema Stability) : SQL을 컴파일하면서 오브젝트 스키마를 참조할 때 발생하며, 읽는 스키마 정보가 수정되거나 삭제되지 못하도록 함
- Sch-M(Schema Modification) : 테이블 구조를 변경하는 DDL문을 수행할 때 발생하며, 수정 중인 싀마 정보를 다른 세션이 참조하지 못하도록 함



###### 6) Bulk Update Lock

- 테이블 Lock의 일종으로, 테이블에 데이터를 Bulk Copy할 때 발생한다.
- 병렬 데이터 로딩(Bulk Insert나 bcp 작업을 동시 수행)을 허용하지만 일반적인 트랜잭션 작업은 허용되지 않는다.



### 나. Lock 레벨과 Escalation



| Lock 레벨         | 설명                                                         |
| :---------------- | :----------------------------------------------------------- |
| 로우 레벨         | 변경하려는 로우(실제로는 RID)에만 Lock을 설정하는 것         |
| 페이지 레벨       | 변경하려는 로우가 담긴 데이터 페이지(또는 인덱스 페이지)에 Lock을 설정하는 것 같은 페이지에 속한 로우는 진행 중인 변경 작업과 무관하더라도 모두 잠긴것과 같은 효과가 나타남. |
| 익스텐트 레벨     | 익스텐트 전체가 잠김. SQL Server의 경우, 하나의 익스텐트가 여덟 개 페이지로 구성되므로 8개 페이지에 속한 모든 로우가 잠긴 것과 같은 효과가 나타남. |
| 테이블 레벨       | 테이블 전체 그리고 관련 인덱스까지 모두 잠김.                |
| 데이터베이스 레벨 | 데이터베이스 전체가 잠긴다. 보통 데이터베이스를 복구하거나 스키마를 변경할 때 일어 남. |

- 위 5가지 레벨 외에 인덱스 키(Key)에 로우 레벨 Lock을 거는 경우도 있음.
- Lock Escalation
  - 관리할 Lock 리소스가 정해진 임계치를 넘으면 로우 레벨 락이 \-> 페이지 \-> 익스텐트 \-> 테이블 레벨 락으로 점점 확장되는 것을 의미.
- SQL Server, DB2 UDB 처럼 한정된 메모리 상에서 Lock 매니저를 통해 lock 정보를 관리하는 DBMS에서 공통적으로 발생할 수 있는 현상
- Locking 레벨이 낮을 수록 동시성은 좋지만 관리해야 할 Lock 개수가 증가하기 대문에 더 많은 리소스를 소비.
  - Locking 레벨이 높을수록 적은 양의 Lock 리소스를 사용하지만 하나의 Lock으로 수많은 레코드를 한꺼번에 Locking하기 때문에 동시성은 나빠짐.



###### 다. Lock호환성

- '호환된다'는 말은 한 리소스에 두 개 이상의 Lock을 동시에 설정할 수 있음을 뜻함.

|                                   | IS   | S    | U    | IX      | SIX  | X    |
| :-------------------------------- | :--- | :--- | :--- | :------ | :--- | :--- |
| Intent Shared(IS)                 | O    | O    | O    | O       | O    |      |
| Shared(S)                         | O    | O    | O    |         |      |      |
| Updated(U)                        | O    | O    |      |         |      |      |
| Intent Exclusive(IX)              | O    |      |      | O&nbsp; |      |      |
| Shared with intent exclusive(SIX) | O    |      |      |         |      |      |
| Exclusive(X)                      |      |      |      |         |      |      |



- 스키마 Lock 호환성
  - Sch-S는 Sch-M을 제외한 모든 Lock과 호환
  - Sch-M은 어떤 Lock과도 호화된지않음



## 3) Oracle Lock

- Oraclde은 공유 리소스와 사용자 데이터를 보호할 목적으로 DML Lock, DDL Lock, 래치(Latch), 버퍼 Lock, 라이브러리 캐시 Lock/Pin등 다양한 종류의 Lock을 사용



### 가. 로우 Lock

- Oracle에서 로우 Lock은 항상 배타적이다.
- INSERT, UPDATE, DELETE 문이나 SELECT....FOR UPDATE 문을 수행한 트랜잭션에 의해 설정되면, 트랜잭션이 커밋 또는 롤백할 때까지
  다른 트랜잭션은 해당 로우는 변경할 수 없음
- Oracle에서 읽는 과정에서는 어떤 Lock도 설정하지 않음으로 읽기와 갱신 작업은 서로 방해 하지 않음
  - 읽으려는 데이터를 다른 트랜잭션이 갱신 중이더라도 기다리지 않음
  - 갱신하려는 데이터를 다른 트랜잭션이 읽는 중이더라도 기다리지 않음(SELECT...FOR UPDATE 구문은 제외)
  - 갱신하려는 데이터를 다른 트랜잭션이 갱신중이면 기다림
- oracle이 공유 Lock을 사용하지 않고도 일관성을 유지할 수 있는 것은 UNDO 데이터를 이용한 다중 버전 동시성 제어 매커니즘을 사용하기 때문.
- Oracle은 별도의 Lock 매니저 없이 레코드의 속성으로서 로우 Lock을 구현했기 때문에 아무리 많은 레코드를 갱신하더라도 절대 Lock Escalation은 발생하지 않음



### 나. 테이블 Lock

- 한 트랜잭션이 로우 Lock을 얻는 순간, 해당 테이블에 대한 테이블 Lock도 동시에 얻어 현재 트랜잭션이 갱신 중인 테이블에 대한 호환되지 않는
  DDL 오퍼레이션을 방지 한다.
- 테이블 Lock 종류
  - Row Share(RS)
  - Row Exclusive(RX)
  - Share(S)
  - Share row Exclusive(SRX)
  - Exclusive(X)
- SELECT...FOR UPDATE 문을 수행할 대 RS 모드 테이블 Lock을 얻고, insert, update, delete 문을 수행할 대 RX 모드 테이블 Lock을 얻음
- 일반적으로 DML 로우 Lock을 처음 얻는 순간 묵시적으로 테이블 Lock을 얻지만, 아래처럼 명령어를 이용해서도 가능

```sql
lock table emp in row share mode;

lock table emp in row esclusive mode;

lock table emp in share mode;

lock table emp in share row exclusive mode;

lock table emp in exclusive mode;
```

- '테이블 Lock'이라 하면, 테이블 전체에 Lock이 걸린다고 생각하기 쉬우나, Oracle의 테이블 Lock의 의미는, Lock을 획득한 선행 트랜잭션이 해당 테이블에서
  현재 어떤 작업을 수행중인지를 알리는 일종의 푯말(Flag)이다. 후행 트랜잭션은 어떤 테이블 Lock이 설정돼 있는지만 보고도그 테이블로의 진입 여부를 결정할수 있다.
- Oracle의 Lock 호환성

|      | NULL | RS   | RX   | S    | SRX  | X    |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| NULL | O    | O    | O    | O    | O    | O    |
| RS   | O    | O    | O    | O    | O    |      |
| RX   | O    | O    | O    |      |      |      |
| S    | O    | O    |      | O    |      |      |
| SRX  | O    | O    |      |      |      |      |
| X    | O    |      |      |      |      |      |
