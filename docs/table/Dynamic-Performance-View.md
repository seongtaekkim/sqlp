# Dynamic Performance View

- 오라클 인스턴스가 동작할때마다 자동 갱신되는 View.
- 오라클의 상태, 성능, 모니터링, 감사 등을 위한 View.



## V$SESSION

- 현재 세션에 대한 정보.

| no   | column id | domain                   |
| ---- | --------- | ------------------------ |
| 1    | OSUSER    | os hostname              |
| 2    | TYPE      | BACKGROUND, USER PROCESS |
| 3    | STATUS    | ACTIVE, INACTIVE         |
| 4    | ADDR      | 메모리 주소              |





## V$PROCESS

- 현재 작업중인 프로세스에 대한 정보. LATCHWAIT 칼럼은 프로세스잠금이 무엇을 기다려야하는가를 나타내며, LATCHSPIN 칼럼은 프로세스잠금이 동작되는 것을 나타낸다. 멀티프로세서의 경우 Oracle 프로세스는 잠금을 기다리기전에 실시한다.



| NO   | COLOUME ID | COLOUME NAME         | DOMAIN           |
| ---- | :--------- | -------------------- | ---------------- |
| 1    | ADDR       | 프로세스 메모리 주소 | 000000007C5A4DC0 |
| 2    | PID        | 프로세스 ID          |                  |
| 3    | SPID       | OS 프로세스 ID       |                  |
| 4    | USERNAME   | OS 유저 이름         | staek            |







## V$BGPROCESS

- 백그라운드 프로세스 정보.

| NO   | COLOUME ID  | DOMAIN |
| ---- | ----------- | ------ |
| 1    | NAME        |        |
| 2    | PADDR       |        |
| 3    | DESCRIPTION |        |

















