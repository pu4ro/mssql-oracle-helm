FROM ubuntu:22.04

# 비대화형 모드 설정
ENV DEBIAN_FRONTEND=noninteractive
ENV ACCEPT_EULA=Y

# 필수 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    software-properties-common \
    unzip \
    libaio1 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Microsoft GPG 키 및 저장소 추가
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list > /etc/apt/sources.list.d/mssql-server-2022.list

# SQL Server 설치
RUN apt-get update && \
    apt-get install -y mssql-server && \
    rm -rf /var/lib/apt/lists/*

# 오라클 클라이언트 설치 경로 생성
RUN mkdir -p /opt/oracle
WORKDIR /opt/oracle

# 오라클 Instant Client 복사
COPY instantclient-basic-linux.x64-23.6.0.24.10.zip .
COPY instantclient-odbc-linux.x64-23.6.0.24.10.zip .
COPY instantclient-sqlplus-linux.x64-23.6.0.24.10.zip .

# 압축 해제 및 정리
RUN unzip -o instantclient-basic-linux.x64-23.6.0.24.10.zip && \
    unzip -o instantclient-odbc-linux.x64-23.6.0.24.10.zip && \
    unzip -o instantclient-sqlplus-linux.x64-23.6.0.24.10.zip && \
    rm *.zip

# 환경 변수 설정
ENV LD_LIBRARY_PATH="/opt/oracle/instantclient_23_6"
ENV PATH="$PATH:/opt/oracle/instantclient_23_6:/opt/mssql/bin:/opt/mssql-tools/bin"

# TNS 설정 디렉토리
RUN mkdir -p /var/opt/mssql/oracle/network/admin
ENV TNS_ADMIN="/var/opt/mssql/oracle/network/admin"

# SQL Server 데이터 디렉토리 권한 설정
RUN mkdir -p /var/opt/mssql && chown -R mssql:mssql /var/opt/mssql

WORKDIR /

# mssql 사용자로 전환
USER mssql

# SQL Server 포트
EXPOSE 1433

# SQL Server 시작
CMD ["/opt/mssql/bin/sqlservr"]
