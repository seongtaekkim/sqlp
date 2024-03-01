# 08. Statspack And AWR





- 8i부터 사용하던 Statspack과 10g 이후 사용하게 된 AWR(Automatic Workload repository)도 주기적으로 동적 성능 뷰를 수집하여 표준화된 방식으로 성능관리를 지원하려고 오라클이 제고하는 패키지다.

- 이들 패키지는 Ratio기반 성능진단과 Wait Event 기반 성능진단 방법론을 둘 다 가지고 있다.

- 아래 동적 성능 뷰(Dynamic Performance View)를 주기적으로 특정 Repository에 저장하고, 이를 분석해 오라클 데이터베이스 전반의 건강 상태를 체크하고 병목원인과 튜닝 대상을 식별해 내는 데 사용한다.
  ~~~sql
  - v$segstat
  - v$undostat
  - v$latch
  - v$latch_children
  - v$sgastat
  - v$pgastat
  - v$sysstat
  - v$system_event
  - v$waitstat
  - v$sql
  - v$sql_plan
  - v$splstats(10g이후)
  - v$active_session_history(10g 이후)
  - v$osstat(10g 이후)
  ~~~



- Statspack은 SQL을 이용한 딕셔너리 조회방식.
- AWR은 DMA(Direct Memory Access)방식으로 SGA를 직접 액세스.(빠르게 정보를 수집) 부하가 적기 때문에 Statspack 보다 더 많은 정보를 수집하고 제공할 수 있다.
- 오라클 9i에서는 Statspack의 정보를 수집하는데 따른 부하 때문에 스냅샷을 자주 수행하기 어려웠다. 사용자가 수동이나 정해진 기간 동안만 JOB에 등록해 DB 성능 정보를 수집.
- 10g AWR부터는 자동으로 성능 자료를 수집해 일정기간 보관한다.
  (스냅샷 주기 : 1시간, 보관주기 : 1주일 - 설정변경가능)



## 1) Statspack / AWR 기본 사용법

- Statspack : PERFSTAT 계정 밑에 'stats$'로 시작하는 뷰를 통해 수집된 성능 정보를 조회.
- AWR에서는 SYS 계정 밑에 'dba_hist_'로 시작하는 뷰를 이용.
- 표준화된 보고서 출력

SQL>@?/rdbms/admin/awrrpt <--- ? AWR SQL>@?/rdbms/admin/spreport <--- ? Statspack

- 성능 진단 보고서를 출력할 때는 측정구간, 즉 시작스냅샷 ID와 종료스냅샷 ID를 어떻게 입력하느냐가 가장 중요하다.
- 매일매일 시스템의 Load Profile의 비교 목적이라면 업무시간을 기준으로 뽑고, 문제점을 찾아 성능 이슈를 해결할 목적이라면 peak 시간대 또는 장애가 발생한 시점을 전후해 가능한 한 짧은 구간을 선택해야 한다.
- AWR뷰를 직접 쿼리해 하루 동안의 각 통계항목별 성능추이와 이벤트 발생 현황을 볼 수 있다.
- 정해진 기간동안 각 구간별로 SQL 실행횟수를 뽑아오는 쿼리

~~~sql
select to_char(min(s.begin_interval_time), 'hh24:mi') begin
, to_char(min(s.end_interval_time),'hh24:mi') end
, sum(b.value-a.value) "execute count"
from dba_hist_sysstat a, dba_hist_sysstat b, dba_hist_snapshot s
where s.instance_number = &instance_number
and s.snap_id between &gegin_snap and &end_snap
and a.stat_name = 'execute count'
and b.stat_id = a.stat_id
and b.snap_id = s.snap_id
and a.snap_id = b.snap_id - 1
and a.instance_number = s.instance_number
group by s.snap_id
order by s.snap_id;
~~~





## 2) Statspack / AWR 리포트 분석

- Statspack과 AWR 리포트에 맨 첫 장을 보면 오라클 데이터베이스의 상태를 한눈에 파악해 볼 수 있는 요약보고서가 나온다. 그 한장의 보고서를 정확히 해석할수만 있다면 AWR을 효과적으로 활용할 수 있다.

| Loar Profile      | Per Second | Per Transaction |
| ----------------- | ---------- | --------------- |
| Redo size :       | 140,839.60 | 5,345.24        |
| Logical reads :   | 47,768.26  | 1,812.93        |
| Block changes :   | 711.34     | 27.00           |
| Physical reads :  | 736.69     | 27.96           |
| Physical writes : | 84.69      | 3.21            |
| User calls :      | 2,401.63   | 91.15           |
| Parses :          | 412.66     | 15.66           |
| Hard parses :     | 1.49       | 0.06            |
| Sorts :           | 138.94     | 5.27            |
| Logons :          | 0.79       | 0.03            |
| Executes :        | 1,187.18   | 45.06           |
| Transactions :    | 26.35      |                 |

- Per Second는 각 측정 지표 값들을 측정 시간(Snapshot interval, 초)으로 나눈 것.(초당 부하)
- Per Transaction은 각 측정 지표 값들을 트랜잭션 개수로 나눈 것이다. 한 트랜잭션 내에서 평균적으로 얼만큼의 부하가 발생하였는지를 나타내는 것인데, 트랜잭션 개수가 commit 또는 rollback 수행 횟수를 단순히 더한 값이어서 의미 없는 수치로 받아들여질 때가 종종 있다.
  (조회 위주의 시스템이라면 I/O 수치는 계속 누적되는 반면 commit 발생 횟수는 적기 때문에 트랜젝션당 Logical reads와 Physical reads 항목이 매우 높게 나타난다)
- 실제 업무적인 의미에서의 트랜잭션과 괴리가 있다는 사실과, 본인이 관리하는 시스템의 특성을 이해한 상태에서 수치를 해석해야 한다.

- AWR에서 보여지는 항목들을 v$sysstat 뷰를 이용한 개별 쿼리
  ~~~sql
  select value rsiz from v$sysstat where name = 'redo size';
  
  select value gets from v$sysstat where name = 'session logical reads';
  
  select value chng from v$sysstat where name = 'db block changes';
  
  select value phyr from v$sysstat where name = 'physical reads';
  
  select value phyw from v$sysstat where name = 'physical writes';
  
  select value ucal from v$sysstat where name = 'user calls';
  
  select value prse from v$sysstat where name = 'parse count (total)';
  
  select value hprse from v$sysstat where name = 'parse count (hard)';
  
  select srtm + srtd from
  (select value srtm from v$sysstat where name = 'sorts (memory)' ),
  (select value srtd from v$sysstat where name = 'sorts (disk)' );
  
  select value logc from v$sysstat where name = 'logons cumulative';
  
  select value exe from v$sysstat where name = 'execute count';
  
  select ucom + urol from
  (select value ucom from v$sysstat where name = 'user calls'),
  (select value urol from v$sysstat where name = 'user rollbacks');
  ~~~





| % Blocks changed per Read : 15.9  | Recursive Call % : 35.33 |
| --------------------------------- | ------------------------ |
| Rollback per transaction % : 3.81 | Rows per Sort : 274.24   |

% Block changed per Read : 읽은 블록 중 갱신이 발생하는 비중.

~~~sql
select round(100*chng/gets, 2) "% Blocks changed per Read"
from
(select value chng from v$sysstat where name = 'db block changes'),
(select value gets from v$sysstat where name = 'session logical reads');
~~~

Rollback per transaction % : 최종적으로 커밋되지 못하고 롤백된 트랜잭션 비중.

~~~sql
select round(100*urol/(ucom+urol), 2) "Rollback per transaction %"
from
(select value ucom from v$sysstat where name = 'user calls'),
(select value urol from v$sysstat where name = 'user rollbaks');
~~~

Recursive Call % : 전체 Call 발생 횟수에서 Recursive Call이 차지하는 비중.
(사용자 정의 함수/프로시저를 많이 사용하면 이 수치가 높아지며, 하드파싱에 의해서도 영향을 받는다)

~~~sql
select round(100*recr/(recr+ucal), 2) "Recursive Call %"
from
(select value recr from v$sysstat where name = 'recursive calls'),
(select value ucal from v$sysstat where name = 'user calls');
~~~

Rows per Sort : 소트 수행 시 평균 몇 건씩 처리했는지를 나타낸다.

~~~sql
select decode((srtm+srtd), 0, to_number(null), round(srtr/(srtm+srtd),2))
from
(select value srtm from v$sysstat where name = 'sorts (memory)'),
(select value srtd from v$sysstat where name = 'sorts (disk)'),
(select value srtr from v$sysstat where name = 'sorts (rows)')
~~~



### 인스턴스 효율성 리포트

| Instance Efficiency Percentages (Target 100%) |       |                    |        |
| --------------------------------------------- | ----- | ------------------ | ------ |
| Buffer Nowait % :                             | 99.99 | Redo NoWait % :    | 100.00 |
| Buffer Hit % :                                | 98.71 | In-memory Sort % : | 100.00 |
| Library Hit % :                               | 99.67 | Soft Parse % :     | 99.64  |
| Execute to Parse % :                          | 65.24 | Latch Hit % :      | 99.89  |
| Parse CPU to Parse Elapsd % :                 | 0.85  | % Non-Parse CPU :  | 97.96  |

- Execute to Parse % 항목을 제외하면 모두 100%에 가까운 수치를 보여야 정상.
- 위에서 Parse CPU to Parse Elapsed % 항목이 0.85로 비정상적으로 낮은 수치를 보인 것은, Active 프로세스가 동시에 폭증하면서 과도한 Parse Call이 발생한 장애 상황에서 측정했기 때문.



### Shared Pool 사용량 통계

| Shared Pool Statistics        | Begin | End   |
| ----------------------------- | ----- | ----- |
| Memory Usage % :              | 69.20 | 93.96 |
| % SQL with executions > 1 :   | 93.40 | 98.29 |
| % Memory for SQL w/exec > 1 : | 73.36 | 98.99 |

- AWR리포트 구간 시작 시점의 Shared Pool 메모리 상황과 종료 시점에서의 메모리 상황을 보여준다. (앞에서 설명)



### Top 5 Timed Events는 AWR 

| Top 5 Timed Events      |            |         | Avg  Wait  (ms) | %Total  Call  Time |            |
| ----------------------- | ---------- | ------- | --------------- | ------------------ | ---------- |
| Event                   | Waits      | Time(s) |                 |                    | Wait Class |
| Latch free              | 2,169,850  | 596,104 | 275             | 70.2               | Other      |
| Latch: shared pool      | 1,050,870  | 262,298 | 250             | 30.9               | Concurrenc |
| Latch: library cache    | 868,920    | 219,076 | 252             | 25.8               | Concurrenc |
| Db file sequential read | 18,869,172 | 108,189 | 6               | 12.7               | User I/O   |
| CPU time                |            | 48,991  |                 | 5.8                |            |

- Top 5 Timed Events는 AWR 리포트 구간 동안 누적 대기 시간이 가장 컸던 대기 이벤트 5개를 보여준다.(Idle 이벤트 제외)

- 위 리포트는 Active 프로세스가 동시에 폭증하면서 과도한 Parse Call을 일으키고 OS 레벨에서 Paging까지 심하게 발생했던 장애 상황에서 측정한 것이다.

- CPU time은 대기 이벤트가 아니며 원활하게 일을 수행했던 Service time이지만, 가장 오래 대기를 발생시켰던 이벤트와의 점유율을 서로 비교해 볼 수 있도록 Top 5 대기 이벤트에 포함해 보여주고 있다.

  ~~~
  Response Time = Service Time + Wait Time
                = CPU Time + Queue Time
  ~~~

  - 위 공식에 의하면 CPU time %와 Wait time %를 더한 값이 100을 넘을 수 없지만 위 사례는 비정상적이 장애 상황이어서 그런지 100%를 넘었다.
  - CPU time이 Total Call Time에서 차지하는 비중이 가장 높아 Top 1에 위치한다면 일단 DB의 건강상태가 양호하다는 청신호인 셈이다. 반대로 CPU time 비중이 아래쪽으로 밀려날수록 어딘가 이상이 발생했다는 적신호로 받아들여야 한다.

- 서비스가 정상적으로 수행된 시간대에 AWR 리포트를 뽑더라도 CPU time을 제외하고 항상 4개의 대기 이벤트가 나열된다.

- 예를 들어, 래치나 Lock관련 대기 이벤트 순위가 상위로 매겨졌다면, 문제가 발생했음을 나타내는 위험 신호일 가능성이 높지만 래티의 경우는, CPU 사용률까지 같이 분석해 봐야 한다. 래치 경합은 CPU 사용률을 높이는 주원인이므로, 그 당시 CPU 사용률이 높지 않았다면 다른 이벤트보다 상대적으로 많이 발생한 것에 불과 할 수 있다.

- 트랜잭션 처리 위주의 시스템이라면 log file sync 대기 이벤트가 Top 5 내에 포함되었다고 무조건 이상 징후로 보기 어렵다.(이벤트가 많이 발생한 것만으로 불필요한 커밋을 자주 날렸다고 판단해서는 않된다)

- I/O 관련 대기 이벤트가 상위로 올라오는 것은, 상황에 따라 다르게 해석해야 한다. 데이터베이스는 I/O 집약적인 시스템이므로 db_file_sequential read, db_file_scattered_read 대기 이벤트가 상위에 매겨지는 게 정상이다. 다만, 이 두 대기 이벤트가 CPU time 보다 높은 점융율을 차지하고, OS 모니터링 결과 CPU 사용률도 매우 높은 상황이 지속된다면 I/O 튜닝이 필요한 시스템일 가능성이 높다.

- 대기 이벤트 발생 현황만을 놓고 보면 별 문제가 없어 보이지만 실제 사용자가 느끼는 시스템 성능은 매우 느린 경우가 많다. 아무리 peak time 전후로 리포트 구간을 짧게 가져가더라도 시스템 레벨로 측정한 값이기 때문에 그렇다.(Top-N 대기 이벤트 분석에 의한 성능 진단의 한계)
  -> 9절 ASH에서 대응사항을 알아보자.

