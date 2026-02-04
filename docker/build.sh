#!/bin/bash

# MSSQL + Oracle Client 이미지 빌드 스크립트

set -e

# 기본값 설정
REGISTRY=${REGISTRY:-"your-registry"}
IMAGE_NAME=${IMAGE_NAME:-"mssql-oracle"}
TAG=${TAG:-"2022-latest"}
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MSSQL + Oracle Client 이미지 빌드${NC}"
echo -e "${GREEN}========================================${NC}"

# Oracle Instant Client 파일 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "\n${YELLOW}[1/4] Oracle Instant Client 파일 확인 중...${NC}"

BASIC_ZIP="instantclient-basic-linux.x64-23.6.0.24.10.zip"
ODBC_ZIP="instantclient-odbc-linux.x64-23.6.0.24.10.zip"

if [ ! -f "$BASIC_ZIP" ]; then
    echo -e "${RED}오류: $BASIC_ZIP 파일이 없습니다.${NC}"
    echo -e "${YELLOW}Oracle에서 다운로드하세요: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html${NC}"
    exit 1
fi

if [ ! -f "$ODBC_ZIP" ]; then
    echo -e "${RED}오류: $ODBC_ZIP 파일이 없습니다.${NC}"
    echo -e "${YELLOW}Oracle에서 다운로드하세요: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html${NC}"
    exit 1
fi

echo -e "${GREEN}Oracle Instant Client 파일 확인 완료!${NC}"

# Docker 이미지 빌드
echo -e "\n${YELLOW}[2/4] Docker 이미지 빌드 중...${NC}"
echo -e "이미지: ${FULL_IMAGE}"

docker build -t "$FULL_IMAGE" .

echo -e "${GREEN}이미지 빌드 완료!${NC}"

# 이미지 푸시 여부 확인
echo -e "\n${YELLOW}[3/4] 이미지 푸시${NC}"
read -p "이미지를 레지스트리에 푸시하시겠습니까? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}이미지 푸시 중...${NC}"
    docker push "$FULL_IMAGE"
    echo -e "${GREEN}이미지 푸시 완료!${NC}"
else
    echo -e "${YELLOW}이미지 푸시를 건너뜁니다.${NC}"
fi

# 완료 메시지
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}[4/4] 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Helm values.yaml 설정 방법:${NC}"
echo -e "
oracle:
  enabled: true
  useCustomImage: true
  customImage:
    repository: ${REGISTRY}/${IMAGE_NAME}
    tag: \"${TAG}\"
"
