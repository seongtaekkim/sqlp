# 09. Static-VS-DynamicSQL



## 1. Static SQL (Embedded SQL)

1. String 형 변수에 쿼리 문장을 담지 않고 코드 사이에 직접 기술 다른 말로 `Embedded SQL` 이라고도 한다.
2. Pre컴파일러가 PreCompile 과정 에서 Static SQL을 발견 하면 함수를 호출 할 수 있는 코드로 변환함.
3. **런타임 시에 절대 변하지 않아 PreCompile 단계에서 구문 분석, 유효 오브젝트 여부, 오브젝트 액세스 권한 등을 체크하는 것이 가능**



```c
void main(){
   printf("사번을 입력하시오 : ");
   scanf("%d"  ,&empno);                //사번 입력
   EXEC SQL WHENEVER NOT FOUND GOTO notfound;
   EXEC SQL SELECT ENAME INTO :ename    //변수에 담지 않고 바로 기술
              FROM EMP
            WHERE EMPNO = :empno;
   printf("사원명 : %s.\n",ename);
notfound:
   printf("%d는 존재하지 않는 사번입니다.\n",empno);
}
```







## 2. Dynamic SQL

1. String 변수에 담아서 처리하는 SQL문 즉 변수를 사용 하므로서 쿼리문을 동적으로 바꿀수 있으며 런타임시에 사용자가 SQL에 대해서 입력(전체 입력 및 변경)이 가능
2. 위의 이유로 PreCompiler시 문법에 체크(Syntax)/권한체크(Semantics) 가 불가능
3. Semeantic 체크는 DB 접속을 통해 이루어지지만 Syntanx 체크는 PreCompiler에 내장된 SQL파서를 이용 하는데 아래와 같은 구문을 사용 하면 현재 사용 중인 PreCompiler가 인식 하지 못해 에러를 발생 한다면, Dynamic SQL로 변경하여 해결할수 있다.

```sh
$ proc test.pc sqlcheck=syntax : success
$ proc test.pc sqlcheck=full userid=scott/tiger : Semantics error
```



##### Pro*C 예제

```c
void main(){
	char selectId[50] = "SELECT * FROM EMP WHERE EMPNO = :empno"; //바인드 변수사용하고, SQL을 String 변수에 담는다.
	EXEC SQL PREPARE sql_stmt FROM :selectId ; /* SQL 문장을 정의 */

	EXEC SQL DECLARE emp_cursor CURSOR SQL sql_stmt ; /* 커서 선언 */

	EXEC OPEN emp_cursor USING :empno ; /* 커서 열기 : 실제 실행 단계가 아님 */

	EXEC FETCH emp_cursor INTO :ename ; /* 쿼리문 실행 */

	EXEC CLOSE emp_cursor ; /* 커서 닫기 : 닫지 않을 경우 비정상적 오류 발생 */
	Printf("사원명 : %s.\n", ename);
}
```



##### Pro*C에서 제공하는 Dynamic Method 4가지 방법

```
Method 1. 입력 Host변수 없는 Non-Query(SELECT 문 제외)
  1) DELETE FROM EMP WHERE EMPNO=20
  2) ALTER USER SCOTT ACCOUNT UNLOCK;

Method 2. Host 변수가 고정적일 경우 Non-Query(SELECT 문 제외)
  1) INSERT INTO EMP(EMPNO, ENAME) VALUES(:empno, :ename);
  2: DELETE FROM DEPTNO WHERE DEPTNO = :deptno;

Method 3.select-list의 컬럼 갯수와 Host변수가 고정적일때
  1) SELECT DEPTNO, COUNT('X') AS CNT FROM EMP GROUP BY DEPTNO; --컬럼의 갯수가 고정적
  2) SELECT DEPTNO, DNAME FROM DEPT WHERE DEPTNO=20;--컬럼의 갯수가 고정적
  3) SELECT ENAME, EMPNO FROM EMP WHERE DEPTNO=:deptno --컬럼의 갯수 및 Host 변수가 고정적

Method 4. select-list의 컬럼의 갯수와 Host 변수가 가변적
  1) INSERT INTO EMP(....) VALUES(....);
  2) SELECT .... FROM EMP WHERE EMPNO=:empno; --컬럼의 갯수가 고정적
```





## 3. 일반프로그램 언어에서 SQL작성 방법

- Static SQL : PowerBuilder, PL/SQL, Pro*C, SQLJ
- Dynamic SQL : String 에 담는 모든것 ( 자바, Delphi,  Vaisual Basic, Toad, Orange, SQL*PLUS 등 )
- 아래 두 언어만 보더라도 Static SQL 작성 방법은 제공 되지 않는다.

##### 자바

```java
public void preCursorCaching(int cnt)throws Exception{
	((OracleConnection)conn).setStatementCacheSize(1);
	((OracleConnection)conn).setImplicitCachingEnabled(true);

	for( int i = 0; i < cnt; i ++){
		PreparedStatement pstmt = conn.prepareStatement(" SELECT a.* *,?, ?, ?* FROM EMP a WHERE a.ENAME LIKE 'W%' ");
		pstmt.setInt(1, i);
		pstmt.setInt(2, i);
		pstmt.setString(3, "test");
		ResultSet rs = pstmt.executeQuery();
		rs.close();
		pstmt.close();
	}
}
```



##### Delphi

```java
begin
  Query1.Close;
  Query1.Sql.Clear;
  Query1.Sql.Add('SELECT ENAME, SAL FROM EMP ');
  Query1.Sql.Add('WHERE EMPNO = :empno');
  Query1.ParamByuName('empno').AsString := txtEmpno.Text;
  Query1.Open;
end;
```



## 4. 문제의 본질은 바인드 변수 사용 여부

- Static SQL이던 Dynamic SQL이던 DBMS입장에서는 SQL문 그자체만 인식 할 뿐이므로 애플리케이션 커서 캐싱 기능을 활용하고자 하는 경우 외에는 성능에 전혀 영향이 없다.
  - 애플리케이션 커서 캐싱 기능은 Static SQL일때만 사용 가능.
- **라이브러리 캐쉬 효율을 논할 때는 바인드 변수 사용 여부에 맞춰져야 한다.**
  - 변수를 문자와 결합 하므로서 얼마나 하드 파싱이 일어나 성능이 저하가 되는지, 라이브러리 캐시에 얼마나 심한 경합이 발생에 따라 바인드 변수의 사용 여부에 초점을 맞춰 작성을 해야 한다.
