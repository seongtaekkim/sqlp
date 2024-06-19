# 02. SQL파싱부하



##  1) SQL 처리과정

- 사용자는 구조화된 질의언어(SQL, Structured Query Language)를 통해 사용자가 원하는 결과집합을 정의
- DBMS는 사용자의 SQL을 SQL옵티마이저를 통해 실행계획으로 작성해줌



```sql
Execution Plan 
---------------------------------------------------------- 
0 SELECT STATEMENT Optimizer=CHOOSE (Cost=209 Card=5 Bytes=175) 
1 0 TABLE ACCESS (BY INDEX ROWID) OF 'EMP' (Cost=2 Card=5 Bytes=85) 
2 1 NESTED LOOPS (Cost=209 Card=5 Bytes=175)
3 2 TABLE ACCESS (BY INDEX ROWID) OF 'DEPT' (Cost=207 Card=1 Bytes=18) 
4 3 INDEX (RANGE SCAN) OF 'DEPT_LOC_IDX'(NON-UNIQUE) (Cost=7 Card=1) 
5 2 INDEX (RANGE SCAN) OF 'EMP_DEPTNO_IDX'(NON-UNIQUE) (Cost=1 Card=5) 
```

- 위의 실행계획은 실제 실행 가능한 형태는 아니므로 코드 형태로 변환하는 과정을 거치고 나서 SQL 엔진에 의해 수행됨



##### 가. SQL 파싱(Parsing)

- SQL을 실행하면 제일먼저 SQL 파서(parser)가 SQL 문장에 문법적 오류가 없는지 검사(Syntax 검사)
- 문법적 오류가 없다면 의미상 오류가 없는지 검사(Semantic 검사, 오브젝트 존재유무등)
- 검사를 다 마치면, 사용자가 발생한 SQL과 그 실행계획이 라이브러리캐시(프로시저캐시)에 캐싱되어 있는지 확인
- 캐싱되어 있다면 소프트파싱, 캐싱되어있지 않다면 하드파싱



| 파싱종류                  | 설명                                                         |
| :------------------------ | :----------------------------------------------------------- |
| 소프트파싱 (Soft Parsing) | SQL과 실행계획을 캐시에서 찾아 곧바로 실행단계로 넘어가는 경우 |
| 하드파싱(Hard Parsing)    | SQL과 실행계획을 캐시에서 찾지 못해 최적화 과정을 거치고 나서 실행단계로 넘어가는 경우 |



- 라이브러리캐시는 해시 구조로 관리됨
  - SQL마다 해시값에 따라 여러 해시 버킷으로 나뉘며 저장되고, SQL을 찾을때는 SQL 문장을 해시 함수에 적용하여 반환되는 해시값을 이용하셔 해시 버킷을 탐색함.



##### 나. 최적화(Optimization)

- SQL 최적화를 담당하는 옵티마이저는 사용자가 요청한 SQL을 가장 빠르고 효율적으로 수행할 최적의(처리비용) 처리경로를 선택해 주는 DBMS의 핵심



###### 최적화 과정

- 예를들어 5개의 테이블을 조인한다면,순서만 고려해도 5!(=120)개의 실행계획 평가
- 120가지의 실행계획에 포함된 각 단계별 다양한 조인방식 고려
- 테이블을 full scan 할지 인덱스를 사용할지, 어떤 인덱스를 어떤방식으로 스캔할지 고려
  - 이와 같이 무거운 작업이므로 이러한 힘든과정을 거쳐 최적화된 SQL 실행계획을 한번만 쓰고 버린다면 엄청난 비효율이 발생한다.
  - 파싱과정을 거친 SQL과 실행계획이 여러 사용자가 공유해서 재사용 할수 있도록 공유메모리에 캐싱는 이유가 여기에 있다.



## 2) 캐싱된 SQL 공유

##### 가. 실행계획 공유 조건

- SQL 수행절차
  - 문법적 오류와 의미상 오류가 없는지 검사
  - 해시 함수로부터 반환받은 해시 값으로 라이브러리 캐시 내 해시버킷 탐색
  - 찾아간 해시버킷에 체인으로 연결된 엔트리를 차례로 스캔하면서 같은 SQL 문장 탐색
  - SQL문장을 찾으면 함께 저장된 실행계획을 가지고 바로 실행
  - 찾아간 해시 버킷에서 SQL 문장을 찾지 못하면 최적화를 수행
  - 최적화를 거친 SQL과 실행계획을 방금 탐색한 해시 버킷 체인에 연결
  - 방금 최적화한 실행계획을 가지고 실행



**중요**

- 하드파싱을 반복하지 않고 캐싱된 버전을 찾아 재사용하려면 SQL을 먼저 찾아가야 하며, 캐시에서 SQL을 찾기위해 사용되는 키값은 SQL 문장 그 차제
  => 이 때문에 SQL 문장안의 작은 공백 하나로도 DBMS는 서로 다른 SQL 문장으로 인식할수 있으므로 주의 해야함





##### 나. 실행계획이 공유하지 못하는 경우

- 1. 공백 또는 줄바꿈

```
SELECT * FROM CUSTOMER;
SELECT *    FROM CUSTOMER; 
```



- 2. 대문자 구분

```
SELECT * FROM CUSTOMER; 
SELECT * FROM Customer; 
```



- 3. 주석(Comment)

```
SELECT * FROM CUSTOMER; 
SELECT /* 주석문 */ * FROM CUSTOMER; 
```



- 4. 테이블 Owner 명시

```
SELECT * FROM CUSTOMER; 
SELECT * FROM HR.CUSTOMER; 
```



- 5. 옵티마이저 힌트사용

```
SELECT * FROM CUSTOMER;
SELECT /*+ all_rows */ * FROM CUSTOMER; 
```



- 6. 조건절 비교값

```
SELECT * FROM CUSTOMER WHERE LOGIN_ID = 'tommy'; 
SELECT * FROM CUSTOMER WHERE LOGIN_ID = 'karajan'; 
SELECT * FROM CUSTOMER WHERE LOGIN_ID = 'javaking'; 
SELECT * FROM CUSTOMER WHERE LOGIN_ID = 'oraking'; 
```



- 이러한 비효율을 줄이고 공유 가능한 형태로 SQL을 작성하려면 개발 초기에 SQL 작성표준을 정해서 이를 준수하도록 해야함*
- 6번처럼 조건절값을 문자열로 붙여가며 매번 다른 SQL로 실행되는 리터럴 SQL의 경우, 한가한 시간이라면 문제에 대해서 느끼지 못하겠지만, 사용자가 동시에 몰리는 시간대에는 장애상황으로 발생할 수도 있으므로 바인드변수의 사용을 고려해야함*



## 3) 바인드 변수 사용하기

##### 가. 바인드 변수의 중요성

- 사용자가 로그인을 하는 프로그램이 위의 6번과 같이 리터럴 SQL로 만들어져 있다면,
- 아래와 같이 로그인사용자가 생길때매다 프로시저가 하나씩 만들어지게 된다.

```sql
procedure LOGIN_TOMMY() { ... } 
procedure LOGIN_KARAJAN() { ... } 
procedure LOGIN_JAVAKING() { ... } 
procedure LOGIN_ORAKING() { ... } 
. 
. 
. 
```

- 이러한 경우 아래처럼 로그인 ID를 파라미터로 받아서 하나의 프로시저로 처리하도록 해야한다.



```
procedure LOGIN(login_id in varchar2) { ... } 
```

- 위와 같은 Driven 방식으로 SQL을 작성하는 방법이 제공되면 이것이 곧 바인드 변수이며,
- 이렇게 바인드 변수를 사용하면 하나의 프로시저를 공유하면서 반복 재사용 가능



```
SELECT * FROM CUSTOMER WHERE LOGIN_ID = :LOGIN_ID; 
```

- 위와 같이 바인드 변수를 사용하면 처음 수행한 세션이 하드파싱을 통해 실행계획을 작성
- 다른 세션들이 해당 SQL을 수행하면 라이브러리에 캐싱된 정보를 재사용함
- 캐시에서 실행계획을 얻어 입력한 값만 새롭게 바인딩하면서 바로 실행(소프트파싱)



###### 바인드변수를 사용했을때의 효과

- SQL과 실행계획을 반복적으로 재사용함으로써 파싱 소요시간과 메모리 사용량을 줄여줌
- 궁극적으로 시스테전반의 CPU 와 메모리 사용률을 낮춰 데이터베이스 성능과 확장성을 높임



###### 바인드 변수를 사용하지 않아도 되는 예외상황

- 배치프로그램이나 DW, OLAP 등 정보계 시스테에서 사용되는 Long Running 쿼리
  - 파싱 소요시간이 총 소요시간에서 차지하는 비중이 낮음
  - 수행빈도가 낮아 하드파싱에 의한 라이브러리 캐시 부하 유발 가능성이 낮음
  - 그러므로 상수조건절을 사용하여 옵티마이저가 컬럼히스토그램 정보를 활용할수 있도록 유도하는것이 유리함
- 조건절 컬럼의 값 종류(Distinct value)가 소수 일때
  - 분포도가 좋지 않은 값은 옵티마이저가 컬럼히스토그램 정보를 활용할수 있도록 유도.

- **이러한경우가 아니라면 OLTP 환경에서는 바인드 변수 사용을 권고함**



- 리터럴 SQL을 자동으로 변수화 시켜주는 기능

| ORACLE                                          | SQL Server                      |
| :---------------------------------------------- | :------------------------------ |
| cursor_sharing 파라미터 force 또는 similar 설정 | 단순매개 변수화 활성화(default) |

- 이러한 기능은 부작용도 만만치 않으므로 되도록이면 바인드 변수 사용 해야함



##### 나. 바인드변수 사용시 주의사항

- 칼럼의 분포가 균일할때는 바인드 변수 처리가 나쁘지 않음
- 칼럼의 분포가 균일하지 않을때에는 실행 시점에 바인딩되는 값에 따라 쿼리 성능이 다르게 나타날 수 있으므로 이럴때는 상수값을 사용하는것이 나을수 있음



##### 다.바인드 변수 부작용을 극복하기 위한 노력

- 바인드변수 Peeking 기능 도입 : 첫번째 바인드 변수값을 살짝 훔쳐보고 그 값에 대한 분포를 이용하여 실행계획 결정하는 기능



| 오라클              | SQL Server         |
| :------------------ | :----------------- |
| 바인드 변수 Peeking | Parameter Sniffing |



- 이또한 처음 훔쳐본값에 따라 실행계획이 수립되므로 위험한 기능이라고 할수 있음
- 대부분의 운영환경에서는 비활성화 시켜 사용하고 있음 (alter system set "_optim_peek_user_binds"=FALSE;)
- 오라클은 11g부터는 적응적 커서공유(Adaptive Cursor Sharing)를 도입하여 칼럼 분포에 따라 다른 실행계획이 사용되도록 처리하였지만 이또한 완전한 기능이 아니므로 주의해서 사용해야 한다.



## 4) Static SQL과 Dynamic SQL

##### 가. Static SQL

- String형 변수에 담지 않고 코드 사이에 직접 기술한 SQL문(Embedded SQL)
- 개발언어 : PowerBuilder, PL/SQL, Pro*C, SQLJ

```sql
Proc*C 구분으로 Static SQL 작성한 예시
int main() 
{ 
  printf("사번을 입력하십시오 : "); 
  scanf("%d", &empno); 
  EXEC SQL WHENEVER NOT FOUND GOTO notfound; 
  EXEC SQL SELECT ENAME INTO :ename 
           FROM EMP 
           WHERE EMPNO = :empno; 
  printf("사원명 : %s.\n", ename); 

notfound: 
  printf("%d는 존재하지 않는 사번입니다. \n", empno); } 
```



- SQL문을 String 변수에 담지 않고 마치 예약된 키워드처럼 C/C++ 코드 사이에 섞어 기술
- 구문분석, 유효 오브젝트 여부, 오브젝트 엑세스 권한등의 체크 가능



##### 나. Dynamic SQL

- String 형 변수에 담아서 기술하는 SQL문

```sql
int main() 
{ 
   char select_stmt[50] = "SELECT ENAME FROM EMP WHERE EMPNO = :empno"; 
   // scanf("%c", &select_stmt); → SQL문을 동적으로 입력 받을 수도 있음

   EXEC SQL PREPARE sql_stmt FROM :select_stmt; 

   EXEC SQL DECLARE emp_cursor CURSOR FOR sql_stmt; 
   
   EXEC SQL OPEN emp_cursor USING :empno; 

   EXEC SQL FETCH emp_cursor INTO :ename; 
   
   EXEC SQL CLOSE emp_cursor; 

   printf("사원명 : %s.\n", ename); 
} 
```

- 조건에 따란 SQL이 동적으로 바뀔수 있으므로 syntax, semantics 체크 불가능



##### 다. 바인드 변수의 중요성 재강조

- Static를 사용하든 Dynamic SQL을 사용하든 옵티마이저는 SQL 문장 자체만을 인식할 뿐이므로 성능에 영향을 주지는 않는다.
- 라이브러리 캐시 효율은 Static이냐 Dynamic의 차이가 아니라 바인드 변수의 사용여부에 초점을 맞춰야 함.



### 5) 애플리케이션 커서 캐싱

- 같은 SQL을 여러번 반복해서 수행해야할 때, 첫번째는하드파싱이 일어나겠지만 이후부터는 라이브러리 캐시에 공유되 버전을 찾아 가볍게 실행한다.
- 하지만 그렇다더라도 SQL문장의 문법적, 의미적 오류를 확인하고 해시함수로부터 반환된 해시값을 이요해서 캐시에서 실행계획을 찾고, 수행이 필요한 메모리를 할당받는 등의 작업이 매번 반복되면 비효율이 발새할 것이다.
- 이러한 과정을 생략하고 빠르게 SQL을 수행하는 방법이 바로 **"애플리케이션 커서 캐싱"** 이다.
- 개발언어마다 구현방식이 다르므로 이 기능을 활용하려면 API를 살펴봐야함.



- 애플리케이션 커서 캐싱 예시( Proc*C)

```
for(;;) { 
   EXEC ORACLE OPTION (HOLD_CURSOR=YES); 
   EXEC ORACLE OPTION (RELEASE_CURSOR=NO); 
   EXEC SQL INSERT ...... ; // SQL 수행
   EXEC ORACLE OPTION (RELEASE_CURSOR=YES); 
} 
```



- 애플리케이션에서 커서를 캐싱한 상태에서 SQL 5,000 반복 수행 했을때 SQL 트레이스

```
call    count cpu  elapsed  disk query current rows 
----- ------ ----- ------- ----- ------- ------ ----- 
Parse      1  0.00    0.00     0      0       0     0 
Execute 5000  0.18    0.14     0      0       0     0 
Fetch   5000  0.17    0.23     0  10000       0  5000 
----- ------ ----- -------  ----- ------- ------  ----- 
total 10001 0.35 0.37 0 10000 0 5000 

Misses in library cache during parse: 1 
```



- 일반적으로 SQL을 반복 수행할 때에는 Parse Call 횟수가 Execute Call 횟수와 같지만
- 위의 결과는 Parse Call 한번만 발생했고, 이후 4,999번 수행할 때에도 Parse Call이 전혀 발생하지 않았음

- JAVA에서 위의 기능을 구현하기 위한 방법 : 묵시적캐싱 옵션 사용(Implicit Caching)

```
public static void CursorCaching(Connection conn, int count) throws Exception{ 
  // 캐시 사이즈를 1로 지정 
  ((OracleConnection)conn).setStatementCacheSize(1); 
  // 묵시적 캐싱 기능을 활성화 ((OracleConnection)conn).setImplicitCachingEnabled(true); 

  for (int i = 1; i <= count; i++) { 
    // PreparedStatement를 루프문 안쪽에 선언 
    PreparedStatement stmt = conn.prepareStatement( 
      "SELECT ?,?,?,a.* FROM emp a WHERE a.ename LIKE 'W%'"); stmt.setInt(1,i); 
    stmt.setInt(2,i); stmt.setString(3,"test"); 
    ResultSet rs=stmt.executeQuery(); 
    
    rs.close(); 
    
    // 커서를 닫더라도 묵시적 캐싱 기능을 활성화 했으므로 닫지 않고 캐시에 보관하게 됨 
    stmt.close(); 
  } 
  } 
```



- 또는 아래처럼 Statement를 닫지 않고 재사용해도 같은 효가를 얻을 수 있음

```
public static void CursorHolding(Connection conn, int count) throws Exception{ 

  // PreparedStatement를 루프문 바깥에 선언 
  PreparedStatement stmt = conn.prepareStatement( 
    "SELECT ?,?,?,a.* FROM emp a WHERE a.ename LIKE 'W%'"); 
  ResultSet rs; 

   for (int i = 1; i <= count; i++) { 
      stmt.setInt(1,i); 
      stmt.setInt(2,i); 
      stmt.setString(3,"test");
      rs=stmt.executeQuery(); 
      rs.close(); 
   } // 루프를 빠져 나왔을 때 커서를 닫는다.
     stmt.close();
}
```



- 위와 같이 옵션을 별도로 적용하지 않더라도 자동적으로 커서를 캐싱함(단, Stastic SQL 사용시에만)
- Dynamic SQL을 사용하거나 Cursor Variable(=Ref Cursor)를 사용할 때는 커서를 자동으로 캐싱하는 효과가 사라짐
