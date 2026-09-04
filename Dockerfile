FROM ubuntu:26.04 AS dev-container

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt -y install --no-install-recommends ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ""$VERSION_CODENAME"") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt update && \
    apt -y install --no-install-recommends \
    build-essential \
    dnsutils \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    containerd.io \
    git \
    locales \
    stow \
    sudo \
    unzip \
    wget \
    zsh && \
    locale-gen en_US.UTF-8 && \
    useradd --create-home --shell /bin/zsh dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev && \
    apt clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

USER dev
WORKDIR /home/dev

ENV PATH=/home/dev/.local/share/mise/shims:/home/dev/.local/bin:${PATH} \
    DOCKER_BUILDKIT=1

COPY --chown=dev:dev . /home/dev/config/

RUN /home/dev/config/install && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/dev/workdir

ENTRYPOINT ["/bin/zsh"]
