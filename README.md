# sqlp



## Outline

sqlp 자격증 취득 목적으로 oracle 옵티마이저, 튜닝 등을 정리

주제를 요약하며 각각 개념을 문서로 나누고, 실습예제를 따로 작성할 예정





## 1권

### [Section01 오라클아키텍처](docs/section01)

- [01-기본아키텍처](docs/section01/01-기본아키텍처.md)
- [02-DB버퍼캐시](docs/section01/02-DB버퍼캐시.md)
- [03-버퍼 Lock](docs/section01/03-버퍼Lock.md)
- [04-Redo](docs/section01/04-Redo.md)
- [05-Undo](docs/section01/05-Undo.md)
- [06-문장수준읽기일관성](docs/section01/06-문장수준읽기일관성.md)
- [07-Consistent-VS-Current](docs/section01/07-Consistent-VS-Current.md)
- [08-Block-CleanOut](docs/section01/08-Block-CleanOut.md)
- [09-Snapshot-too-old](docs/section01/09-Snapshot-too-old.md)
- [10-대기이벤트](docs/section01/10-대기이벤트.md)

### [Section02 트랜잭션과 Lock](docs/section02/00-outline.md)

- [01-트랜잭션동시성제어](docs/section02/01-트랜잭션동시성제어.md)
- [02-트랜잭션수준읽기일관성](docs/section02/02-트랜잭션수준읽기일관성.md)
- [03-비관적-vs-낙관적동시성제어](docs/section02/03-비관적-vs-낙관적동시성제어.md)
- [04-동시성구현사례](docs/section02/04-동시성구현사례.md)
- [05-오라클Lock](docs/section02/05-오라클Lock.md)

### [Section03 오라클 성능관리](docs/section03/00-outline.md)

- [01-ExplainPlan](docs/section03/01-ExplainPlan.md)
- [02-AutoTrace](docs/section03/02-AutoTrace.md)
- [03-SQL트레이스](docs/section03/03-SQL트레이스.md)
- [04-DBMS_XPLAN패키지](docs/section03/04-DBMS_XPLAN패키지.md)
- [05-VSYSSTAT](docs/section03/05-VSYSSTAT.md)
- [06-VSYSTEM_EVENT](docs/section03/06-VSYSTEM_EVENT.md)
- [07-Response-Time-Analysis방법론과OWI](docs/section03/07-Response-Time-Analysis방법론과OWI.md)
- [08-Statspack-And-AWR](docs/section03/08-Statspack-And-AWR.md)
- [09-ASH](docs/section03/09-ASH.md)
- [10-VSQL](docs/section03/10-VSQL.md)
- [11-End-To-End성능관리](docs/section03/11-End-To-End성능관리.md)
- [12-데이터베이스성능고도화정석해법](docs/section03/12-데이터베이스성능고도화정석해법.md)

### [Section04 라이브러리 캐시 최적화 원리](docs/section04/00-outline.md)

- [01-SQL과옵티마이저](docs/section04/01-SQL과옵티마이저.md)
- [02-SQL처리과정](docs/section04/02-SQL처리과정.md)
- [03-라이브러리캐시구조](docs/section04/03-라이브러리캐시구조.md)
- [04-커서공유](docs/section04/04-커서공유.md)
- [05-바인드변수의중요성](docs/section04/05-바인드변수의중요성.md)
- [06-바인드변수의부장용과해법](docs/section04/06-바인드변수의부장용과해법.md)
- [07-세션커서캐싱](docs/section04/07-세션커서캐싱.md)
- [08-애플리케이션커서캐싱](docs/section04/08-애플리케이션커서캐싱.md)
- [09-Static-VS-DynamicSQL](docs/section04/09-Static-VS-DynamicSQL.md)
- [10-DynamicSQL사용기준](docs/section04/10-DynamicSQL사용기준.md)
- [11-Static SQL 구현을 위한 기법들](docs/section04/11-StaticSQL구현을위한기법들.md)

## [Section05 ](docs/section05/00-outline.md)

- [01-Call통계](docs/section05/01-Call통계.md)
- [02-UserCall-VS-RecursiveCall](docs/section05/02-UserCall-VS-RecursiveCall.md)
- [03-데이터베이스Call이성능에미치는영향](docs/section05/03-데이터베이스Call이성능에미치는영향.md)
- [04-ArrayProcessing활용](docs/section05/04-ArrayProcessing활용.md)
- [05-FetchCall최소화](docs/section05/05-FetchCall최소화.md)
- [06-페이지처리의중요성](docs/section05/06-페이지처리의중요성.md)
- [07-PLSQL함수의특징과성능부하](docs/section05/07-PLSQL함수의특징과성능부하.md)
- [08-PLSQL함수호출부하해소방안](docs/section05/08-PLSQL함수호출부하해소방안.md)

## [Section06 ](docs/section06/00-outline.md)

- [01-블록단위IO](docs/section06/01-블록단위IO.md)
- [02-Memory-VS-DiskIO](docs/section06/02-Memory-VS-DiskIO.md)
- [03-SingleBlock-VS-MultiblockIO](docs/section06/03-SingleBlock-VS-MultiblockIO.md)
- [04-Prefetch](docs/section06/04-Prefetch.md)
- [05-DirectPathIO](docs/section06/05-DirectPathIO.md)
- [06-RAC캐시퓨전](docs/section06/06-RAC캐시퓨전.md)
- [07-Result캐시](docs/section06/07-Result캐시.md)
- [08-IO효율화원리](docs/section06/08-IO효율화원리.md)



## 2권

## [Section01 인덱스 원리와 활용](docs/section01)

- [01-인덱스구조](docs2/section01/01-인덱스구조.md)
- [02-인덱스기본원리](docs2/section01/02-인덱스기본원리.md)
- [03-다양한인덱스스캔방식](docs2/section01/03-다양한인덱스스캔방식.md)
- [04-테이블Random액세스부하](docs2/section01/04-테이블Random액세스부하.md)







## Etc

- [v$~ table](docs/table/Dynamic-Performance-View.md)





## Reference

[오라클성능고도화 원리화 해법1](https://product.kyobobook.co.kr/detail/S000061696047)

[오라클성능고도화 원리화 해법2](https://product.kyobobook.co.kr/detail/S000061696048)

[blog](http://www.gurubee.net/article/87748)

