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

# Kubernetes Context
KUBE_CONTEXT ?= kwater-config

# 색상
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help build push deploy upgrade uninstall status logs shell test test-odbc test-network test-all test-mssql clean all

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
