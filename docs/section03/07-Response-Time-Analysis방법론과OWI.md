# 07. Response Time Analysis 방법론과 OWI





- Response Time Analysis 방법론
  - 1999년 6월에 'Yet Another Performance Profiling Method' (YAPP)라는 제목의 오라클 기술백서가 발표되면서 주목

```
Response Time = Servic Time + Wait Time
              = CPU Time    + Queue Time
```

| 구분                      | 내용                                                         |
| :------------------------ | :----------------------------------------------------------- |
| 서비스 시간(Servic Time ) | 프로세스가 정상적으로 동작하며 일을 수행한 시간(=CPU time)   |
| 대기 시간(Wait Time)      | 대기 이벤트가 발생해 수행을 잠시 멈추고 대기한 시간(=Queue Time) |

- CPU time과 Wait time을 각각 break down하면서 서버의 일량과 대기 시간을 분석

- OWI(Oracle Wait Interface): Response Time Analysis 방법론을 지원하려고 오라클이 제공하는 기능과 인터페이스를 통칭하는 말
  - Response Time Analysis 방법론에 기반한 튜닝은 병목해소 과정이다





### 테스트

## &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

2회독 때 아래 시나리오를 실제 데이터 구성해서 테스트 해보자

## &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

- 아래 쿼리를 8개 프로세스가 수행하도록 설정하였으나 오래걸린다.

~~~sql
INSERT INTO t1
SELECT /*+ parallel(t2, 8) ordered use_nl(t3) */ 
seq.nextbal, t2.*, t3.*
FROM t2, t3
WHERE t2.key = t3.key
and t2.col between :range1 and :range2;
~~~

| step | comment                                                      |
| ---- | ------------------------------------------------------------ |
| 1    | 분석 - db file scattered read 대기 이벤트가 Wait time의 대부부분을 차지 → Full Table Scan을 하고 있음.<br />원인 - t2 테이블 기준으로 NL 조인을 수행하면서 반복 액세스가 일어나는 t3 테이블 조인 컬럼에 인덱스가 없어 매번 Full Table Scan<br />해결 - 인덱스를 추가해 정상적인 Index Scan하도록 변경 |
| 2    | 분석 - Step1 이후 buffer busy waits과 latch: cache buffers chains 이벤트가 새롭게 발생<br />원인 - 서버 프로세스의 처리 속도가 크게 향상되면서 버퍼 블록에 대한 동시 액세스가 증가하면서 메모리 경합이 발생<br />해결 - 캐싱된 버퍼 블록에 대한 읽기 요청이 많아 생기는 문제이므로 블록 요청 횟수를 줄여야 한다. → NL조인을 해시 조인 방식으로 변경 |
| 3    | 분석 - log buffer space와 enq:SQ-contention 이벤트가 새롭게 발생<br />원인 - select 경합이 해소되면서 insert에 의한 Redo 레코드 생성 속도가 증가하니까 Redo 로그 버퍼 공간이 부족하고 Sequence 테이블에 대한 경합 발생<br />해결 - Redo 로그 버퍼 크기를 약간 늘려주고, Sequence 캐시 사이즈를 10에서 20으로 늘림 |

- Response Time Analysis 방법론을 지원하는 오라클
  - 버전을 거듭할 수록 대기 이벤트는 세분화 되고 있고, 유용한 동적 성능 뷰도 계속 증가
  - 10g부터는 쿼리를 이용하지 않고 직접 SGA 메모리를 액세스하기 때문에 더 많은 정보 수집 가능
  - Response Time Analysis 방법론 지원하는 오라클 표준도구: Statspack, AWR (8절)
