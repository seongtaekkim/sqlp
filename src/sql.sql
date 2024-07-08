

-- 고객
CREATE TABLE CUSTOMER
(
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR2(100),
    CUSTOMER_GRADE VARCHAR2(2),
    CONSTRAINT PK_CUSTOMER PRIMARY KEY (CUSTOMER_ID)
);

COMMENT ON COLUMN CUSTOMER.CUSTOMER_ID IS '고객ID';
COMMENT ON COLUMN CUSTOMER.CUSTOMER_NAME IS '고객이름';
COMMENT ON COLUMN CUSTOMER.CUSTOMER_GRADE IS '고객등급';


-- 고객 변경이력
CREATE TABLE CUSTOMER_UPDT_HIST
(
    STRT_DT VARCHAR2(8),
    END_DT VARCHAR2(8),
    CUSTOMER_GRADE VARCHAR2(2),
    CONSTRAINT PK_CUSTOMER_UPDT_HIST PRIMARY KEY (STRT_DT, END_DT)
);

COMMENT ON COLUMN CUSTOMER_UPDT_HIST.STRT_DT IS '시작일자';
COMMENT ON COLUMN CUSTOMER_UPDT_HIST.END_DT IS '종료일자';
COMMENT ON COLUMN CUSTOMER_UPDT_HIST.CUSTOMER_GRADE IS '고객등급';
