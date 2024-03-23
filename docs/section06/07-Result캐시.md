# 07. Result캐시



## $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

RESULT_CACHE 힌트 등의 테스트는 2회독때 가능하다면 해보자 (내용이 딥하다..)

## $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$



- 오라클은 한번 수행한 쿼리 또는 PL/SQL 함수의 결과값을 Result 캐시에 저장해 두는 기능을 11g버전부터 제공하기 시작함.
  - **DML이 거의 발생하지 않는 테이블을 참조하면서, 반복 수행 요청이 많은 쿼리에 이 기능을 사용하면 I/O발생량을 현격히 감소시킬 수 있다.**
- 예를 들어 특정 Query가 반복적으로 수행될 때 이 결과를 캐시하여, 다음부터는 해당 쿼리를 다시 execute하는 것이 아니라 캐시 메모리에 저장된 결과 값을 그대로 가져오게 된다.
- Result 캐시는 버퍼캐시에 위치하지 않고 Shared Pool에 위치하지만 시스템 I/O 발생량을 최소화하는데 도움이 되는 기능이다.

- Result Cache 영역
  - SQL Query Result 캐시 : SQL 쿼리 결과를 저장
  - PL/SQL 함수 Result 캐시 : PL/SQL 함수 결과값을 저장

- Result Cache는 SGA영역에 존재하므로, 모든 세션에서 공유가능하고, 인스턴스를 재기동하면 초기화되며, 해당 쿼리가 접근하는 오브젝트가 변경될 때 invalid된다.
- 공유영역에 존재하므로 래치가 필요하다.

- Result 캐시를 위해 추가된 파라미터들

| 파라미터                       | 기본값 | 설명                                                         |
| :----------------------------- | :----- | :----------------------------------------------------------- |
| result_cache_max_size          | N/A    | SGA내에서 result_cache가 사용할 메모리 총량을 바이트로 지정. 0으로 설정하면 이 기능이 작동하지 않음 |
| result_cache_max_result        | 5      | 하나의 SQL 결과집합이 전체 캐시 영역에서 차지할 수 있는 최대 크기를 %로 지정 |
| result_cache_remote_expiration | 0      | remote객체의 결과를 얼마 동안 보관할 지를 분 단위로 지정<br />Remote 객체는 result 캐시에 저장하지 않도록 하려면 0으로 설정 |
| result_cache_mode              | Manual | Result 캐시 등록 방식을 결정<br />Manual:result_cache 힌트를 명시한 SQL만 등록.<br />Force:no_result_cache 힌트를 명시하지 않은 모든 SQL을 등록 |

- 아래와 같은 경우에는 쿼리 결과집합을 Result Cache에 캐싱하지 못한다.
  - Dictionary 오브젝트를 참조할 때
  - Temporary 테이블을 참조할 때
  - 시퀀스로부터 CURRVAL, NEXTVAL Pseudo 컬럼을 호출할 때
  - 쿼리에서 아래 SQL함수를 사용할 때 (아래)
    - CURRENT_DATE
    - CURRENT_TIMESTAMP
    - LOCAL_TIMESTAMP
    - SYS_CONTEXT(with non-constant variables)
    - SYS_GUID
    - SYSDATE
    - SYSTIMESTAMP
    - USERENV(with non-constant variables)

- 바인드 변수를 사용한 쿼리는 바인딩 되는 값에 따라 개별적으로 캐싱되므로, 변수값 종류가 다양한 쿼리는 등록을 삼가해야한다.
- 쿼리에서 사용하는 테이블에 DML이 발생한 경우 캐싱된 결과집합을 무효화 시킨다.
- 인라인뷰 또는 일부집합만 캐싱도 가능하나 서브쿼리는 불가능하다.



#### 사용권장 하는 경우

- 작은 결과 집합을 얻으려고 대용량 데이터를 읽어야 할 때
- 읽기 전용의 작은 테이블을 반복적으로 읽어야 할 때
- 읽기 전용코드 테이블을 읽어 코드명칭을 반환하는 함수

#### 사용자제 해야 하는 경우

- 쿼리가 참조하는 테이블에 DML이 자주 발생할 때
- 함수 또는 바인드 변수를 가진 쿼리에서 입력되는 값의 종류가 많고, 골고루 입력될 때





#### 참고

지금까지 설명한 기능은 서버 측 Result Cache 기능이다 
클라이언트 측 Result Cache기능은 오라클 매뉴얼 참조가 필요하다.