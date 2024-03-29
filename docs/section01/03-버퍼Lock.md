# 버퍼 Lock





## 1. 버퍼 Lock이란?



##### 버퍼Lock역할을 순서와함께 살펴보자.

1) DB 버퍼 캐시 내에서 버퍼 블록을 찾은 후 바로 래치를 해제해야한다.
   - 해제가 늦어지면 cache buffer chains 래치에 여러 개의 해시 체인이 달렸으므로 래치에 대한 경합 발생 가능성이 증가하게 된다.
2) 캐시된 버퍼 블록을 읽거나 변경하려는 프로세스는 먼저 버퍼 헤더로부터 버퍼 Lock을 획득해야 한다.
   - 2개이상 프로세스가 동시에 버퍼 내용을 읽고 쓴다면 문제가 생길수 있음 (정합성)

3. 버퍼 Lock을 획득했다면 래치를 곧바로 해제한다.

   - 버퍼 내용을 읽기만 할때는 Share 모드, 변경 할때는 Exclusive 모드로 Lock을 설정한다.

   - select문이더라도[Block Clean Out](./08-Block-CleanOut.md)이 필요할 때는 버퍼 내용을 변경하는 작업이므로 Exclusive 모드 Lock이 필요함.

4. 다른 프로세스가 버퍼 Lock을 Exclusive 모드로 점유한 채 내용을 갱신 중이라면 버퍼 헤더에 잇는 버퍼 Lock 대기자 목록(Waiter List)에 자신을 등록하고 일단 래치는 해제한다. 
   - 이때, 버퍼 Lock 대기자 목록에 등록돼 있는 동안 [buffer busy waits 대기 이벤트](./대기이벤트.md)가 발생한다.

5. 대기자 목록에서 기다리다가 버퍼 Lock이 해제되면 버퍼 Lock을 획득하고, 원했던 작업을 진행한다
6. 목적한 읽기/쓰기 작업을 완료하면 버퍼 헤더에서 버퍼 Lock을 해제해야 하는데, 이 때도 버퍼 헤더를 액세스하려는 **다른 프로세스와 충돌이 생길 수 있으므로 해당 버퍼가 속한 체인 래치를 다시 한번 획득한다.**
7. 버퍼 Lock을 해제하고 래치를 해제해야 비로소 버퍼 블록 읽기가 완료된다.
8. 읽으려는 블록이 버퍼 캐시에 없을 때는 디스크 I/O까지 수반되므로 하나의 블록 읽기가 고비용의 작업이다.



![스크린샷 2024-02-14 오후 2.12.54](/Users/staek/Library/Application Support/typora-user-images/스크린샷 2024-02-14 오후 2.12.54.png)



## 2. 버퍼 핸들

- 버퍼 Lock을 설정하는 것은 자신이 현재 그 버퍼를 사용중임을 표시해 두는 것으로서, 그 버퍼 헤더에 Pin을 걸었다고도 표현한다.
- 버퍼 Lock을 다른 말로 '버퍼 Pin'이라고 표현하기도 하며, 앞에서 말한 Pinned 버퍼가 여기에 해당한다.
- 변경 시에는 하나의 프로세스만 Pin을 설정할 수 있지만 읽기 작업을 위해서라면 여러 개 프로세스가 동시에 Pin을 설정할 수 있다.
- 버퍼 헤더에 Pin을 설정할고 사용하는 오브젝트를 `버퍼핸들` 이라고 부르며, 버퍼 핸들을 얻어 버퍼 헤더에 있는 소유자 목록(Holder List)에 연결시키는 방식으로 Pin을 설정한다.
- 버퍼 핸들도 공유된 리소스이므로 버퍼 핸들을 얻으려면 또 다른 래치가 필요해지는데, 바로 `cache buffer handles 래치`가 그것이다.
- 버퍼를 Pin하는 오퍼레이션이 많을수록 오히려 cache buffer handles 래치가 경합지점이 될 것이므로 오라클은 각 프로세스마다 `_db_handles_cached` 개수만큼의 버퍼 핸들을 미리 할당해 주며, 기본 값은 5개다. (oracle21c: 10개)
- 각 세션은 이를 캐싱하고 있다가 버퍼를 Pin 할 때마다 사용하며, 그 이상의 버퍼 핸들이 필요할 때만 cache buffer handles 래치를 얻고 추가로 버퍼 핸들을 할당 받는다.
- 시스템 전체적으로 사용할 수 있는 총 버퍼 핸들 개수는 `_db_handles` 파라미터에 의해 결정되며, 이는 `processes` 파라미터와 `_db_handles_cached` 파라미터를 곱한 값으로 설정된다.



~~~
SELECT A.KSPPINM  NAME,
       B.KSPPSTVL VALUE,
       A.KSPPDESC DESCRIPTION
FROM   X$KSPPI  A,
       X$KSPPSV B
WHERE  A.INDX = B.INDX
AND    LOWER(A.KSPPINM) IN ('_db_handles', '_db_handles_cached', 'processes')
ORDER  BY 1
;

~~~

| name               | value | description                                |
| ------------------ | ----- | ------------------------------------------ |
| _db_handles        | 3200  | System-wide simultaneous buffer operations |
| _db_handles_cached | 10    | Buffer handles cached each process         |
| processes          | 320   | user processes                             |







## 3. 버퍼 Lock의 필요성

- 사용자 데이터를 변경할 때는 DML Lock을 통해 보호하도록 돼 있는데, 그것을 담는 블록에 또 다른 Lock을 획득해야 하는 이유는, 오라클이 하나의 레코드를 갱신하더라도 블록 단위로 I/O를 수행하기 때문이다.

- 블록 안에 저장된 10개의 레코드를 읽는 짧은 순간 동안 다른 프로세스에 의해 변경이 발생하면 잘못된 결과를 얻게 된다.
  **(00000000 Consistent, Undo, 쿼리SCN 등 뒤에 나오는 개념과 통합해서 다시 정리 예정 00000000000)**

- 값을 변경하기 전에 레코드에 로우 단위 Lock을 설정하는 일 자체도 레코드의 속성을 변경하는 작업이므로 두 개의 프로세스가 동시에 로우 단위 Lock을 설정하려고 시도한다면(대상 로우가 다르더라도) 문제가 된다.

- [블록 SCN](나중에)을 변경하거나 [ITL 슬롯](나중에)에 변경을 가하는 등 블록 헤더 내용을 변경하는 작업도 동시에 일어날 수 있는데, 이런 동시 액세스가 실제로 발생한다면 Lost Update 문제가 생겨 블록 자체의 정합성이 깨지게 된다. 그러므로 블록 자체로의 진입을 직렬화해야 하는 것이다.

- Pin된 버퍼 블록은, **버퍼 캐시 전체를 비우려고** 아래 시스템 명령어를 날리더라도 밀려 나지 않는다.
  ~~~sql
  SQL> ALTER SYSTEM FLUSH BUFFER_CACHE;
  ~~~

  



## 4. 버퍼 pinning

- 버퍼를 읽고 나서 버퍼 Pin을 즉각 해제하지 않고 데이터베이스 **Call(Prase Call, Execute Call, Fetch Call)**이 진행되는 동안 유지하는 기능을 말한다.
- 같은 블록을 반복적으로 읽을 때 버퍼 Pinning을 통해 래치 획득 과정을 생략한다면 **논리적인 블록 읽기(Logical reads)횟수**를 획기적으로 줄 일 수 있다. 모든 버퍼 블록을 이 방식으로 읽는 것이 아니며, **같은 블록을 재방문할 가능성이 큰 몇몇 오퍼레이션을 수행할 때만 사용한다.**
- 래치 획득 과정을 통해 블록을 액세스할 때는 **session logical reads** 항목이 증가하고, 래치 획득 과정 없이 버퍼 Pinning 을 통해 블록을 곧바로 액세스할 때는 **buffer is pinned count** 항목의 수치가 증가한다. **(v$sysstat, v$sesstat, v$mystat)**
- 버퍼 Pinning은 하나의 데이터베이스 **Call(Prase Call, Execute Call, Fetch Call)**내에서만 유효하다.
- **Call이 끝나고 사용자에게 결과를 반환하고 나면 Pin은 해제되어야 한다.**
- 첫 번째 Fetch Call에서 Pin된 블록은 두 번째 Fetch Call에서 다시 래치 획득 과정을 거쳐 Pin되어야 한다.

- **전통적으로** 버퍼 Pinning이 적용되던 지점은 인덱스를 스캔하면서 테이블을 액세스할 때의 인덱스 리프 블록이다.
- **Index Range Scan**하면서 인덱스와 테이블 블록을 교차방문 할 때 블록 I/O를 체크해 보면, 테이블 블록에 대한 I/O만 계속 증가하는 이유가 여기에 있다.
- 인덱스를 경유해 테이블을 액세스할 때 **인덱스 클러스터링 팩터**가 좋다면 (인덱스 레코드가 가리키는 테이블 rowid 정렬 순서가 인덱스 키 값 정렬 순서와 거의 일치한다면) 같은 테이블 블록을 반복 액세스할 가능성이 그만큼 커진다.

- 오라클 8i부터, **인덱스로부터 액세스되는 하나의 테이블 블록을 Pinning하기 시작했다.**

- 9i 부터는 NL, 조인 시 Inner 테이블을 룩업하기 위해 사용되는 인덱스 루트 블록을 Pinning 하기 시작 햇다.
- 9i에 도입된 **Index Skip Scan**에서 **브랜치 브록을 거쳐 리프 블록을 액세스하는 동안에도 브랜치 블록을 계속 Pinning하고 있다가 그 다음 방문할 리프 블록을 찾으려 할때 추가적인 래치 획득 과정없이 브랜치 블록을 곧바로 읽는다.**

- 11g 부터는 **NL 조인 시 Inner 테이블의 인덱스 루트 블록 뿐 아니라 다른 인덱스 블록에 대해서도 Pinning을 함으로써 논리적 블록 읽기를 획기적으로 감소시키고 있다.**
- DML 수행 시 Undo 레코드를 기록하는 Undo 블록에 대해서도 Pinning을 적용한다.

- 버퍼 Pinning을 통한 블록I/O감소효과는 튜닝에 중요한 이슈이므로 원리를 알고 있어야 한다.
  인덱스를 통해 소량데이터 테이블을 읽을때 느린경우, 대량데이터 테이블을 읽을 때 빠른경우가 있는데, 인덱스 클러스터링 팩터, 버퍼Pinning과 관련이 있다. (2권에서 사례소개)



~~~
4절 내용은 2권 1,2,3장을 학습후 예제를 통해서 이해할 수 있다.
현재시점에서는 흐름만 이해하고
2권에서 여러 튜닝사례를 접한 후 v$sysstat, v$sesstat, v$mystat등 통계로 보다 깊은 이해를 할 수 있습니다.
~~~





