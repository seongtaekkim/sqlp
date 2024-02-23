# 01. Explain Plan



Explain Plan은 SQL을 수행하기 전 실행계획을 의미하며 이 실행계획을 확인하고자 할때 Explain Plan 명령어를 사용



| 구분     | 내용                                                         |
| :------- | :----------------------------------------------------------- |
| 10g 이전 | 스크립트 실행: $ORACLE_HOME/rdbms/admin/utlxplan.sql         |
| 10g 이후 | 설치 시 기본적으로 테이블(sys.plan_table$)과 public synoym(plan_table) 생성 |



### Explain Plan 생성

- Explain Plan을 생성하려면&nbsp;`@?/rdbms/admin/utlxplan.sql` 을 실행
  - 참고로 ? 는 $ORACLE_HOME 디렉토리를 대체하는 기호
- Oracle 10g 부터는 설치 시 기본적으로 sys.plan_table$를 제공하므로 별도의 Plan Table을 생성하지 않아도 됨



##### Explain Plan For 명령어를 수행을 통해 Plan_Table에 실행계획을 저장 할 수 있음

- set statement_id ='query1' 는 생략 가능함
- 9i 이전에는 plan_table를 직접 쿼리, 9i부터는 아래 오라클에서 제공하는 스크립트로 확인 가능
- utlxpls 싱글 실행 계획, utlxplp 병렬 실행 계획

```sql
set linesize 200 
Explain plan set statement_id ='query1' for 
select * from emp where empno = 7900; 

해석되었습니다.

SQL > @?/rdbms/admin/utlxpls

Plan hash value: 2949544139

--------------------------------------------------------------------------------------
| Id  | Operation		    | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT	    |	     |	   1 |	  38 |	   1   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| EMP    |	   1 |	  38 |	   1   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN	    | PK_EMP |	   1 |	     |	   0   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------

   2 - access("EMPNO"=7900)
```

- 쿼리로 직접 조회

~~~SQL
SELECT owner, synonym_name, table_owner, table_name
  FROM all_synonyms
  WHERE synonym_name = 'PLAN_TABLE'
  ;
  
  -- PUBLIC	PLAN_TABLE	SYS	PLAN_TABLE$


SELECT lpad(id, 4, ' ') || NVL(LPAD(parent_id, 6, ' '), '       ')
       || ' ' || lpad(' ', (LEVEL - 1) * 2, ' ')
        || operation || NVL2(options, ' ( ' || options || ' ) ', '')
        || NVL2(object_name, ' OF '''
        || object_owner || '.' || object_name, NULL)
        || NVL2(object_name, '''', '')
        || decode(parent_id, NULL, ' Optimizer=' || optimizer)
        || (CASE
        WHEN cost IS NULL AND cardinality IS NULL AND bytes IS NULL
          THEN ''
          ELSE '(' || NVL2(cost, 'Cost=' || cost, '')
               || NVL2(cardinality, 'Card=' || cardinality, '')
               || NVL2(bytes, 'Bytes=' || bytes, '')
               || ')' END) "Execution Plan"
FROM   plan_table p
START WITH statement_id = 'query1' AND id = 0
CONNECT BY PRIOR id = parent_id AND PRIOR statement_id = statement_id
ORDER BY id;


Execution Plan
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   0	    SELECT STATEMENT Optimizer=ALL_ROWS(Cost=1Card=1Bytes=38)
   1	 0   TABLE ACCESS ( BY INDEX ROWID )  OF 'SYS.EMP'(Cost=1Card=1Bytes=38)
   2	 1     INDEX ( UNIQUE SCAN )  OF 'SYS.PK_EMP'(Cost=0Card=1)
~~~

- 실행계획을 별도 테이블로 저장하여 시스템 운영 및 성능관리에 활용
  - sql_repository에 저장된 모든 sql의 실행계획을 plan table에 저장하는 스크립트

~~~sql
 drop table sql_repository;
 select * from sql_repository;
 
 CREATE TABLE SQL_repository(SQL_id VARCHAR2(30), SQL_text VARCHAR2(4000));

 insert into sql_repository values ('query1', 'select * from emp where empno = 7900 ');

BEGIN
  FOR c IN (SELECT sql_id, sql_text from SQL_repository)
  LOOP
    EXECUTE IMMEDIATE 'explain plan set statement_id = ''' || c.sql_id
            ||  ''' for ' || c.sql_text;
    COMMIT;
  END LOOP;
END;
/
~~~





##### Predicate Information 은 아래와 같이 세 가지 유형이 존재함

- 인덱스 Access Predicate : 인덱스를 통해 스캔의 범위를 결정하는데 영향을 미치는 조건절
- 인덱스 Filter Predicate : 인덱스를 통했으나 스캔의 범위를 결정하는 영향을 미치지 못하는 조건절
- 테이블 Access Predicate : NL 조인을 제외한 조인에서 발생하며 결과 값의 범위를 결정하는데 영향을 미치는 조건절
- 테이블 Filter Predicate : 테이블 스캔 후 최종 결과 집합 포함 여부를 결정하는데 영향을 미치는 조건절



- Explain Plan For 명령어를 통해 실행계획을 별도로 저장해 둔다면 이를 활용해 안정적인 시스템 운영 및 성능관리에 활용 할 수 있음
- 인덱스 구조 변경 시 사용하는 SQL을 뽑아 사전점검
- 통계정보 변경 등으로 인한 이유로 갑자기 성능이 나빠질 경우 이전 실행계획을 확인하고 예전과 같은 방식으로 수행되도록 할 수 있음
