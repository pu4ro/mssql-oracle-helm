# MSSQL + Oracle Client Helm Chart Makefile
# ==========================================

# 설정 변수
NAMESPACE ?= mssql-namespace
RELEASE_NAME ?= mssql-oracle
CHART_PATH ?= .
REGISTRY ?= cr.makina.rocks/external-hub
IMAGE_NAME ?= mssql-oracle
IMAGE_TAG ?= 2022-latest
DOCKER_DIR ?= docker
SA_PASSWORD ?= Newpower1@

# Kubernetes Context
KUBE_CONTEXT ?= kwater-config

# 색상
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help build push deploy upgrade uninstall status logs shell test test-odbc test-network test-all test-mssql clean all setup-polybase setup-polybase-enable setup-polybase-masterkey setup-polybase-credential setup-polybase-datasource test-polybase clean-polybase setup-adhoc-queries test-adhoc test-adhoc-tables test-adhoc-query test-odbc-direct setup-linkedserver setup-linkedserver-provider setup-linkedserver-create setup-linkedserver-login test-linkedserver query-oracle clean-linkedserver

# 기본 타겟
help:
	@echo "$(GREEN)MSSQL + Oracle Client Helm Chart$(NC)"
	@echo "=================================="
	@echo ""
	@echo "$(YELLOW)사용 가능한 명령어:$(NC)"
	@echo ""
	@echo "  $(GREEN)make build$(NC)      - Docker 이미지 빌드"
	@echo "  $(GREEN)make push$(NC)       - Docker 이미지 레지스트리에 푸시"
	@echo "  $(GREEN)make deploy$(NC)     - Helm 차트 신규 배포"
	@echo "  $(GREEN)make upgrade$(NC)    - Helm 차트 업그레이드"
	@echo "  $(GREEN)make uninstall$(NC)  - Helm 릴리즈 삭제"
	@echo "  $(GREEN)make status$(NC)     - 배포 상태 확인"
	@echo "  $(GREEN)make logs$(NC)       - Pod 로그 확인"
	@echo "  $(GREEN)make shell$(NC)      - Pod 쉘 접속"
	@echo "  $(GREEN)make test$(NC)       - Oracle 클라이언트 테스트"
	@echo "  $(GREEN)make test-odbc$(NC)  - ODBC 설정 테스트"
	@echo "  $(GREEN)make test-network$(NC) - 네트워크 연결 테스트"
	@echo "  $(GREEN)make test-all$(NC)   - 전체 Oracle 테스트"
	@echo "  $(GREEN)make test-mssql$(NC) - MSSQL 연결 테스트"
	@echo "  $(GREEN)make setup-polybase$(NC) - PolyBase Oracle 연결 설정"
	@echo "  $(GREEN)make test-polybase$(NC)  - PolyBase 설정 확인"
	@echo "  $(GREEN)make clean-polybase$(NC) - PolyBase 설정 삭제"
	@echo ""
	@echo "$(YELLOW)ODBC 직접 연결 (Linux 권장):$(NC)"
	@echo "  $(GREEN)make setup-adhoc-queries$(NC) - Ad-hoc 분산 쿼리 활성화"
	@echo "  $(GREEN)make test-adhoc$(NC)       - Ad-hoc 쿼리 테스트 (DUAL 테이블)"
	@echo "  $(GREEN)make test-adhoc-tables$(NC) - Oracle 테이블 목록 조회"
	@echo "  $(GREEN)make test-adhoc-query$(NC)  - 커스텀 Oracle 쿼리 실행"
	@echo "  $(GREEN)make test-odbc-direct$(NC)  - ODBC 설정 확인"
	@echo ""
	@echo "$(YELLOW)Linked Server (Windows 전용):$(NC)"
	@echo "  $(GREEN)make setup-linkedserver$(NC) - Linked Server Oracle 연결 설정"
	@echo "  $(GREEN)make test-linkedserver$(NC)  - Linked Server 연결 테스트"
	@echo "  $(GREEN)make query-oracle$(NC)   - OPENQUERY로 Oracle 쿼리 실행"
	@echo "  $(GREEN)make clean-linkedserver$(NC) - Linked Server 삭제"
	@echo "  $(GREEN)make clean$(NC)      - 빌드 아티팩트 정리"
	@echo "  $(GREEN)make all$(NC)        - 빌드 + 푸시 + 배포"
	@echo ""
	@echo "$(YELLOW)설정 변수:$(NC)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  RELEASE_NAME=$(RELEASE_NAME)"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  KUBE_CONTEXT=$(KUBE_CONTEXT)"
	@echo ""
	@echo "$(YELLOW)예시:$(NC)"
	@echo "  make deploy NAMESPACE=my-namespace"
	@echo "  make build IMAGE_TAG=v1.0.0"

# Oracle Instant Client 파일 확인
check-oracle-files:
	@echo "$(YELLOW)Oracle Instant Client 파일 확인...$(NC)"
	@if [ ! -f "$(DOCKER_DIR)/instantclient-basic-linux.x64-23.6.0.24.10.zip" ]; then \
		echo "$(RED)오류: instantclient-basic-linux.x64-23.6.0.24.10.zip 파일이 없습니다$(NC)"; \
		echo "다운로드: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"; \
		exit 1; \
	fi
	@if [ ! -f "$(DOCKER_DIR)/instantclient-odbc-linux.x64-23.6.0.24.10.zip" ]; then \
		echo "$(RED)오류: instantclient-odbc-linux.x64-23.6.0.24.10.zip 파일이 없습니다$(NC)"; \
		echo "다운로드: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"; \
		exit 1; \
	fi
	@echo "$(GREEN)Oracle Instant Client 파일 확인 완료$(NC)"

# Docker 이미지 빌드
build: check-oracle-files
	@echo "$(YELLOW)Docker 이미지 빌드 중...$(NC)"
	@echo "이미지: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"
	cd $(DOCKER_DIR) && docker build -t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)빌드 완료!$(NC)"

# Docker 이미지 푸시
push:
	@echo "$(YELLOW)Docker 이미지 푸시 중...$(NC)"
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)푸시 완료!$(NC)"

# Namespace 생성
create-namespace:
	@kubectl --context=$(KUBE_CONTEXT) create namespace $(NAMESPACE) --dry-run=client -o yaml | \
		kubectl --context=$(KUBE_CONTEXT) apply -f -

# Helm 배포
deploy: create-namespace
	@echo "$(YELLOW)Helm 차트 배포 중...$(NC)"
	@echo "Context: $(KUBE_CONTEXT)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Release: $(RELEASE_NAME)"
	helm --kube-context=$(KUBE_CONTEXT) upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--set oracle.customImage.repository=$(REGISTRY)/$(IMAGE_NAME) \
		--set oracle.customImage.tag=$(IMAGE_TAG)
	@echo "$(GREEN)배포 완료!$(NC)"

# Helm 업그레이드
upgrade:
	@echo "$(YELLOW)Helm 차트 업그레이드 중...$(NC)"
	helm --kube-context=$(KUBE_CONTEXT) upgrade $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--set oracle.customImage.repository=$(REGISTRY)/$(IMAGE_NAME) \
		--set oracle.customImage.tag=$(IMAGE_TAG)
	@echo "$(GREEN)업그레이드 완료!$(NC)"

# Helm 삭제
uninstall:
	@echo "$(YELLOW)Helm 릴리즈 삭제 중...$(NC)"
	helm --kube-context=$(KUBE_CONTEXT) uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "$(GREEN)삭제 완료!$(NC)"

# PVC까지 모두 삭제
uninstall-all: uninstall
	@echo "$(YELLOW)PVC 삭제 중...$(NC)"
	kubectl --context=$(KUBE_CONTEXT) delete pvc --all -n $(NAMESPACE) || true
	@echo "$(YELLOW)Namespace 삭제 중...$(NC)"
	kubectl --context=$(KUBE_CONTEXT) delete namespace $(NAMESPACE) || true
	@echo "$(GREEN)전체 삭제 완료!$(NC)"

# 배포 상태 확인
status:
	@echo "$(YELLOW)=== Helm Release ===$(NC)"
	@helm --kube-context=$(KUBE_CONTEXT) list -n $(NAMESPACE) 2>/dev/null || echo "릴리즈 없음"
	@echo ""
	@echo "$(YELLOW)=== Pods ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) get pods -n $(NAMESPACE) 2>/dev/null || echo "Pod 없음"
	@echo ""
	@echo "$(YELLOW)=== Services ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) get svc -n $(NAMESPACE) 2>/dev/null || echo "Service 없음"
	@echo ""
	@echo "$(YELLOW)=== PVC ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) get pvc -n $(NAMESPACE) 2>/dev/null || echo "PVC 없음"
	@echo ""
	@echo "$(YELLOW)=== ConfigMaps ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) get configmap -n $(NAMESPACE) 2>/dev/null || echo "ConfigMap 없음"

# Pod 로그 확인
logs:
	@kubectl --context=$(KUBE_CONTEXT) logs -f deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE)

# Pod 쉘 접속
shell:
	@kubectl --context=$(KUBE_CONTEXT) exec -it deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- /bin/bash

# Oracle 클라이언트 테스트
test:
	@echo "$(YELLOW)=== Oracle Client 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		bash -c 'echo "TNS_ADMIN=$$TNS_ADMIN"; echo "LD_LIBRARY_PATH=$$LD_LIBRARY_PATH"; \
		echo ""; echo "=== tnsnames.ora ==="; cat $$TNS_ADMIN/tnsnames.ora; \
		echo ""; echo "=== Oracle Client Version ==="; \
		/opt/oracle/instantclient_23_6/genezi -v 2>&1 | head -10'

# ODBC 설정 테스트
test-odbc:
	@echo "$(YELLOW)=== Oracle ODBC 설정 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		bash -c 'echo "=== 환경변수 ==="; \
		echo "ODBCINI=$$ODBCINI"; echo "ODBCSYSINI=$$ODBCSYSINI"; \
		echo ""; echo "=== odbcinst.ini (드라이버 설정) ==="; cat /etc/odbcinst.ini; \
		echo ""; echo "=== odbc.ini (DSN 설정) ==="; cat /etc/odbc.ini; \
		echo ""; echo "=== ODBC 드라이버 파일 확인 ==="; ls -la /opt/oracle/instantclient_23_6/libsqora* 2>/dev/null || echo "드라이버 파일 없음"'

# Oracle 네트워크 연결 테스트 (포트 확인)
test-network:
	@echo "$(YELLOW)=== Oracle 네트워크 연결 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		bash -c 'for entry in $$(grep -oP "^\s*\K[A-Z_]+(?=\s*=)" $$TNS_ADMIN/tnsnames.ora); do \
		host=$$(grep -A5 "$$entry" $$TNS_ADMIN/tnsnames.ora | grep -oP "HOST=\K[^)]+"); \
		port=$$(grep -A5 "$$entry" $$TNS_ADMIN/tnsnames.ora | grep -oP "PORT=\K[^)]+"); \
		echo -n "$$entry ($$host:$$port): "; \
		timeout 3 bash -c "echo > /dev/tcp/$$host/$$port" 2>/dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"; \
		done'

# 전체 Oracle 테스트
test-all: test test-odbc test-network
	@echo "$(GREEN)=== 전체 Oracle 테스트 완료 ===$(NC)"

# Linked Server 설정 변수
LINKED_SERVER_NAME ?= ORA23_LINK
LINKED_SERVER_DSN ?= Oracle23DSN

# PolyBase 설정 변수
POLYBASE_DB ?= master
MASTER_KEY_PWD ?= PolyBase@SecureKey123!
ORACLE_USER ?= EZOFFICE
ORACLE_PWD ?= 1215
ORACLE_HOST ?= 192.168.70.30
ORACLE_PORT ?= 1521
ORACLE_SERVICE ?= MESNPPOP
ORACLE_DRIVER ?= Oracle 23 ODBC driver

# PolyBase 활성화
setup-polybase-enable:
	@echo "$(YELLOW)=== PolyBase 활성화 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_configure 'polybase enabled', 1; RECONFIGURE;"
	@echo "$(GREEN)PolyBase 활성화 완료 (Pod 재시작 필요할 수 있음)$(NC)"

# Master Key 생성
setup-polybase-masterkey:
	@echo "$(YELLOW)=== Master Key 생성 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##') CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$(MASTER_KEY_PWD)';"
	@echo "$(GREEN)Master Key 생성 완료$(NC)"

# Oracle Credential 생성
setup-polybase-credential:
	@echo "$(YELLOW)=== Oracle Credential 생성 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); IF NOT EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'OracleCredential') CREATE DATABASE SCOPED CREDENTIAL OracleCredential WITH IDENTITY = '$(ORACLE_USER)', SECRET = '$(ORACLE_PWD)';"
	@echo "$(GREEN)Oracle Credential 생성 완료$(NC)"

# Oracle External Data Source 생성
setup-polybase-datasource:
	@echo "$(YELLOW)=== Oracle External Data Source 생성 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'OracleDataSource') CREATE EXTERNAL DATA SOURCE OracleDataSource WITH (LOCATION = 'odbc://$(ORACLE_HOST):$(ORACLE_PORT)/$(ORACLE_SERVICE)', CONNECTION_OPTIONS = 'Driver={$(ORACLE_DRIVER)}', CREDENTIAL = OracleCredential);"
	@echo "$(GREEN)Oracle External Data Source 생성 완료$(NC)"

# PolyBase 전체 설정
setup-polybase: setup-polybase-enable setup-polybase-masterkey setup-polybase-credential setup-polybase-datasource
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)PolyBase Oracle 연결 설정 완료!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)사용 예시:$(NC)"
	@echo "  CREATE EXTERNAL TABLE OracleTable ("
	@echo "      col1 INT,"
	@echo "      col2 NVARCHAR(100)"
	@echo "  )"
	@echo "  WITH ("
	@echo "      LOCATION = 'SCHEMA.TABLE_NAME',"
	@echo "      DATA_SOURCE = OracleDataSource"
	@echo "  );"

# PolyBase 설정 확인
test-polybase:
	@echo "$(YELLOW)=== PolyBase 설정 확인 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT name, value_in_use FROM sys.configurations WHERE name = 'polybase enabled';"
	@echo ""
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); SELECT name FROM sys.database_scoped_credentials;"
	@echo ""
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); SELECT name, location FROM sys.external_data_sources;"

# ===========================================
# OPENROWSET + ODBC 방식 (Linux 권장)
# ===========================================

# Ad-hoc 분산 쿼리 활성화
setup-adhoc-queries:
	@echo "$(YELLOW)=== Ad-hoc 분산 쿼리 활성화 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;"
	@echo "$(GREEN)Ad-hoc 분산 쿼리 활성화 완료$(NC)"
	@echo ""
	@echo "$(YELLOW)사용 예시:$(NC)"
	@echo "  SELECT * FROM OPENROWSET("
	@echo "    'MSDASQL',"
	@echo "    'Driver={Oracle 23 ODBC driver};DBQ=$(ORACLE_HOST):$(ORACLE_PORT)/$(ORACLE_SERVICE);',"
	@echo "    'SELECT * FROM SCHEMA.TABLE'"
	@echo "  );"

# Ad-hoc 분산 쿼리 테스트 (Oracle DUAL 테이블)
test-adhoc:
	@echo "$(YELLOW)=== Ad-hoc 분산 쿼리 테스트 ===$(NC)"
	@echo "1. Ad-hoc 분산 쿼리 설정 확인..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT name, value_in_use FROM sys.configurations WHERE name = 'Ad Hoc Distributed Queries';"
	@echo ""
	@echo "2. Oracle DUAL 테이블 쿼리 테스트..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT * FROM OPENROWSET('MSDASQL', 'Driver={$(ORACLE_DRIVER)};DBQ=$(ORACLE_HOST):$(ORACLE_PORT)/$(ORACLE_SERVICE);UID=$(ORACLE_USER);PWD=$(ORACLE_PWD)', 'SELECT ''Connected!'' AS STATUS, SYSDATE AS ORACLE_TIME FROM DUAL');" 2>&1 || \
		echo "$(RED)Ad-hoc 쿼리 실패 - MSDASQL 드라이버가 설치되지 않았거나 Oracle 연결 오류$(NC)"

# Ad-hoc 쿼리로 Oracle 테이블 목록 조회
test-adhoc-tables:
	@echo "$(YELLOW)=== Oracle 테이블 목록 조회 (Ad-hoc) ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT * FROM OPENROWSET('MSDASQL', 'Driver={$(ORACLE_DRIVER)};DBQ=$(ORACLE_HOST):$(ORACLE_PORT)/$(ORACLE_SERVICE);UID=$(ORACLE_USER);PWD=$(ORACLE_PWD)', 'SELECT TABLE_NAME FROM USER_TABLES WHERE ROWNUM <= 10');" 2>&1 || \
		echo "$(RED)테이블 목록 조회 실패$(NC)"

# Ad-hoc 커스텀 쿼리 실행
test-adhoc-query:
	@echo "$(YELLOW)=== Ad-hoc 커스텀 쿼리 실행 ===$(NC)"
	@echo "Oracle 쿼리를 입력하세요 (예: SELECT * FROM DUAL)"
	@read -p "쿼리: " query; \
	kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT * FROM OPENROWSET('MSDASQL', 'Driver={$(ORACLE_DRIVER)};DBQ=$(ORACLE_HOST):$(ORACLE_PORT)/$(ORACLE_SERVICE);UID=$(ORACLE_USER);PWD=$(ORACLE_PWD)', '$$query');"

# ODBC 직접 연결 테스트 (isql 사용)
test-odbc-direct:
	@echo "$(YELLOW)=== ODBC 직접 연결 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		cat /etc/odbc.ini 2>/dev/null || echo "odbc.ini 없음"
	@echo ""
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		cat /etc/odbcinst.ini 2>/dev/null || echo "odbcinst.ini 없음"

# ===========================================
# Linked Server 설정 (Windows SQL Server용)
# ===========================================
# 참고: Linux SQL Server에서는 MSDASQL이 지원되지 않습니다.
# Linux에서는 위의 OPENROWSET 또는 PolyBase를 사용하세요.

# MSDASQL AllowInProcess 설정 (Windows 전용)
setup-linkedserver-provider:
	@echo "$(YELLOW)=== MSDASQL Provider 설정 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_configure 'show advanced options', 1; RECONFIGURE;"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC master.dbo.sp_MSset_oledb_prop 'MSDASQL', 'AllowInProcess', 1;" 2>/dev/null || \
		echo "$(YELLOW)sp_MSset_oledb_prop 사용 불가 - 대체 방법 시도$(NC)"
	@echo "$(GREEN)Provider 설정 완료$(NC)"

# Linked Server 생성
setup-linkedserver-create:
	@echo "$(YELLOW)=== Linked Server 생성 ===$(NC)"
	@echo "기존 Linked Server 삭제 시도..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"IF EXISTS (SELECT * FROM sys.servers WHERE name = '$(LINKED_SERVER_NAME)') EXEC sp_dropserver '$(LINKED_SERVER_NAME)', 'droplogins';" || true
	@echo "Linked Server 생성 중..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_addlinkedserver @server='$(LINKED_SERVER_NAME)', @srvproduct='Oracle', @provider='MSDASQL', @datasrc='$(LINKED_SERVER_DSN)';" || \
		(echo "$(RED)ERROR: sp_addlinkedserver 실패! MSDASQL provider가 설치되어 있는지 확인하세요.$(NC)" && exit 1)
	@echo "Linked Server 생성 확인 중..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = '$(LINKED_SERVER_NAME)') RAISERROR('Linked Server $(LINKED_SERVER_NAME) 생성 실패', 16, 1); ELSE PRINT 'Linked Server $(LINKED_SERVER_NAME) 확인됨';"
	@echo "$(GREEN)Linked Server 생성 완료$(NC)"

# Linked Server 로그인 설정
setup-linkedserver-login:
	@echo "$(YELLOW)=== Linked Server 로그인 설정 ===$(NC)"
	@echo "Linked Server 존재 여부 확인..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = '$(LINKED_SERVER_NAME)') RAISERROR('Linked Server $(LINKED_SERVER_NAME)가 존재하지 않습니다. 먼저 make setup-linkedserver-create를 실행하세요.', 16, 1);" || \
		(echo "$(RED)ERROR: Linked Server가 존재하지 않습니다!$(NC)" && exit 1)
	@echo "로그인 매핑 설정 중..."
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_addlinkedsrvlogin @rmtsrvname='$(LINKED_SERVER_NAME)', @useself='FALSE', @rmtuser='$(ORACLE_USER)', @rmtpassword='$(ORACLE_PWD)';"
	@echo "$(GREEN)로그인 설정 완료$(NC)"

# Linked Server 전체 설정
setup-linkedserver: setup-linkedserver-provider setup-linkedserver-create setup-linkedserver-login
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)Linked Server Oracle 연결 설정 완료!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)사용 예시:$(NC)"
	@echo "  -- OPENQUERY 사용 (권장)"
	@echo "  SELECT * FROM OPENQUERY($(LINKED_SERVER_NAME), 'SELECT * FROM SCHEMA.TABLE');"
	@echo ""
	@echo "  -- 4-part naming"
	@echo "  SELECT * FROM $(LINKED_SERVER_NAME)..SCHEMA.TABLE;"

# Linked Server 테스트
test-linkedserver:
	@echo "$(YELLOW)=== Linked Server 설정 확인 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT name, provider, data_source FROM sys.servers WHERE is_linked = 1;"
	@echo ""
	@echo "$(YELLOW)=== Linked Server 연결 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"EXEC sp_testlinkedserver '$(LINKED_SERVER_NAME)';" 2>&1 || echo "$(RED)연결 테스트 실패$(NC)"

# Linked Server로 Oracle 쿼리 실행
query-oracle:
	@echo "$(YELLOW)=== Oracle 쿼리 실행 (OPENQUERY) ===$(NC)"
	@read -p "Oracle 쿼리 입력: " query; \
	kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"SELECT * FROM OPENQUERY($(LINKED_SERVER_NAME), '$$query');"

# Linked Server 삭제
clean-linkedserver:
	@echo "$(YELLOW)=== Linked Server 삭제 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"IF EXISTS (SELECT * FROM sys.servers WHERE name = '$(LINKED_SERVER_NAME)') EXEC sp_dropserver '$(LINKED_SERVER_NAME)', 'droplogins';" || true
	@echo "$(GREEN)Linked Server 삭제 완료$(NC)"

# PolyBase 설정 삭제
clean-polybase:
	@echo "$(YELLOW)=== PolyBase 설정 삭제 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'OracleDataSource') DROP EXTERNAL DATA SOURCE OracleDataSource;" || true
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$(SA_PASSWORD)' -C -Q \
		"USE $(POLYBASE_DB); IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'OracleCredential') DROP DATABASE SCOPED CREDENTIAL OracleCredential;" || true
	@echo "$(GREEN)PolyBase 설정 삭제 완료$(NC)"

# MSSQL 연결 테스트
test-mssql:
	@echo "$(YELLOW)=== MSSQL 연결 테스트 ===$(NC)"
	@kubectl --context=$(KUBE_CONTEXT) exec deployment/$(RELEASE_NAME)-mssql-latest -n $(NAMESPACE) -- \
		/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Newpower1@' -C -Q "SELECT @@VERSION"

# 빌드 아티팩트 정리
clean:
	@echo "$(YELLOW)빌드 캐시 정리...$(NC)"
	docker image prune -f
	@echo "$(GREEN)정리 완료!$(NC)"

# 전체 프로세스 (빌드 + 푸시 + 배포)
all: build push deploy
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)전체 프로세스 완료!$(NC)"
	@echo "$(GREEN)========================================$(NC)"

# Oracle Instant Client 다운로드 안내
download-oracle:
	@echo "$(YELLOW)Oracle Instant Client 다운로드 방법$(NC)"
	@echo "=================================="
	@echo ""
	@echo "1. 아래 URL에서 Linux x64용 파일 다운로드:"
	@echo "   https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"
	@echo ""
	@echo "2. 필요한 파일:"
	@echo "   - instantclient-basic-linux.x64-23.6.0.24.10.zip"
	@echo "   - instantclient-odbc-linux.x64-23.6.0.24.10.zip"
	@echo ""
	@echo "3. 다운로드한 파일을 $(DOCKER_DIR)/ 디렉토리에 복사"
	@echo ""
	@echo "또는 wget으로 직접 다운로드:"
	@echo "  cd $(DOCKER_DIR)"
	@echo "  wget https://download.oracle.com/otn_software/linux/instantclient/2360000/instantclient-basic-linux.x64-23.6.0.24.10.zip"
	@echo "  wget https://download.oracle.com/otn_software/linux/instantclient/2360000/instantclient-odbc-linux.x64-23.6.0.24.10.zip"
