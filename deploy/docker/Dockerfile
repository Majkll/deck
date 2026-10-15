FROM debian:trixie-slim

WORKDIR /workspace
COPY . /workspace

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl wget python3 ca-certificates fail2ban && \
    rm -rf /var/lib/apt/lists/*

CMD ["bash", "/workspace/bootstrap/bootstrap.sh", "--mode", "docker", "--flavor", "sysadmin"]
