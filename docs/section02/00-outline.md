# outline





1장에서 오라클 읽기 일관성에대해 살펴보았다.

DB2, SQL Server, Sybase 등은 Lock을 통해 읽기 일관성을 구현하지만,
오라클은 Undo를 이용했다.

데이터를 읽을 때 Lock을 사용하지 않으므로 상대적으로 동시성이 좋다.

그렇다고 동시성 개념을 몰라도 된다는건 아니다.



### 대기이벤트 분류

~~~sql
select wait_class, count(*)
from v$event_name
group by wait_class
order by 1;


/*
Administrative	59
Application	18
Cluster	75
Commit	5
Concurrency	59
Configuration	29
Idle	151
Network	30
Other	1492
Queueing	9
Scheduler	10
System I/O	40
User I/O	70
*/
~~~

- 오라클의 Lock경합 대부분을 차지하는 테이블락, 로우락 경합이 Concurrency가 아닌 Application으로 되어있다.
- DBA이슈가 아닌 개발자 이슈라는 뜻임
- 그니까, 1장에서 읽기일관성에 대해 오라클이 Lock에서 자유롭다고 해도, 실제 Lock이 발생하는 부분을 보면 개발자로서는 잘 알아야 하는 내용이라는 거다

~~~sql
select event#, name, wait_class
from v$event_name
where name in ('enq: TM - contention', -- DML 테이블 lock 경합
                'enq: TX - row lock contention', -- DML row lock 경합
                'SQL*Net break/reset to client') -- 존재하지 않는 테이블 혹은 pl/sql catch 발생
                
                
/*
305	enq: TM - contention	Application
311	enq: TX - row lock contention	Application
464	SQL*Net break/reset to client	Application
*/
~~~





해당 장은 기본적인 트랜잭션 개념, 동시성제어기법, 일관성과 동시성을 같이 높이는 방법, 오라클의 Lock메커니즘 에 대해 설명한다



