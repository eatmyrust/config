# syntax=docker/dockerfile:1
FROM ubuntu:26.04 AS dev-container

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt -y install --no-install-recommends ca-certificates curl && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ""$VERSION_CODENAME"") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt update && \
    apt -y install --no-install-recommends \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    containerd.io \
    locales \
    sudo && \
    locale-gen en_US.UTF-8 && \
    groupadd --gid 1001 dev && \
    useradd --create-home --shell /bin/zsh --uid 1001 --gid 1001 dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev && \
    apt clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

# Numeric so Kubernetes can verify runAsNonRoot from the image config.
USER 1001:1001
WORKDIR /home/dev

ENV PATH=/home/dev/.local/share/mise/shims:/home/dev/.local/bin:${PATH} \
    DOCKER_BUILDKIT=1

COPY --chown=dev:dev . /home/dev/.config/mise/

# The setup:skills task calls the GitHub API. CI passes a token so it isn't
# throttled by the anonymous rate limit on shared runner IPs. Local builds
# work without it.
RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    curl -fsSL https://mise.run | sh && \
    mise bootstrap --yes && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/dev/workdir /home/dev/.kube

ENTRYPOINT ["/bin/zsh"]
