# 01. Call통계

- SQL 트레이스 레포트에서 Call 통계(Statistic)부분만을 발췌한 것이다.
  이 레포트는 커서의 활동상태를 Parse, Execute, Fetch 세 단계로 나누어 각각에 대한 수행통계를 보여준다.

```sql
select * from emp;

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.03          0          0          0           0
Execute      1      0.00       0.01          0          0          0           0
Fetch        2      0.00       0.00          0          8          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.01       0.04          0          8          0          14

Misses in library cache during parse: 1
```

- Parse Call은 커서를 파싱하는 과정에 대한 통계로서, 실행계획을 생성하거나 찾는 과정에 관한 정보를 포함한다.
- Execute Call은 말 그대로 커서를 실행하는 단계에 대한 통계를 보여준다.
- Fetch Call은 select문에서 실제 레코드를 읽어 사용자가 요구한 결과집합을 반환하는 과정에 대한 통계를 보여준다.



##### DML (insert, update, delete, merge)

- Execute Call 시점에 모든 처리과정을 서버내에서 완료하고 처리결과만 리턴하므로 Fetch Call이 전혀 발생하지 않는다.

```sql
delete from emp2


call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.01          0          1          0           0
Execute      1      0.00       0.00          0          3         17          14
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2      0.00       0.01          0          4         17          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54 
```



##### insert select

- 클라이언트로부터 명시적인 Fetch Call을 받지 않으며 서버 내에서 묵시적으로 Fetch가 이루어진다.

```sql
insert into emp2
select * from emp

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.02          0          8          5          14
Fetch        0      0.00       0.00          0          0          0           0
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        2      0.00       0.03          0          8          5          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54  
```



##### select

- Execute Call 단계에서는 커서만 오픈하고, 실제 데이터를 처리하는 과정은 모두 Fetch 단계에서 일어난다.

```sql
select * from  emp


call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch        2      0.00       0.00          0          8          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.00       0.00          0          8          0          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54 
```



##### for update

- for update 구문을 사용하면 Execute Call 단계에서는 모든 레코드를 읽어 Lock을 설정한다.

```sql
select * from
emp for update


call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.01       0.00          0          0          0           0
Execute      1      0.00       0.00          0          7         14           0
Fetch        2      0.00       0.00          0          8          0          14
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total        4      0.01       0.00          0         15         14          14

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 54
```