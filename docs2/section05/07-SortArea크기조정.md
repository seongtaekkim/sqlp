# 07. SortArea크기조정

- 세션 레벨 혹은 시스템 레벨에서 각 세션에 할달될 수 있는 총 크기 조정 가능
  - 크기 조정 1차 목표 : 디스크 소트가 발생하지 않게 함
  - 크기 조정 2차 목표 : onepass 소트 처리



## 1) PGA 메모리 관리 방식의 선택

#### About Work Area

- 데이터 정렬, 해시 조인, 비트맵 머지, 비트맵 생성 등을 위해 사용되는 메모리 공간
- `sort_area_size`, `hash_area_size`, `bitmap_merge_area_size`, `create_bitmap_area_size` 파라미터를 통해 조정
- 9i부터 "Automatic PGA Memory Management" 기능 도입으로 사용자가 일일이 그 크기 조정 하지 않아도 됨

- `pga_aggregate_target` 파라미터를 통해 인스턴스 전체적으로 이용가능한 PGA 메모리 총량을 지정
  - 오라클이 시스템 부하 정도에 따라 자동으로 각 세션에 메모리 할당
  - 이 파라미터의 설정 값은 인스턴스 기동 중에 자유롭게 늘리거나 줄일 수 있음
  - 이 기능을 활성화하려면 "workarea_size_policy=auto"로 해야 함

- 9i부터 default `"workarea_size_policy=auto" : *_area_size` 파라미터는 모두 무시되며 오라클이 내부적으로 계산한 값 사용

- 수동 PGA 메모리 관리 : 주로 트랜잭션이 거의 없는 야간에 대량의 배치 job 수행 시 효과적
  - 해당 경우에 `"workarea_size_policy=auto"`로 사용하면 프로세스 당 사용할 수 있는 최대 크기제한되므로 work area를 사용 중인 다른 프로세스가 없더라도 특정 프로세스가 모든 공간을 다 쓸 수 없게 되고, 결국 수 GB의 여유 메모리가 있어도 충분히 메모리를 활용하지 못해 작업 시간이 오래 걸릴 수 있음
  - `"workarea_size_policy=manual"`로 변경







## 2) 자동 PGA 메모리 관리 방식 하에서 크기 결정 공식



#### workarea_size_policy = auto 모드에서 WORK AREA 크기

- 단일 프로세스가 사용할 수 있는 최대 work area 크기는 인스턴스 기동 시 오라클에 의해 내부적으로 결정
- `_smm_max_size` 파라미터 통해 확인 가능(value 단위 : KB)



#### Work Area 크기 조회

```sql
SELECT a.ksppinm name
     , b.ksppstvl VALUE
  FROM sys.x$ksppi  a
     , sys.x$ksppcv b
 WHERE a.indx = b.indx
   AND a.ksppinm = '_smm_max_size'
;

      NAME            VALUE(KB)
-------------- --------------------
_smm_max_size        15974
```

#### 이 파라미터의 값을 결정하는 내부 계산식

- 9i ~ 10gR1
  - _smm_max_size=least((pga_aggregate_target * 0.05), (_pga_max_size * 0.5))
  - DB관리자가 지정한 pga_aggrate_target의 5%와 _pga_max_size 파라미터(maximum size of the PGA memory for a single process. 단위는 byte)의 50% 중 작은 값으로 설정



- 10gR2 는 조금 더 복잡
  - pga_aggregate_target <= 500MB : _smm_max_size = pga_aggregate_target * 0.2
  - 500MB < pga_aggregate_target <= 1000MB : _smm_max_size = 100MB
  - pga_aggregate_target > 1000MB : _smm_max_size = pga_aggregate_target * 0.1
  - _pga_max_size = _smm_max_size * 2d



- 병렬 쿼리의 각 슬레이브 프로세스가 사용할 수 있는 work area 총량은 _smm_px_max_size 파라미터(KB)에 의해 제한 됨
- SGA : sga_max_size 파라미터로 설정된 크기만큼 공간을 미리 할당
- PGA : 자동 PGA 메모리 관리 기능을 사용하더라도 pga_aggregate_target 크기 만큼의 메모리를 미리 할당하지 않음
- pga_aggregate_target 파라미터는 workarea_size_policy를 auto로 설정한 모든 프로세스들이 할당 받을 수 있는 work area의 총량을 제한하는 용도임





## 3) 수동 PGA 메모리 관리 방식으로 변경 시 주의사항

- workarea_size_policy = manual모드로 설정한 프로세스는 pga_aggregate_target 파라미터 제약 받지 않음
- sort area와 hash area를 아주 큰 값으로 설정하고 실제 매우 큰 작업을 동시에 수행한다면 가용한 물리적 메모리가 고갈돼 페이징(paging)이 발생하면서 시스템 전체 성능 저하(페이징이 심하면 시스템 마비까지 가능)
- *_area_size : 0 ~ 2147483647(2G - 1byte)

#### workarea_size_policy = manual

- 병렬 쿼리를 사용하면 각 병렬 슬레이블 별로 sort_area_size크기 만큼의 sort area 사용 가능
- sort order by나 해시 조인 등을 수행할 때는 사용자가 지정한 DOP(the drgree of parallelism)의 2배수만큼의 병렬 슬레이브가 떠서 작업 수행
- paralle1(t 64)의 경우 128개의 프로세스가 각각 최대 2GB의 sort area 사용
- manual 모드에서 병렬 degree를 크게 설정할 때는 sort_area_size와 hash_area_size를 반드시 확인
- (sort order by를 수행할 때 한쪽 서버 집합은 데이터 블록을 읽어 반대편 서버 집합에 분배하는 역학만 하므로 위 쿼리만으론 최대 64*2GB의 sort area가 필요)



#### 병렬 쿼리 테스트

- 결과 : 시스템의 상태에 따라 작업을 수행하는 병렬 슬레이브의 수가 다를 수 있다.

| parallel Degree | parallel Slave |
| :-------------- | :------------- |
| 8               | 9              |
| 16              | 5              |
| 32              | 5              |
| 64              | 5              |



###### 쿼리

```sql
alter session set workarea_size_policy = manual;
alter session set sort_area_size = 2147483647;

SELECT /*+ full(t) parallel(t 64) */
       *
from t
ORDER  BY object_name;
```



## 4) PGA_AGGREGATE_TARGET 의 적정 크기

###### 오라클 권고

- OLTP : (Total Physical Memory * 80%) * 20%
- DSS : (Total Physical Memory * 80%) * 50%



###### 애플리케이션 특성에 따라 모니터링 결과를 바탕으로 세밀한 조정 필요

- 일반적인 목표 : Optimal 소트 방식으로 수행, 나머지(10%미만)만 onepass 소트 방식으로 수행
- 시스템에 multipass 소트가 종종 발생하는 것으로 측정되면 크기를 늘리거나 튜닝이 필요한 상태임





## 5) sort area 할당 및 해제

### sort_area_size

- 8.0 이전 : 소트가 수행되는 시점에 sort_area_size 크기만큼의 메모리 미리 할당
- 8.0 이후
  - db_block_size 크기에 해당하는 chunk단위로 필요한 만큼 조금씩 할당
  - sort_area_size는 할당할 수 있는 최대 크기를 지정하는 파라미터로 바뀜

### PGA

- 8i 이전 : PGA공간은 프로세스가 해제될 때까지 OS에 반환하지 않음
- 9i 이후 : 자동PGA 메모리 관리 방식 도입으로 프로세스가 더 이상 사용하지 않는 공간을 즉시 반환함으로써 다른 프로세스가 사용 가능 (버그로 인해 PGA메모리가 반환되지 않는 경우가 종종 있음)



### 실제 Sort Area 가 할당되고 해제 되는 과정 측정

- 최초 : 쿼리 수행 직전
- 수행도중 : 쿼리가 수행 중이지만 아직 결과가 출력되지 않은 상태(--> 값이 계속 변함)
- 완료 후 : 결과를 출력하기 시작했지만 데이터를 모두 fetch하지 않은 상태
- 커서를 닫은 후 : 정렬된 결과집합을 끝까지 fetch하거나 다른 쿼리를 수행함으로써 기존 커서를 닫은 직후
- 결과 : 수행도중과 완료 후에 UGA, PGA 크기가 max 값을 밑도는 이유 : 소트해야 할 총량이 할당받을 수 있는 sort area 최대치를 초과하기 때문. 그 때마다 중간 결과집합(sort run)을 디스크에 저장하고 메모리에 반환했다가 필요한 만큼 다시 할당받음
- AUTO 모드로 설정한 프로세스는 이 파라미터의 제약을 받음



### PGA 및 UGA 크기 조회 쿼리

```sql
SELECT ROUND( MIN( decode( n.name , 'session pga memory' , s.value ) ) /1024 ) "PGA(KB)" ,
       ROUND( MIN( decode( n.name , 'session pga memory max' , s.value ) ) /1024 ) "PGA_MAX(KB)" ,
       ROUND( MIN( decode( n.name , 'session uga memory' , s.value ) ) /1024 ) "UGA(KB)" ,
       ROUND( MIN( decode( n.name , 'session uga memory max' , s.value ) ) /1024 ) "UGA_MAX(KB)"
FROM   v$statname n ,
       v$sesstat s
WHERE ( name LIKE '%uga%'
        OR   name LIKE '%pga%' )
AND    n.statistic# = s.statistic#
AND    s.sid = :sid
```



#### 자동 PGA 메모리 관리 방식으로 시스템 레벨에서 사용할 수 있는 총량 제한

- pga_aggregate_target = 24M

```sql
alter system set pga_aggregate_target = 24M;
System altered.
CREATE TABLE t_emp AS
SELECT *
FROM   emp ,
       (
        SELECT ROWNUM no
        FROM   dual
        CONNECT BY LEVEL <= 100000
       ) ;
Table created.
```



### 정렬이 필요한 쿼리 수행

```sql
SELECT *
FROM   t_emp
ORDER  BY empno ;
```



###### 결과

| 단계           | PGA(KB) | PGA_MAX(KB) | UGA(KB) | UGA_MAX(KB) |
| :------------- | :------ | :---------- | :------ | :---------- |
| 최초           | 572     | 3004        | 280     | 657         |
| 수행 도중      | 764     | 3004        | 344     | 657         |
| 완료 후        | 636     | 3004        | 344     | 657         |
| 커서를 닫은 후 | 572     | 3004        | 280     | 657         |



### manual 모드로 설정한 프로세스는 이 파라미터의 제약을 받지 않음

```sql
alter session set workarea_size_policy = MANUAL;
alter session set sort_area_size = 52428800;
alter session set sort_area_retained_size = 52428800;

SELECT *
FROM   t_emp
ORDER  BY empno ;
```



###### 결과

| 단계           | PGA(KB) | PGA_MAX(KB) | UGA(KB) | UGA_MAX(KB) |
| :------------- | :------ | :---------- | :------ | :---------- |
| 최초           | 636     | 3004        | 280     | 657         |
| 수행 도중      | 44796   | 44796       | 44264   | 44264       |
| 완료 후        | 2812    | 52988       | 2393    | 47205       |
| 커서를 닫은 후 | 572     | 52988       | 280     | 47205       |
