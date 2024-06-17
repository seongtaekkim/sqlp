# 07. DCL



## 1) DCL 개요

- 유저를 생성하고 권한을 제어할 수 있는 DCL(DATA CONTROL LANGUAGE)



## 2) 유저와 권한

- Oracle
  - 아이디와 비밀번호 방식으로 인스턴스에 접속을 하고 그에 해당하는 스키마에 오브젝트 생성 등의 권한을 부여받게 된다.

- SQL Server
  - 첫 번째, Windows 인증 방식으로 Windows에 로그인한 정보를 가지고 SQL Server에 접속하는 방식이다. ( 트러스트된 연결)
  - 두 번째, 혼합 모드(Windows 인증 또는 SQL 인증) 방식으로 기본적으로 Windows 인증으로도 SQL Server에 접속 가능.



#### 가. 유저 생성과 시스템 권한 부여

#### Oracle 

```sql
GRANT CREATE USER TO SCOTT;
conn scott/tiger
CREATE USER PJS IDENTIFIED BY KOREA7; CREATE USER PJS IDENTIFIED BY KOREA7;
GRANT CREATE SESSION TO PJS; (resource, connect)
GRANT CRATE TABLE TO PJS;
```

#### SQL Server 

- SQL Server는 유저를 생성하기 전 먼저 로그인을 생성해야 한다. 
  로그인을 생성할 수 있는 권한을 가진 로그인은 기본적으로 sa이다. 

~~~sql
CREATE LOGIN PJS WITH PASSWORD='KOREA7'
     , DEFAULT_DATABASE=AdventureWorks 
   USE ADVENTUREWORKS; 
GO
CREATE USER PJS FOR LOGIN PJS 
       WITH DEFAULT_SCHEMA = dbo; 

GRANT CREATE TABLE TO PJS; 
GRANT Control ON SCHEMA:
~~~



### 나. OBJECT에 대한 권한 부여

- ORACLE

| 객체권한   | 테이블 | VIEWS | SEQUENC | PROCEDURE |
| :--------- | :----- | :---- | :------ | :-------- |
| alter      | O      |       | O       |           |
| delete     | O      | O     |         |           |
| execute    |        |       |         | O         |
| index      | O      |       |         |           |
| insert     | O      | O     |         |           |
| references | O      |       |         |           |
| select     | O      | O     | O       |           |
| update     | O      | O     |         |           |



- SQL Server

| 객체권한   | 테이블 | VIEWS | SEQUENC | PROCEDURE |
| :--------- | :----- | :---- | :------ | :-------- |
| alter      | O      |       | O       |           |
| delete     | O      | O     | O       |           |
| execute    |        |       |         | O         |
| index      | O      |       |         |           |
| insert     | O      | O     |         |           |
| references | O      |       |         |           |
| select     | O      | O     | O       |           |
| update     | O      | O     |         |           |



## 3) Role을 이용한 권한 부여

- 데이터베이스에서 유저들과 권한들 사이에서 중개 역할을 하는 ROLE을 제공한다.
- 데이터베이스 관리자는 ROLE을 생성하고, ROLE에 각종 권한들을 부여한 후 ROLE을 다른 ROLE이나 유저에게 부여할 수 있다.
- 또한 ROLE에 포함되어 있는 권한들이 필요한 유저에게는 해당 ROLE만을 부여함으로써 빠르고 정확하게 필요한 권한을 부여할 수 있게 된다.

- ROLE에는 시스템 권한과 오브젝트 권한을 모두 부여할 수 있으며, ROLE은 유저에게 직접 부여될 수도 있고, 다른 ROLE에 포함하여 유저에게 부여될 수도 있다.
- Connect Role 과 Rource Role 에 포함된 권한 목록 (ORACLE)



| CONNECT              | RESOURCE             |
| :------------------- | :------------------- |
| ALTER SESSION        | CREATE CLUSTER       |
| CREATE CLUSTER       | CREATE INDEXTYPE     |
| CREATE DATABASE LINK | CREATE OPERATOR      |
| CREATE MENU_SEQUENCE | CRATE PROCEDURE      |
| CREATE SESSION       | CREATE MENU_SEQUENCE |
| CREATE SYSNONYM      | CREATE TABLE         |
| CREATE TABLE         | CREATE TRIGGER       |
| CREATE VIEW          | CREATE               |

- -> dba_tab_roles 조회 시 다름.



- 서버 수준 역활 (SQL Server 사례)

| 서버 수준 역할명  | 설명                                                         |
| :---------------- | :----------------------------------------------------------- |
| Public            | 모든 sql server 로그인은 public 권한에 속한다. 모든 사용자에게 개체를 사용 할 수 있도록 하라면 개체에 public 권한 할당 필요 |
| bulkadmin         | BULK INSERT 문을 수행할 수 있다                              |
| dbcrator          | 데이터베이스 생성,변경, 삭제 및 복원 가능                    |
| diskadmin         | 디스트 파일을 관리하는데 사용                                |
| processadmin      | SQL server 의 인스턴승서 실행 중인 프로세스를 종료 가능      |
| securityadmin     | 로그인 및 해당 속성 관리, grant, deny, revoke 을 할수 있음, 패스워스 변경 가능 |
| serveradmin       | 서버 차원의 구성 옵션을 변경하고 서버 종료                   |
| setupadmin        | 연결된 서버를 추가하거나 제거 가능                           |
| sysadmin          | 서버에서 모든 작업을 수행 할 수 있다. (Default builtin\administators 그룹 맴버인 로컬 관리 그룹은 sysadmin 고정 서버 역활 맴버 |
| db_accessadmin    | window login, windows 그룹 및 sql server 로그인의 데이터베이스에 대한 액세스를 추가하거나 제거 가능 |
| db_backupoperator | 데이터베이스를 백업 할 수 있다                               |
| db_datareader     | 모든 사용자의 테이블의 모든 데이터를 읽을 수 있다            |
| db_datawriter     | 모든 사용자의 테이블의 모든 데이터를 추가, 삭제, 변경 가능   |
| db_ddladmin       | 데이터베이스에서 모든 ddl 을 명령을 수행 가능                |
| db_denydatareader | 데이터베이스 내 있는 사용자의 테이블 데이터를 읽을 수 없다   |
| db_denydatawriter | 데이터베이스 내 있는 모든 사용자의 데이터를 추가, 삭제, 변경 불가능 |
| db_owner          | 데이터베이스 내에 있는 모든 구성 및 유지 관리 작업을 수행할 수 있고 데이터베이스 삭제 가능 |
| db_securityadmin  | 역활 맴버 자격을 수정하고 사용 권한 관리를 할 수 있다, 이 역활에 보안 주체를 추가하면 원하지 않는 권한 상승이 설정 될 수 있다 |

- SQL Server에서는 Oracle과 같이 Role을 자주 사용하지 않는다. 대신 위에서 언급한 서버 수준 역할 및 데이터베이스 수준 역할을 이용하여 로그인 및 사용자 권한을 제어한다.
- 인스턴스 수준의 작업이 필요한 경우 서버 수준 역할을 부여하고 그보다 작은 개념인 데이터베이스 수준의 권한이 필요한 경우 데이터베이스 수준의 역할을 부여하면 된다.
- 즉, 인스턴스 수준을 요구하는 로그인에는 서버 수준 역할을, 데이터베이스 수준을 요구하는 사용자에게는 데이터베이스 수준 역할을 부여한다.
