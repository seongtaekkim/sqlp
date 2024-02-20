# 11. Shared Pool



SGA의 중요한 구성요소중 하나인 Shared Pool에 대해..



## 1) 딕셔너리 캐시



Shared Pool은 크게 딕셔너리캐시와 라이브러리캐시로 나뉜다.

딕셔너리캐시(== 로우캐시)

오라클 딕셔너리 정보를 저장하는 캐시영역

Row단위로 읽고 쓴다.

테이블, 인덱스, 테이블스페이스, 데이터파일, 세그먼트, 익스텐트, 사용자, 제약, Sequence, DB linke 정보를 캐싱한다.

- Sequence 객체를 만들면 딕셔너리에 저장되고, 로우캐시를 거쳐 읽고쓴다.
- nextval 호출 시 로우캐시를 통해 update 됨
  - 잦은 채번 시 로우캐시 경합이 발생함 이에대해 캐시사이즈를 설정해서 경합이슈를 줄일 수 있다. (기본값: 20)



`V$ROWCACHE`- 딕셔너리 캐시의 활동성에 대한 통계 뷰

- 히트율이 낮으면 Shared Pool 사이즈 확장을 고려

~~~sql
COLUMN HIT_RATIO FORMAT 990.99
SELECT ROUND((SUM(GETS - GETMISSES)) / SUM(GETS) * 100, 2) HIT_RATIO
FROM V$ROWCACHE;
~~~





~~~sql
SELECT PARAMETER, GETS, GETMISSES, ROUND((GETS - GETMISSES) / GETS * 100, 2) HIT_RATIO, MODIFICATIONS
FROM V$ROWCACHE
WHERE GETS > 0
ORDER BY HIT_RATIO DESC;


/*
dc_column_model_to_tab	21	0	100	0
dc_realtime_colst	21	0	100	0
dc_tablespaces	5090	25	99.51	0
dc_awr_control	302	2	99.34	2
dc_users	9926	173	98.26	0
dc_histogram_data	177481	6859	96.14	3107
dc_global_oids	3862	152	96.06	0
dc_histogram_defs	526025	21791	95.86	6241
dc_objects	200121	8673	95.67	713
dc_rollback_segments	792	44	94.44	43
/*
~~~





- 로우 캐시 엔트리 당 래치 할당 추정
  - 책에는 아래 두 값이 같다고 하는데, 실제론 row cache objects이 없다 왜지???


~~~sql
SELECT *
FROM (SELECT COUNT(*) FROM V$ROWCACHE WHERE TYPE = 'PARENT'),
     (SELECT COUNT(*) FROM V$LATCH_CHILDREN WHERE NAME = 'row cache objects')
;

-- 62 0
~~~







## 2) 라이브러리 캐시

DB버퍼캐시, Redo로그버퍼캐시, 딕셔너리캐시 등은 데이터 입출력 속도관련인 반면 라이브러리캐시는 SQL, 실행계획을 저장하는 캐시영역이다.



실행계획?

- 사용자가 쿼리한 SQL에 대해, 최적으로 수행하기 위한 처리루틴.

하드파싱?

- SQL을 분석해서 문법오류,실행권한 등을 체크하고 최적화 과정을 거쳐 실행계획을 만들고, SQL실행엔진 문법에 맞게 포매팅하는 과정
- 위 과정 중 최적화 과정이 가장 오래걸린다.

소프트파싱

- 같은 쿼리에 대해 중복되는 하드파싱을 피하기 위해 라이브러리캐시에 SQL, 실행계획을 캐싱하여 재사용한다.







































