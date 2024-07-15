

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

-- 주문상세 
CREATE TABLE ORDERS2_DETAIL
(
    ORDER_ID NUMBER,
    PRODUCT_ID NUMBER,
    ORDER_DATE DATE,
    ORDER_RECEPT_NO NUMBER,
    ORDER_RECEPT_DATE DATE,
    SELL_BUY_CD VARCHAR2(2),
    ORDER_TYPE_CODE VARCHAR2(2),
    ORDER_QUENTITY NUMBER,
    ORDER_PROCE NUMBER,
    MEMBER_ID NUMBER,
    CONSTRAINT PK_ORDERS PRIMARY KEY (ORDER_ID, PRODUCT_ID)
);

COMMENT ON COLUMN ORDERS2_DETAIL.PRODUCT_ID IS '상품번호';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_DATE IS '주문일자';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_RECEPT_NO IS '주문접수번호';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_RECEPT_DATE IS '주문접수시각';
COMMENT ON COLUMN ORDERS2_DETAIL.SELL_BUY_CD IS '매도매수구분';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_TYPE_CODE IS '주문유형코드';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_QUENTITY IS '주문수량';
COMMENT ON COLUMN ORDERS2_DETAIL.ORDER_PROCE IS '주문가격';
COMMENT ON COLUMN ORDERS2_DETAIL.MEMBER_ID IS '회원번호';


-- 판매
CREATE TABLE SALES
(
    SALES_ID NUMBER,
    ITEM_ID NUMBER,
    SALES_DATE DATE,
    SALES_QUENTITY NUMBER,
    SALES_PRICE NUMBER,
    MEMBER_ID NUMBER,
    CONSTRAINT PK_SALES PRIMARY KEY (SALES_ID)
);

COMMENT ON COLUMN SALES.SALES_ID IS '판매ID';
COMMENT ON COLUMN SALES.ITEM_ID IS '상품ID';
COMMENT ON COLUMN SALES.SALES_DATE IS '판매날짜';
COMMENT ON COLUMN SALES.SALES_QUENTITY IS '판매수량';
COMMENT ON COLUMN SALES.SALES_PRICE IS '판매가격';
COMMENT ON COLUMN SALES.MEMBER_ID IS '고객ID';


-- 주문상품테이블
CREATE TABLE ORDERS2_PRODUCT
(
    PRODUCT_ID NUMBER,
    ORDER_ID NUMBER,
    ORDER_DATETIME timestamp,
    PRODUCT_NAME NUMBER,
    MEMBER_NAME NUMBER,
    MEMBER_ID NUMBER,
    CONSTRAINT PK_ORDERS2_PRODUCT PRIMARY KEY (PRODUCT_ID, ORDER_ID)
);



COMMENT ON COLUMN ORDERS2_PRODUCT.PRODUCT_ID IS '상품번호';
COMMENT ON COLUMN ORDERS2_PRODUCT.ORDER_ID IS '주문번호';
COMMENT ON COLUMN ORDERS2_PRODUCT.ORDER_DATETIME IS '주문일시';
COMMENT ON COLUMN ORDERS2_PRODUCT.PRODUCT_NAME IS '상품명';
COMMENT ON COLUMN ORDERS2_PRODUCT.MEMBER_NAME IS '회원명';
COMMENT ON COLUMN ORDERS2_PRODUCT.MEMBER_ID IS '회원번호';

-- 과금
CREATE TABLE BILLING
(
    BILLING_ID NUMBER,
    BILLING_AMOUNT NUMBER,
    BILLING_YYYYMM VARCHAR2(6),
    PRODUCT_ID NUMBER,
    MEMBER_ID NUMBER,
    CONSTRAINT PK_BILLING PRIMARY KEY (BILLING_ID)
);


COMMENT ON COLUMN BILLING.BILLING_ID IS '과금ID';
COMMENT ON COLUMN BILLING.BILLING_AMOUNT IS '과금액';
COMMENT ON COLUMN BILLING.BILLING_YYYYMM IS '과금연월';
COMMENT ON COLUMN BILLING.PRODUCT_ID IS '상품ID';
COMMENT ON COLUMN BILLING.MEMBER_ID IS '회원번호';

-- 수납
CREATE TABLE RECEIPT
(
    RECEIPT_ID NUMBER,
    RECEIPT_ORDER NUMBER,
    BILLING_ID NUMBER,
    RECEIPT_AMOUNT NUMBER,
    RECEIPT_DTM TIMESTAMP,
    BILLING_YYYYMM VARCHAR2(6),
    PRODUCT_ID NUMBER,
    MEMBER_ID NUMBER,
    CONSTRAINT PK_BILLING PRIMARY KEY (RECEIPT_ID)
);


COMMENT ON COLUMN RECEIPT.RECEIPT_ID IS '수납ID';
COMMENT ON COLUMN RECEIPT.RECEIPT_ORDER IS '수납순서';
COMMENT ON COLUMN RECEIPT.BILLING_ID IS '과금ID';
COMMENT ON COLUMN RECEIPT.RECEIPT_AMOUNT IS '수납액';
COMMENT ON COLUMN RECEIPT.RECEIPT_DTM IS '수납일시';
COMMENT ON COLUMN RECEIPT.BILLING_YYYYMM IS '과금연월';
COMMENT ON COLUMN RECEIPT.PRODUCT_ID IS '상품ID';
COMMENT ON COLUMN RECEIPT.MEMBER_ID IS '회원번호';





-- 시간대별종목거래
-- 시간별 종목 거래 통계 테이블
CREATE TABLE TIME_STOCK_TRADES
(
    TRADE_DTTM VARCHAR2(10),
    EXECUTION_COUNT NUMBER,
    EXECUTION_QUANTITY NUMBER,
    TRADE_AMOUNT NUMBER,
    STOCK_CD VARCHAR2(2),
    CONSTRAINT PK_TIME_STOCK_TRADES PRIMARY KEY (TRADE_DTTM, STOCK_CD)
);


COMMENT ON COLUMN TIME_STOCK_TRADES.TRADE_DTTM IS '거래일시';
COMMENT ON COLUMN TIME_STOCK_TRADES.EXECUTION_COUNT IS '체결건수';
COMMENT ON COLUMN TIME_STOCK_TRADES.EXECUTION_QUANTITY IS '체결수량';
COMMENT ON COLUMN TIME_STOCK_TRADES.TRADE_AMOUNT IS '거래대금';
COMMENT ON COLUMN TIME_STOCK_TRADES.STOCK_CD IS '종목코드';



