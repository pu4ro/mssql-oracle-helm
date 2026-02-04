FROM mcr.microsoft.com/mssql/server:2022-latest

# 루트 권한으로 전환하여 설치 진행
USER root

# 필수 패키지 및 libaio 설치 (오라클 클라이언트 필수 의존성)
RUN apt-get update && apt-get install -y unzip libaio1 wget && rm -rf /var/lib/apt/lists/*

# 오라클 클라이언트 설치 경로 생성
RUN mkdir -p /opt/oracle
WORKDIR /opt/oracle

# 로컬에 다운로드한 리눅스용 zip 파일들을 이미지로 복사
# 빌드 전에 아래 파일들을 docker 디렉토리에 다운로드해야 합니다
COPY instantclient-basic-linux.x64-23.6.0.24.10.zip .
COPY instantclient-odbc-linux.x64-23.6.0.24.10.zip .

# 압축 해제 및 파일 정리 (-o: 덮어쓰기 자동 승인)
RUN unzip -o instantclient-basic-linux.x64-23.6.0.24.10.zip && \
    unzip -o instantclient-odbc-linux.x64-23.6.0.24.10.zip && \
    rm *.zip

# 환경 변수 설정
ENV LD_LIBRARY_PATH="/opt/oracle/instantclient_23_6"
ENV PATH="$PATH:/opt/oracle/instantclient_23_6"

# TNS 설정 디렉토리 생성 (ConfigMap으로 마운트될 예정)
RUN mkdir -p /var/opt/mssql/oracle/network/admin
ENV TNS_ADMIN="/var/opt/mssql/oracle/network/admin"

# 작업 디렉토리 복원
WORKDIR /

# 다시 mssql 유저로 전환 (보안 권장사항)
USER mssql
