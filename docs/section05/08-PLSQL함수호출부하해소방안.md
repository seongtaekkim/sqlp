# 08. PLSQL함수호출 부하 해소방안



- ###### 사용자정의 함수의 사용범위

  1. 소량의 데이터 조회시
  2. 대용량 데이터를 조회 할때는 부분범위 처리가 가능한 상황에서 제한적으로
  3. 조인 또는 스칼라 서브쿼리 형태로 변환하려는 노력이 필요
  4. 어쩔 수 없을 때는 사용하지만, 호출 횟수를 최소화 할수 있는방법을 강구





## 1) 페이지 처리 또는 부분범위 처리활용

부분범위처리가 가능한 상황이라면 클라이언트에게 데이터를 전송하는 맨 마지막 단계에 사용자함수 호출이 일어나도록 하라.



#### 기존

- 전체 레코드 건수만큼 사용자함수 호출을 일으키고 그 결과 집합을 Sort Area  또는 Temp 테이블 스페이스 에 저장한다. 그리고 최종 결과집합 10건만 전송한다. 

~~~sql

Select *  
From ( 
 Select memb_nm(매수회원번호) 매도 회원명  
      ,memb_nm(매수회원번호)  매수회원명 
      ,code_nm('446' , 매도 투자자 구분코드) 매도투자자구분명 
      ,code_nm('446' , 매수 투자자 구분코드) 매수투자자구분명 
      ,code_nm('418' , 체결 유형코드) 체결 유형명 
 . . . . . . . 
 From 체결 
 Where 종목코드 = : 종목코드 
 And   체결일자 = : 체결일자  
 And   체결시간 between sysdate-10/21/60 and sysdate 
 Order by 체결시각 desc 
     ) a 
     Where rownum <= 30  
   ) 
Where no between 21 and 30 
) 
~~~



#### 변경 후

- Order by 와 rownum에 의한 필터 처리 후 사용자에게 전송하는 결과 집합에 대해서만 함수 호출이 일어난다.

~~~sql
select   memb_nm(매수회원번호) 매도 회원명  
 ,memb_nm(매수회원번호)  매수회원명 
 ,code_nm('446' , 매도 투자자 구분코드) 매도투자자구분명 
 ,code_nm('446' , 매수 투자자 구분코드) 매수투자자구분명 
 ,code_nm('418' , 체결 유형코드) 체결 유형명 
 . . . . . . . 
from ( 
 Select rownum no, a.* 
 From 매도회원번호, 매수 회원번호 
 , 매도투자자구분코드, 매수 투자자구분코드 
 . . . . . . . . . . . . .  
 from 체결 
 Where 종목코드 = : 종목코드 
 And   체결일자 = : 체결일자  
 And   체결시간 between sysdate-10/21/60 and sysdate 
 Order by 체결시각 desc 
 ) a 
     Where rownum <= 30  
   ) 
Where no between 21 and 30 
) 
~~~





## 2) Decode, Case 함수 문으로 변환

- 함수가 안쪽 인라인 뷰에서 order by 절에 사용된다든가, 전체 결과집합을 모두 출력하거나, insert ... select 문에서 사용된다면 다량의 함수 호출을 피할 수 없다.
- 이럴경우 함수 로직을 풀어서 decode, case문으로 전환하거나 조인문으로 구현할 수 있는지 먼저 확인해야 한다.
- 함수를 사용해야 하는 상황이라면 함수에 입력되는 값의 종류가 얼마나 되는지 확인해 보라.
- 값의 종류가 많지 않다면 함수를 그대로 둔 채 스칼라 서브쿼리의 캐싱 효과를 이용하는 것만으로도 큰 효과를 볼 수 있다.



~~~sql
- 체결 테이블 생성  
CREATE TABLE 체결(체결일자, 체결번호, 시장코드, 증권그룹코드, 체결수량, 체결금액) 
NOLOGGING 
AS 
SELECT '20090315' 
     , ROWNUM  
     , DECODE(SIGN(ROWNUM-100000), 1, 'ST', 'KQ')        -- 유가증권, 코스닥  
     , DECODE(MOD(ROWNUM, 8), 0, 'SS', 1, 'EF', 2, 'EW'  -- 주식, ETF, ELW 
                            , 3, 'DR', 4, 'SW', 5, 'RT'  -- DR, 신주인수권, 리츠 
                            , 6, 'BC', 7, 'MF')          -- 수익증권, 투자회사 
     , ROUND(DBMS_RANDOM.VALUE(10, 1000), -1)  
     , ROUND(DBMS_RANDOM.VALUE(10000, 1000000), -2)  
FROM   DUAL 
CONNECT BY LEVEL <= 500000 
UNION ALL 
SELECT '20090315' 
     , ROWNUM + 300000  
     ,(CASE WHEN MOD(ROWNUM, 4) < 2 THEN 'SD' ELSE 'GD' END) 
     ,(CASE WHEN MOD(ROWNUM, 4) IN (0, 2) THEN 'FU' ELSE 'OP' END) 
     , ROUND(DBMS_RANDOM.VALUE(10, 1000), -1)  
     , ROUND(DBMS_RANDOM.VALUE(10000, 1000000), -2)  
FROM   DUAL 
CONNECT BY LEVEL <= 500000 
; 
 
- 업무에 따라 주식 상품을 다르게 분류하고 집계함  
- 집계용 쿼리를 작성할 때마다 분류 기준을 적용하기 어려워 함수 정의  
CREATE OR REPLACE FUNCTION SF_상품분류(시장코드 VARCHAR2, 증권그룹코드 VARCHAR2)  
RETURN VARCHAR2 
IS 
  L_분류 VARCHAR2(20); 
BEGIN 
  IF 시장코드 IN ('ST', 'KQ') THEN  -- 유가증권, 코스닥 
    IF 증권그룹코드 = 'SS' THEN  
      L_분류 := '주식 현물'; 
    ELSIF 증권그룹코드 IN ('EF', 'EW') THEN  -- ETF, ELW 
      L_분류 := '파생'; 
    ELSE  
      L_분류 := '주식외 현물'; 
    END IF; 
  ELSE   
     L_분류 := '파생'; 
  END IF; 
   
  --SELECT 순서 || '. ' || L_분류 INTO L_분류  
  --FROM   분류순서 
  --WHERE  분류명 = L_분류; 
   
  RETURN L_분류; 
END; 
/ 
~~~

#### 개선 전

~~~sql

SELECT SF_상품분류(시장코드, 증권그룹코드) 상품분류 
     , COUNT(*) 체결건수 
     , SUM(체결수량) 체결수량 
     , SUM(체결금액) 체결금액 
FROM   체결 
WHERE  체결일자 = '20090315' 
GROUP BY SF_상품분류(시장코드, 증권그룹코드)
ORDER BY 1 ; 


상품분류
--------------------------------------------------------------------------------
  체결건수   체결수량   체결금액
---------- ---------- ----------
주식 현물
     62500   31516620 3.1604E+10

주식외 현물
    312500  157561670 1.5801E+11

파생
    625000  315445920 3.1570E+11
~~~

#### 개선 1)  CASE 문으로 변경 

~~~sql
SELECT CASE 
       WHEN 시장코드 IN ('ST', 'KQ') AND 증권그룹코드  = 'SS' THEN '주식 현물' 
       WHEN 시장코드 IN ('ST', 'KQ') AND 증권그룹코드 NOT IN ('SS', 'EF', 'EW') THEN '주식외 현물' 
       WHEN 시장코드 IN ('SD', 'GD') OR 증권그룹코드 IN ('EF', 'EW') THEN '파생' 
       END 상품분류 
     , COUNT(*) 체결건수 
     , SUM(체결수량) 체결수량 
     , SUM(체결금액) 체결금액 
FROM   체결 
WHERE  체결일자 = '20090315' 
GROUP BY  
       CASE 
       WHEN 시장코드 IN ('ST', 'KQ') AND 증권그룹코드  = 'SS' THEN '주식 현물' 
       WHEN 시장코드 IN ('ST', 'KQ') AND 증권그룹코드 NOT IN ('SS', 'EF', 'EW') THEN '주식외 현물' 
       WHEN 시장코드 IN ('SD', 'GD') OR 증권그룹코드 IN ('EF', 'EW') THEN '파생' 
       END 
ORDER BY 1 ; 

상품분류           체결건수   체결수량   체결금액
---------------- ---------- ---------- ----------
주식 현물             62500   31516620 3.1604E+10
주식외 현물          312500  157561670 1.5801E+11
파생                 625000  315445920 3.1570E+11

Elapsed: 00:00:02.20

~~~

#### 개선 2) DECODE 문으로 변경  

~~~sql
SELECT DECODE( 시장코드||증권그룹코드 
             , 'STSS', '주식 현물' 
             , 'KQSS', '주식 현물' 
             , 'SDFU', '파생' 
             , 'SDOP', '파생' 
             , 'GDFU', '파생' 
             , 'GDOP', '파생' 
             , 'STEF', '파생' 
             , 'STEW', '파생' 
             , 'KQEF', '파생' 
             , 'KQEW', '파생' 
             , '주식외 현물' ) 상품분류 
     , COUNT(*) 체결건수 
     , SUM(체결수량) 체결수량 
     , SUM(체결금액) 체결금액 
FROM   체결 
WHERE  체결일자 = '20090315' 
GROUP BY  
       DECODE( 시장코드||증권그룹코드 
             , 'STSS', '주식 현물' 
             , 'KQSS', '주식 현물' 
             , 'SDFU', '파생' 
             , 'SDOP', '파생' 
             , 'GDFU', '파생' 
             , 'GDOP', '파생' 
             , 'STEF', '파생' 
             , 'STEW', '파생' 
             , 'KQEF', '파생' 
             , 'KQEW', '파생' 
             , '주식외 현물' ) 
ORDER BY 1 ; 


상품분류           체결건수   체결수량   체결금액
---------------- ---------- ---------- ----------
주식 현물             62500   31516620 3.1604E+10
주식외 현물          312500  157561670 1.5801E+11
파생                 625000  315445920 3.1570E+11

Elapsed: 00:00:01.91
~~~

#### 사용자함수가 재귀라면 ?

사용자함수가 재귀로 동작한다고 생각해보자.

이 때 개선 전 쿼리를 실행한다면 성능은 극도로 안좋아 질 것이다.

~~~sql
create table 분류순서(분류명, 순서)
as
select '주식 현물', 1 from dual union all
select '주식외 현물', 2 from dual union all
select '파생', 3 from dual;
~~~

~~~sql
CREATE OR REPLACE FUNCTION SF_상품분류(시장코드 VARCHAR2, 증권그룹코드 VARCHAR2)  
RETURN VARCHAR2 
IS 
  L_분류 VARCHAR2(20); 
BEGIN 
  IF 시장코드 IN ('ST', 'KQ') THEN  -- 유가증권, 코스닥 
    IF 증권그룹코드 = 'SS' THEN  
      L_분류 := '주식 현물'; 
    ELSIF 증권그룹코드 IN ('EF', 'EW') THEN  -- ETF, ELW 
      L_분류 := '파생'; 
    ELSE  
      L_분류 := '주식외 현물'; 
    END IF; 
  ELSE   
     L_분류 := '파생'; 
  END IF; 
   
  SELECT 순서 || '. ' || L_분류 INTO L_분류  
  FROM   분류순서 
  WHERE  분류명 = L_분류; 
   
  RETURN L_분류; 
END; 
/ 

~~~

#### 개선 전 쿼리 실행 결과

~~~sh
  체결건수   체결수량   체결금액
---------- ---------- ----------
1. 주식 현물
     62500   31516620 3.1604E+10

2. 주식외 현물
    312500  157561670 1.5801E+11

3. 파생
    625000  315445920 3.1570E+11


Elapsed: 00:02:42.51
~~~



사용자함수 사용시 장점은 분류체계가 바뀌더라도 SQL을 일일이 바꾸지 않아도 된다.

하지만 이것도 정보분류 및 업무규칙을 테이블화해서 관리하면 된다.



~~~sql
CREATE TABLE 상품분류(시장코드, 증권그룹코드, 분류명) 
AS 
SELECT 'ST', 'SS', '주식 현물'    FROM DUAL UNION ALL 
SELECT 'ST', 'EF', '파생'         FROM DUAL UNION ALL 
SELECT 'ST', 'EW', '파생'         FROM DUAL UNION ALL 
SELECT 'ST', 'DR', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'ST', 'SW', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'ST', 'RT', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'ST', 'BC', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'ST', 'MF', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'KQ', 'SS', '주식 현물'    FROM DUAL UNION ALL 
SELECT 'KQ', 'EF', '파생'         FROM DUAL UNION ALL 
SELECT 'KQ', 'EW', '파생'         FROM DUAL UNION ALL 
SELECT 'KQ', 'DR', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'KQ', 'SW', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'KQ', 'RT', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'KQ', 'BC', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'KQ', 'MF', '주식외 현물'  FROM DUAL UNION ALL 
SELECT 'SD', 'FU', '파생'         FROM DUAL UNION ALL 
SELECT 'SD', 'OP', '파생'         FROM DUAL UNION ALL 
SELECT 'GD', 'FU', '파생'         FROM DUAL UNION ALL 
SELECT 'GD', 'OP', '파생'         FROM DUAL ; 
- 상품분류 pk 생성 
ALTER TABLE 상품분류 ADD  
CONSTRAINT 상품분류_PK PRIMARY KEY(시장코드, 증권그룹코드); 
~~~

- 위 쿼리와 join하더라도 성능이 거의 떨어지지 않는다.

~~~sql
- 상품 분류 코드 테이블 활용 
SELECT C.순서 || '. ' || B.분류명 상품분류  
     , SUM(체결건수) 체결건수 
     , SUM(체결수량) 체결수량 
     , SUM(체결금액) 체결금액 
FROM (SELECT 시장코드, 증권그룹코드 
           , COUNT(*) 체결건수 
           , SUM(체결수량) 체결수량 
           , SUM(체결금액) 체결금액 
      FROM   체결 
      WHERE  체결일자 = '20090315' 
      GROUP BY 시장코드, 증권그룹코드) A, 상품분류 B, 분류순서 C 
WHERE A.시장코드 = B.시장코드 
AND   A.증권그룹코드 = B.증권그룹코드 
AND   C.분류명 = B.분류명 
GROUP BY C.순서 || '. ' || B.분류명 
ORDER BY 1 ; 


상품분류                                                     체결건수   체결수량   체결금액
---------------------------------------------------------- ---------- ---------- ----------
1. 주식 현물                                                    62500   31516620 3.1604E+10
2. 주식외 현물                                                 312500  157561670 1.5801E+11
3. 파생                                                        625000  315445920 3.1570E+11

Elapsed: 00:00:02.60
~~~





## 3) 뷰 머지 방지를 통한 함수 호출 최소화

- 함수를 풀어 조인문으로 변경하기 곤란한 경우





#### 개선 전

- 100만 건을 스캔하면서 SF_상품분류 함수를 3번씩 반복 수행하므로 총 300만 번 함수 호출한다

~~~sql
SELECT SUM(DECODE(SF_상품분류(시장코드, 증권그룹코드), '1. 주식 현물', 체결수량))    "주식현물_체결수량"    
     , SUM(DECODE(SF_상품분류(시장코드, 증권그룹코드), '2. 주식외 현물', 체결수량))  "주식외현물_체결수량"  
     , SUM(DECODE(SF_상품분류(시장코드, 증권그룹코드), '3. 파생', 체결수량))         "파생_체결수량"        
FROM   체결 
WHERE  체결일자 = '20090315' ; 

*경   과: 00:02:13.51*
~~~



#### 개선 후

- 아래처럼 하면 1/3 로 함수호출을 줄일 수 있을거라 생각하지만

- Query Transformer에 의해 뷰 머지(View Merge)가 발생하여 (이전 쿼리로 돌아가서) 수행 속도가 전혀 줄지 않았다.

~~~sql

SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"     
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량"  
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량"        
FROM ( 
  SELECT SF_상품분류(시장코드, 증권그룹코드) 상품분류 
       , 체결수량  
  FROM   체결 
  WHERE  체결일자 = '20090315' 
) ; 

*경   과: 00:02:13.64*
~~~



- NO_MERGE 힌트사용하면 생각한대로 1/3로 함수호출을 덜 한다.

~~~sql
SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"     
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량"  
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량"        
FROM ( 
  SELECT /*+ NO_MERGE */ SF_상품분류(시장코드, 증권그룹코드) 상품분류 
       , 체결수량  
  FROM   체결 
  WHERE  체결일자 = '20090315' 
) ; 
*경   과: 00:00:45.34* 

~~~

- NO_MERGE를 사용하지 않더라도 뷰 내에서 rownum을 사용하면 옵티마이저는 절대 뷰 머지를 시도하지 않는다.

~~~sql

SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"     
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량"  
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량"        
FROM ( 
  SELECT ROWNUM, SF_상품분류(시장코드, 증권그룹코드) 상품분류 
       , 체결수량  
  FROM   체결 
  WHERE  체결일자 = '20090315' 
) ; 
*경   과: 00:00:45.29* 
~~~



~~~sql
SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"     
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량"  
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량"        
FROM ( 
  SELECT SF_상품분류(시장코드, 증권그룹코드) 상품분류 
       , 체결수량  
  FROM   체결 
  WHERE  체결일자 = '20090315' 
  AND    ROWNUM > 0 
) ; 
*경   과: 00:00:46.50*
~~~



실행시간을 줄였지만 여전히 느리다

4번에서 스칼라 서브쿼리 캐싱을 이용해보자



## 4) 스칼라 서브쿼리 캐싱 효과를 이용한 함수 호출 최소화



- 스칼라 서브쿼리를 사용하면 오라클은 그 수행횟수를 최소화하려고 입력 값과 출력 값을 내부 캐시(Query Execution Cache)에 저장해 둔다.
- 서브쿼리가 수행될 때마다 입력 값을 캐시에서 찾아보고 거기 있으면 저장된 출력 값을 리턴하고, 없으면 쿼리를 수행한 후 입력값과 출력값을 캐시에 저장해 두는 원리이다.
- 함수를 Dual 테이블을 이용해 스칼라 서브쿼리로 한번 감싸는 것이다.
- 함수 입력 값의 종류가 적을 때 이 기법을 활용하면 함수 호출횟수를 획기적으로 줄일 수 있다.

~~~sql
SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"     
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량"  
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량"        
FROM ( 
  SELECT /*+ NO_MERGE */  
        (SELECT SF_상품분류(시장코드, 증권그룹코드) FROM DUAL) 상품분류 
       , 체결수량  
  FROM   체결 
  WHERE  체결일자 = '20090315' 
) ; 

 
 주식현물_체결수량 주식외현물_체결수량 파생_체결수량
----------------- ------------------- -------------
	 31516620	    157561670	  315445920

Elapsed: 00:01:36.13

call     count       cpu    elapsed       disk      query    current        rows 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
Parse        1      0.00       0.00          0          0          0           0 
Execute 725010     11.37      10.39          0          0          0           0 
Fetch   725010     17.57      17.63          0    2175030          0      725010 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
total   1450021     28.95      28.03          0    2175030          0      725010
~~~

- 함수 호출 횟수를 20번으로 예상했지만 너무 많은 함수를 호출을 한다.
  - 해시 충돌이 발생했기 때문
  - 해시 충돌이 발생하면 기존 엔트리를 밀어내고 새로 수행한 입력 값과 출력 값으로 대체할 것 같지만, 오라클은 기존 캐시 엔트리를 그대로 둔채 스칼라 서브쿼리만 한 번 더 수행한다.
  - 8i, 9i에서는 256개 엔트리를 캐싱
  - 10g에서는 입력과 출력 값 크기, _query_execution_cache_max_size 파라미터에 의해 캐시 사이즈가 결정된다(defult : 65536)





#### 개선 후

##### _query_execution_cache_max_size 세팅

~~~
ALTER SESSION SET "_query_execution_cache_max_size" = 2097152;
~~~



~~~sql
SELECT SUM(DECODE(상품분류, '1. 주식 현물'  , 체결수량)) "주식현물_체결수량"  
     , SUM(DECODE(상품분류, '2. 주식외 현물', 체결수량)) "주식외현물_체결수량" 
     , SUM(DECODE(상품분류, '3. 파생'       , 체결수량)) "파생_체결수량" 
FROM ( 
  SELECT /*+ NO_MERGE */  
        (SELECT SF_상품분류(시장코드, 증권그룹코드) FROM DUAL) 상품분류 
       , 체결수량  
  FROM   체결  
  WHERE  체결일자 = '20090315' 
) ; 

주식현물_체결수량 주식외현물_체결수량 파생_체결수량
----------------- ------------------- -------------
	 31516620	    157561670	  315445920

Elapsed: 00:00:02.33
 
call     count       cpu    elapsed       disk      query    current        rows 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
Parse        1      0.00       0.00          0          0          0           0 
Execute     20      0.00       0.00          0          0          0           0 
Fetch       20      0.00       0.00          6         60          0          20 
------- ------  -------- ---------- ---------- ---------- ----------  ---------- 
total       41      0.00       0.00          6         60          0          20
~~~

- 해시 충돌 없이 단 20번만 함수 호출이 발생
- 8i, 9i에서 테스트해 보면 기본적으로 256개를 캐싱하므로 파라미터 조정 없이도 이와 같은 성능 개선 효과를 얻을 수 있다.

- 함수 호출 부분을 맨 바깥쪽 select-list에 기술함으로서 성능을 개선할 수 있지만, 페이지 처리 또는 부분범위처리가 불가능한 상황에서는 스칼라 서브쿼리를 활용함으로써 큰 효과를 볼 수 있다.



이 기법은 입력값의 종류가 소수여서 해시 충돌 가능성이 적은 함수에만 적용해야 한다
그렇지 않으면 CPU 사용률만 높이게 된다.







## 5) Deterministic 함수의 캐싱 효과 활용

- 10gR2에서 함수를 선언할 때 Deterministic 키워드를 넣어 주면 캐싱 효과가 나타난다.
- 함수의 입력 값과 출력 값은 CGA(Call Global Area)에 캐싱된다.
- CGA에 할당된 값은 데이터베이스 Call 내에서만 유효하므로 Fetch Call이 완료되면 그 값은 모두 해제된다.
- Deterministic 함수의 캐싱 효과는 데이터베이스 Call 내에서만 유효하다.
- 스칼라 서브쿼리에서의 입력, 출력 값은 UGA에 저장되므로 Fetch Call에 상관없이 그 효과가 캐싱되는 순간부터 끝까지 유지 된다.

- 1부터 함수 입력값까지의 누적 합을 구하는 함수를 Deterministic으로 선언
- 함수 호출 횟수를 확인할 목적으로 세션 client_info 값을 매번 변경하는 코드를 중간에 삽입



~~~sql
create or replace function ACCUM (p_input number) return number 
DETERMINISTIC
as 
  rValue number := 0 ; 
  call_cnt number := 0; 
begin 
  dbms_application_info.read_client_info(call_cnt); 
  if call_cnt is null then 
    call_cnt := 0; 
  end if; 
 
  dbms_application_info.set_client_info(call_cnt + 1);
 
  for i in 1..p_input loop 
    rValue := rValue + i ; 
  end loop; 
  return rValue ; 
end; 
/ 
 
select sum(accum_num) 
from ( 
  select accum(mod(rownum, 50)) accum_num 
  from dual 
  connect by level <= 1000000 
) ; 


SUM(ACCUM_NUM)
--------------
     416500000

Elapsed: 00:00:06.45


 
select sys_context('userenv', 'client_info') from dual; 
 
SYS_CONTEXT('USERENV','CLIENT_INFO') 
----------------------------------------------------------------- 
100
~~~

- 1,000,000번 호출했지만 실제 호출 횟수는 100번 **<-- 책에서는 50번인데 왜 실제는 100이지?**
- SUM을 구하는 쿼리 이므로 한 번의 Fetch Call 내에 캐시 상태를 유지하며 처리 완료.

- Deterministic 키워드를 제거하고 테스트

~~~sql
exec dbms_application_info.set_client_info( NULL ); 
select sum(accum_num) 
from ( 
  select accum(mod(rownum, 50)) accum_num 
  from dual 
  connect by level <= 1000000 
) ; 


SUM(ACCUM_NUM)
--------------
     416500000

Elapsed: 00:00:07.33

 
select client_info 
from   v$session 
where  sid = sys_context('userenv', 'sid'); 
 
CLIENT_INFO 
------------------------------------------------------- 
50

~~~

- 함수 50번 호출, 7초 소요. **<- 책에서는 백만번 호출인데 왜 차이가 나는걸까?**

- Deterministic 키워드는 그 함수가 일관성 있는 결과를 리턴함을 선언하는 것일 뿐,그것을 넣었다고 해서 일관성이 보장되는 것은 아니다.
- 시점과 무관하게 항상 일관성 있는 결과를 출력하는 함수에 캐싱효과를 위해 Deterministic 함수의 사용은 올바른 활용 사례지만, 함수가 쿼리문을 포함할 때는 캐싱효과를 위해 함부로 Deterministic으로 선언하면 안된다.





## 6) 복잡한 함수 로직을 풀어 SQL로 구현

함수 호출의 부하를 중간집합을 생성하여 조인으로 풀어낸 사례.

- 때와 상황에 맞추어 사용하는게 좋을듯하다.
- 주식로직에 특화되어있어 굳이 이해하지 않아도 될 거 같다.