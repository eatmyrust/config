FROM ubuntu:26.04 AS dev-container

# Bare Ubuntu, not the Microsoft devcontainers/base image -- this container is
# driven with nvim over a shell, not VS Code, so there's no reason to carry
# its devcontainer/Codespaces scaffolding. Root sets up only what `install`
# can't do for itself (the docker apt repo, the non-root user, sudo) in one
# consolidated apt install; everything else -- zsh framework, dotfiles, mise
# tools, nvim warm-up -- comes from running this repo's own `install` script
# as that user, so the container stays in lockstep with a real machine
# bootstrap instead of re-implementing it by hand. See docs/mise-migration.md.
#
# 26.04 specifically (not 22.04/24.04): mise installs prebuilt tool binaries
# (e.g. tree-sitter) linked against glibc >=2.39, which 22.04's glibc 2.35
# can't satisfy -- every treesitter parser failed to compile under it.
# 26.04 ships glibc 2.43.
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
    LC_ALL=en_US.UTF-8

# `docker run` doesn't forward the host's TERM unless told to (`-e
# TERM=$TERM`), and an unset TERM leaves zsh without a terminfo entry --
# `$terminfo[colors]` comes back empty, and powerlevel10k's 256-color escape
# codes render malformed (e.g. `38;5;242` collapses to `3242`) instead of
# just falling back to fewer colors. This default gets overridden by
# `-e TERM=$TERM` for anyone running from a real 256-color terminal.
ENV TERM=xterm-256color

# Switch out of root context
USER dev
WORKDIR /home/dev

ENV PATH=/home/dev/.local/share/mise/shims:/home/dev/.local/bin:${PATH}
ENV DOCKER_BUILDKIT=1

# The whole repo, not just dotfiles/ -- `install` is REPO_ROOT-relative and
# needs its own siblings (dotfiles/, docs/) to bootstrap the rest.
COPY --chown=dev:dev . /home/dev/config/

# install's own `apt-get update` (inside install_debian) re-populates
# /var/lib/apt/lists after the root RUN above already cleared it -- cleaned up
# here, in the same layer, so it doesn't end up baked into the image (a later
# RUN's cleanup can't shrink an earlier layer, but within one RUN it never
# reaches the final layer diff at all). Left alone in install itself: on a
# real machine you want apt's lists populated for subsequent apt search/list.
RUN /home/dev/config/install && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/zsh"]
