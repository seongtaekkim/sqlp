# 03. SQL트레이스



- 실행계획과 Autotrace만으로 부하의 원인을 찾기 어려울 때 내부 수행 절차상 어느 단계에서 부하를 일으키는 지 확인하고자 할 때 사용한다.



## (1) 자기 세센에 트레이스 걸기

- 아래와 같이 설정하고 SQL을 수행한 후에는 user_dump_dest에 지정된 디렉토리 밑에 트레이스(.trc) 파일이 생성됨

```sql
alter session set sql_trace = true;
SELECT * FROM emp WHERE empno = 7788;
SELECT * FROM dual;
alter session set sql_trace = false;
```



- 가장 최근에 수정되거나 생성 된 파일을 찾아 분석
- 파일 찾기 어려울 경우 아래 스크립트를 이용해 현재 트레이스 파일을 쉽게 찾을 수 있음

```sql
SELECT r.value || '/' || LOWER(t.instance_name) || '_ora_'
    || ltrim(to_char(p.spid)) || '.trc' trace_file
  FROM v$process p, v$session s, v$parameter r, v$instance t
 WHERE p.addr = s.paddr
   AND r.name = 'user_dump_dest'
   AND s.sid = (SELECT sid FROM v$mystat WHERE rownum = 1)
;

TRACE_FILE
-----------------------------------------------------------
/opt/oracle/homes/OraDBHome21cXE/rdbms/log/xe_ora_302.trc
```



- 아래의 명령어 사용 시 식별자가 붙게 되므로 쉽게 찾을 수 있음

```sql
alter session set tracefile_identifier ='manon94'
orcl_ora_2444_manon94.trc
```







## (2) 다른 세센에 트레이스 걸기

- (1)특정 세션에서 심한 성능 부하를 일으키고 있다면, 트레이스를 걸어야 하는데 그럴때 사용 할 수 있는 방법들이 존재하며, 버젼마다 다르며 오라클 9i에서는 Serial 번호가 3번인 145번 세션에 레별 12로 10046 트레이스를 수집하는 방법은 아래와 같음
- (2)트레이스 해제시에는 레벨을 0으로 변경

```sql
exec dbms_system.set_ev(145,3,10046,12,'');
```



- 오라클 10g 이후부터는 dbms_monitor 패키지를 사용

```sql
select * from v$session
where username = 'SYS';

begin
dbms_monitor.session_trace_enable(
session_id => 288,
serial_num => 35186,
waits      => true,
binds      => true);
end;
/
```



- 트레이스 해제 시 session_trace_disable

```sql
begin
dbms_monitor.session_trace_disable(
session_id => 145,
serial_num => 3);
end;
/
```



- 버전에 상관없이 오래 전부터 사용하던 Oradebug 명령어가 존재하며 'oradebug help'를 입력하면 사용 방법을 알 수 있음
- 시스템 전체 트레이스를 설정하는 방법은 아래와 같으며, 심각한 부하를 일으키므로 부득이한 경우를 제외하고는 사용 해서는 안됨

```sql
alter system set sql_trace = true;
alter system set sql_trace = false;
```







## (3) Service, Module, Action 단위로 트레이스 걸기

- (1) 10g 부터 Service, Module, Action 별로 트레이스를 설정 및 해제 가능한 dbms_monitor 패키지가 존재하며, 현재 접속해있는 세션 뿐만 아니라 새로 커넥션을 맺는 세션도 자동으로 트레이스가 설정 됨
- (2) v$session을 통해 Service, Module, Action을 확인 할 수 있음
- (3) Action은 dbms_application_info.set_action('action_name')을 통해서 설정 변경 가능
- (4) 트레이스 설정 확인은 dba_enable_traces 뷰를 통해 확인 가능함

```
begin
dbms_monitor.serv_mod_act_trace_enable (
     service_name => 'eCRM'  -- 대소문자 구분함
    ,module_name  => dbms_monitor.all_module
    ,action_name  => dbms_monitor.all_actions
    ,waits        => true
    ,binds        => true);
/
```



- 트레이스 해제는 아래와 같음

```sql
begin
dbms_monitor.serv_mod_act_trace_disable (
     service_name => 'eCRM'
    ,module_name  => dbms_monitor.all_module
    ,action_name  => dbms_monitor.all_actions
);
/
```



- dbms_monitor.serv_mod_act_trace 패키지를 통해 Service, Module, Action 단위의 v$sesstat통계 정보 수집도 가능하며 v$serv_mod_stats뷰를 통해 수행통계를 확인 할 수 있음





#### 트레이스 주요 항목 및 Tkprof

- Tkprof 유틸리티를 이용하여 트레이스 파일을 보기 쉽게 포맷팅 할 수 있음

```
$ tkprof
Usage: tkprof tracefile outputfile [explain= ] [table= ]
              [print= ] [insert= ] [sys= ] [sort= ]

tkprof ora_trace.trc report.prf sys=no
```



- Tkprof 유틸리티를 이용하여 트레이스 파일을 변환하면 아래와 같은 양식으로 출력됨

```sql
================================================================================

Call     Count CPU Time Elapsed Time       Disk      Query    Current       Rows
------- ------ -------- ------------ ---------- ---------- ---------- ----------
Parse        1    0.010        0.018          0         70          0          0
Execute      1    0.000        0.000          0          0          0          0
Fetch        9    0.640        0.769          0      42864          0        728
------- ------ -------- ------------ ---------- ---------- ---------- ----------
Total       11    0.650        0.787          0      42934          0        728

Misses in library cache during parse: 1
Optimizer goal: CHOOSE
Parsing user: XXX (ID=182)

Rows     Row Source Operation
-------  ---------------------------------------------------
      0  STATEMENT
...
    728    HASH JOIN OUTER (cr=32575 r=0 w=0 time=663883 us)
    728     NESTED LOOPS  (cr=32529 r=0 w=0 time=654975 us)
    728      NESTED LOOPS  (cr=31071 r=0 w=0 time=649598 us)
    728       NESTED LOOPS  (cr=29613 r=0 w=0 time=644591 us)
    728        TABLE ACCESS BY INDEX ROWID IT (cr=28155 r=0 w=0 time=637907 us)
    946         INDEX FULL SCAN DESCENDING ITIND99 (cr=27330 r=0 w=0 time=633707 us)OF ITIND99 (NONUNIQUE)
```



##### Call통계 컬럼

| 항목    | 설명                                                         |      |
| :------ | :----------------------------------------------------------- | ---- |
| call    | 커서 상태에 따라 Parse, Execute, Fetch 세 개의 Call로 나누어 각각에 대한 통계정보를 보여줌  \- Parse : 커서를 파싱하고 실행계획을 생성하는 데 대한 통계  \- Execute : 커서의 실행 단계에 대한 통계  \- Fetch : 레코드를 실제로 Fetch하는 데 대한 통계 |      |
| count   | Parse, Execute, Fetch 각 단계가 수행된 횟수                  |      |
| cpu     | 현재 커서가 각 단계에서 사용한 cpu time                      |      |
| elapsed | 현재 커서가 각 단계를 수행하는 데 소요된 시간                |      |
| disk    | 디스크로부터 읽은 블록 수                                    |      |
| query   | Consistent 모드에서 읽은 버퍼 블록 수                        |      |
| current | Current모드에서 읽은 버퍼 블록수                             |      |
| rows    | 각 단계에서 읽거나 갱신한 처리건수                           |      |



###### Auto Trace의 실행통계 항목과 비교

| 실행 통계                         | Call        |
| :-------------------------------- | :---------- |
| db block gets                     | current     |
| consistent gets                   | query       |
| physical reads                    | disk        |
| SQL*Net roundtrips to/from client | fetch count |
| rows processed                    | fetch rows  |



- 오라클은 다양한 종류의 이벤트 트레이스를 제공하며 설정할 수 있는 레벨 값은 1,4,8,12로 설정 할 수 있음
- 레벨4 이상으로 설정할 경우 파일의 크기가 급격하게 커질 수 있으므로 주의해야함

| 레벨   | 설명                |
| :----- | :------------------ |
| 레벨1  | Default             |
| 레벨4  | Bind Values         |
| 레벨8  | Waits               |
| 레벨12 | Bind Values & Waits |



- Elapsed Time은 Call 단위로 측정이 이루어 짐

```
Elapsed Time = CPU Time + Wait Time
             = Response시점 - Call 시점
```



- SELECT문을 사용하는동안 3번의 Call이 발생하고 DML문은 2번의 Call이 발생함

```
* SELECT문 = Parse Call + Execute Call + Fetch Call 
* DML문    = Parse Call + Execute Call
```



- 하나의 SQL을 수행할 때 Total Elapsed Time은 수행 시 발생하는 모든 Call의 Elapsed Time을 더해서 구함
- 트레이스 레벨을 8로 설정 하면 이벤트 발생 현황까지 확인 가능함

| wait event                    | 설명                                                         |
| :---------------------------- | :----------------------------------------------------------- |
| SQL*Net message to client     | Client에게 메세지 송신후 Client로 부터 메세지 수신 완료 신호가 정해진 시간보다 늦게 도착한 경우 발생 |
| db file sequential read       | Single Block I/O 시 발생                                     |
| SQL*Net message from client   | 오라클 서버 프로세스가 사용자에게 결과를 전달하고 다음 Fetch Call이 올때 까지 대기한 시간을 더한 값 |
| SQL*Net more data from client | Client에게 전송할 데이터가 남았는데 네트워크 부하로 전송하지 못할 때 발생하는 대기 이벤트 |
