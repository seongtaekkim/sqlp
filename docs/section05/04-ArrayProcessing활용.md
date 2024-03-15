# 04. Array Processing 활용



Array Processing 기능을 활용하면 한 번의 SQL 수행으로 다량의 로우를 동시에 insert/update/delete 할 수 있다.

네트워크를 통한 데이터베이스 Call을 감소시켜주고, 궁극적으로 SQL 수행시간과 CPU 사용량을 획기적으로 줄여준다.



### 예제1 - java)

```java
public class JavaArrayProcessing{ 
  public static void insertData( Connection con 
                               , PreparedStatement st 
                               , String param1 
                               , String param2 
                               , String param3 
                               , long param4) throws Exception{ 
    st.setString(1, param1); 
    st.setString(2, param2); 
    st.setString(3, param3); 
    st.setLong(4, param4); 
    *st.addBatch();* 
  } 
 
  public static void execute(Connection con, String input_month)  
  throws Exception { 
    long rows = 0; 
    String SQLStmt1 = "SELECT 고객번호, 납입월" 
                    + "     , 지로, 자동이체, 신용카드, 핸드폰, 인터넷 " 
                    + "FROM   월요금납부실적 " 
                    + "WHERE  납입월 = ?"; 
                    
    String SQLStmt2 = "INSERT /*+ test3 */ INTO 납입방법별_월요금집계  "  
            + "(고객번호, 납입월, 납입방법코드, 납입금액) " 
            + "VALUES(?, ?, ?, ?)"; 
 
    con.setAutoCommit(false); 
 
    PreparedStatement stmt1 = con.prepareStatement(SQLStmt1); 
    PreparedStatement stmt2 = con.prepareStatement(SQLStmt2); 
    *stmt1.setFetchSize(1000);* 
    stmt1.setString(1, input_month); 
    ResultSet rs = stmt1.executeQuery(); 
    while(rs.next()){ 
      String 고객번호 = rs.getString(1); 
      String 납입월 = rs.getString(2); 
      long 지로 = rs.getLong(3); 
      long 자동이체 = rs.getLong(4); 
      long 신용카드 = rs.getLong(5); 
      long 핸드폰 = rs.getLong(6); 
      long 인터넷 = rs.getLong(7); 
      if(지로 > 0)     insertData (con, stmt2, 고객번호, 납입월, "A", 지로); 
      if(자동이체 > 0) insertData (con, stmt2, 고객번호, 납입월, "B", 자동이체); 
      if(신용카드 > 0) insertData (con, stmt2, 고객번호, 납입월, "C", 신용카드); 
      if(핸드폰 > 0)   insertData (con, stmt2, 고객번호, 납입월, "D", 핸드폰); 
      if(인터넷 > 0)   insertData (con, stmt2, 고객번호, 납입월, "E", 인터넷); 
      *if(++rows%1000 == 0) stmt2.executeBatch();* 
    } 
 
    rs.close(); 
    stmt1.close(); 
 
    *stmt2.executeBatch();* 
    stmt2.close(); 
 
    con.commit(); 
    con.setAutoCommit(true); 
  } 
 
  public static void main(String[] args) throws Exception{ 
    long btm = System.currentTimeMillis(); 
    Connection con = getConnection(); 
    execute(con, "200903"); 
    System.out.println("elapsed time : " + (System.currentTimeMillis() - btm)); 
    releaseConnection(con); 
} 
```



~~~sql

- 트레이스 결과 
 
SELECT 고객번호, 납입월, 지로, 자동이체, 신용카드, 핸드폰, 인터넷 
FROM 월요금납부실적 WHERE 납입월 = :1 
 
 
call     count       cpu    elapsed       disk      query    current        rows 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
Parse        1      0.00       0.00          0          0          0           0 
Execute      1      0.01       0.01          0         71          0           0 
Fetch       31      0.00       0.04          0        169          0       30000 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
total       33       0.01      0.04          0         240          0       30000 
 
Misses in library cache during parse: 1 
Misses in library cache during execute: 1 
Optimizer mode: ALL_ROWS 
Parsing user id: 54 
 
Rows     Row Source Operation 
-------  --------------------------------------------------- 
  30000  TABLE ACCESS FULL 월요금납부실적 (cr=169 pr=0 pw=0 time=90083 us) 
 
 
INSERT INTO 납입방법별_월요금집계  
(고객번호, 납입월, 납입방법코드, 납입금액) 
VALUES (:1 , :2 , :3 , :4 ) 
 
 
call     count       cpu    elapsed       disk      query    current        rows 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
Parse        1      0.00       0.00          0          0          0           0 
Execute     30      0.18       0.27          2        923       5094      150000 
Fetch        0      0.00       0.00          0          0          0           0 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
total        31      0.18       0.27          2        923       5094      150000 
 
Misses in library cache during parse: 1 
Misses in library cache during execute: 1 
Optimizer mode: ALL_ROWS 
Parsing user id: 54
~~~

- 150,000(30,000*5)건을 insert 하는데 단 1.21초 만에 수행
- insert 문에 대한 Execute Call이 30회만 발생
- insert 된 로우 수가 150,000건이므로 매번 5,000건씩 Array Processing한 것.
  (커서에서 Fetch되는 각 로우마다 5번씩 insert를 수행하는데, 1,000 로우마다 한번식 executeBatch를 수행하기 때문)
- select 결과를 Fetch 할 때도 1,000개 단위로 Array Fetch 하도록 조정. (JAVA에서 기본값은 10)
- 30,000건을 읽는데 Fetch Call이 31회만 발생.

- 네트워크를 경유해 발생하는 데이터베이스 Call이 얼마맡큼 심각한 성능부하를 일으키는 지 ?수 있다.
- One-SQL로 통합하지 않더라도 Array Processing 만으로 그에 버금가는 성능개선 효과를 얻을 수 있다.
- Array Processing의 효과를 극대화하려면 연속된 일련의 처리과정이 모두 Array 단위로 진행 되어야 한다.



### 예제2) PL/SQL Bulk insert

```sql
DECLARE 
  l_fetch_size NUMBER DEFAULT 1000;  -- 1,000건씩 Array 처리 
 
  CURSOR c IS  
    SELECT empno, ename, job, sal, deptno, hiredate  
    FROM   emp; 
 
  TYPE array_empno      IS TABLE OF emp.empno%type; 
  TYPE array_ename      IS TABLE OF emp.ename%type; 
  TYPE array_job        IS TABLE OF emp.job%type; 
  TYPE array_sal        IS TABLE OF emp.sal%type; 
  TYPE array_deptno     IS TABLE OF emp.deptno%type; 
  TYPE array_hiredate   IS TABLE OF emp.hiredate%type; 
 
  l_empno     array_empno     := array_empno   (); 
  l_ename     array_ename     := array_ename   (); 
  l_job       array_job       := array_job     (); 
  l_sal       array_sal       := array_sal     (); 
  l_deptno    array_deptno    := array_deptno  (); 
  l_hiredate  array_hiredate  := array_hiredate(); 
 
  PROCEDURE insert_t( p_empno     IN array_empno    
                    , p_ename     IN array_ename    
                    , p_job       IN array_job      
                    , p_sal       IN array_sal      
                    , p_deptno    IN array_deptno   
                    , p_hiredate  IN array_hiredate ) IS 
 
  BEGIN 
    *FORALL i IN p_empno.first..p_empno.last* 
      *INSERT INTO emp2* 
      VALUES ( p_empno   (i) 
             , p_ename   (i) 
             , p_job     (i) 
             , p_sal     (i) 
             , p_deptno  (i) 
             , p_hiredate(i) ); 
 
  EXCEPTION 
    WHEN others THEN 
      DBMS_OUTPUT.PUT_LINE(SQLERRM); 
      RAISE; 
  END insert_t; 
 
BEGIN 
 
  OPEN c; 
 
  LOOP 
 
    *FETCH c BULK COLLECT* 
    *INTO l_empno, l_ename, l_job, l_sal, l_deptno, l_hiredate* 
    *LIMIT l_fetch_size;* 
 
    insert_t( l_empno, l_ename, l_job, l_sal, l_deptno, l_hiredate ); 
 
    EXIT WHEN c%NOTFOUND; 
  END LOOP; 
 
  CLOSE c; 
 
  COMMIT; 
 
EXCEPTION 
  WHEN OTHERS THEN 
    ROLLBACK; 
END; 
/
```

- SQL 트레이스 결과를 보면, 10,000건을 처리하는데 select문의 Fetch Call과 insert문의 Execute Call이 각각 10번씩만 발생한 것을 알 수 있다.
  (select의 Fetch Call이 11번이 발생한 것은 데이터가 더 있는지 확인하기 위한 것임)
- EXP, IMP 명령을 통해 데이터를 Export, Import 할 때도 내부적으로 Array Proccessing이 활용
  (buffer 옵션으로 지정가능, byte 단위로 지정 = rows_in_array * maximum_row_size)
- Array Processing을 지원하는 인터페이스가 프로그램 언어별로 각기 다르므로 API를 통해 확인하고 이를 활용할 것.