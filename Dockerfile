FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --yes --no-install-recommends \
        ca-certificates \
        coreutils \
        cron \
        curl \
        fuse-overlayfs \
        git \
        gnupg \
        jq \
        wget \
    && rm -rf /var/lib/apt/lists/*

# https://github.com/cli/cli/blob/d994a9cf5e267b694e95d62f6974b08089dd635c/docs/install_linux.md#debian
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install -y gh \
    && rm -rf /var/lib/apt/lists/*

# https://docs.docker.com/engine/install/ubuntu/
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: noble\nComponents: stable\nSigned-By: /etc/apt/keyrings/docker.asc" | tee /etc/apt/sources.list.d/docker.sources > /dev/null \
    && apt update \
    && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# https://github.com/nodesource/distributions/blob/904ee90df149f1eb1688dd07ef77b57ffa35d83f/DEV_README.md#using-ubuntu-nodejs-22
RUN curl -fsSL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh \
    && bash nodesource_setup.sh \
    && apt install -y nodejs \
    && rm nodesource_setup.sh \
    && rm -rf /var/lib/apt/lists/*

COPY main.sh docker-bootstrap.sh run-in-devcontainer.sh /
RUN chmod +x /main.sh /docker-bootstrap.sh /run-in-devcontainer.sh

ARG CRON_SCHEDULE
ARG REPO_NAME
ARG BUILD_COMMAND
ARG RELEASE_ASSET
RUN echo "${CRON_SCHEDULE} REPO_NAME=${REPO_NAME} BUILD_COMMAND=\"${BUILD_COMMAND}\" RELEASE_ASSET=${RELEASE_ASSET} /main.sh >> /var/log/cron.log 2>&1" | crontab -
