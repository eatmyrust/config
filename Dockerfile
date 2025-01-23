FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04 AS dev-container

# Retrieve VSCode apt index
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg && \
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
    # Retrieve trivy apt index
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list > /dev/null && \
    # Retrieve helm apt index
    curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor -o /etc/apt/keyrings/helm.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null && \
    # Retrieve kubectl apt index
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null && \
    # Retrieve docker apt index
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ""$VERSION_CODENAME"") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    # Retrieve packer apt index
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/packer.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packer.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/packer.list > /dev/null && \
    # Retrieve python apt index
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf23c5a6cf475977595c89f51ba6932366a755776" | gpg --dearmor -o /etc/apt/keyrings/deadsnakes.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/deadsnakes.list && \
    echo "deb-src [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" | tee -a /etc/apt/sources.list.d/deadsnakes.list && \
    # Install ripgrep
    curl -LO https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep_13.0.0_amd64.deb && \
    sudo dpkg -i ripgrep_13.0.0_amd64.deb && rm -f ripgrep_13.0.0_amd64.deb && \
    # Install convco
    curl -OL https://github.com/convco/convco/releases/latest/download/convco-deb.zip && \
    unzip convco-deb.zip && \
    dpkg -i convco*.deb && rm -f covco-deb.zip && rm -f convco*.deb && \
    # Install kubeseal
    KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-) && \
    wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" && \
    tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal && \
    install -m 755 kubeseal /usr/bin/kubeseal && \
    # Install aws cli
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm awscliv2.zip && rm -rf ./aws && \
    # Install eksctl
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" && \
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep Linux_amd64 | sha256sum --check && \
    tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && rm eksctl_Linux_amd64.tar.gz && \
    mv /tmp/eksctl /usr/local/bin && \
    # Install k9s
    curl -sLO "https://github.com/derailed/k9s/releases/download/v0.31.8/k9s_Linux_amd64.tar.gz" && \
    tar -xzf k9s_Linux_amd64.tar.gz -C /tmp && rm k9s_Linux_amd64.tar.gz && \
    mv /tmp/k9s /usr/local/bin && \
    # Install stern
    curl -sLO "https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz" && \
    tar -xzf stern_1.28.0_linux_amd64.tar.gz -C /tmp && rm stern_1.28.0_linux_amd64.tar.gz && \
    mv /tmp/stern /usr/local/bin && \
    # Install go
    curl -sLO "https://go.dev/dl/go1.22.0.linux-amd64.tar.gz" && \
    tar -xzf go1.22.0.linux-amd64.tar.gz -C /tmp && rm go1.22.0.linux-amd64.tar.gz && \
    mv /tmp/go /usr/local && \
    # Install argo
    curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/argo-linux-amd64.gz && \
    gunzip argo-linux-amd64.gz && \
    chmod +x argo-linux-amd64 && \
    mv ./argo-linux-amd64 /usr/local/bin/argo && \
    # Install argocd
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    install -m 555 argocd-linux-amd64 /usr/bin/argocd && \
    rm argocd-linux-amd64 && \
    # Install kubectx
    git clone https://github.com/ahmetb/kubectx /opt/kubectx && \
    ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx && \
    ln -s /opt/kubectx/kubens /usr/local/bin/kubens && \
    # Install 1pass cli
    curl "https://cache.agilebits.com/dist/1P/op2/pkg/v2.25.0/op_linux_amd64_v2.25.0.zip" -o op.zip && \
    unzip -d op op.zip && \
    mv op/op /usr/local/bin/ && \
    rm -r op.zip op && \
    # Install OPA
    OPA_VERSION=$(curl -s https://api.github.com/repos/open-policy-agent/opa/tags | jq -r '.[0].name' | cut -c 2-) && \
    curl -L -o opa https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_amd64_static && \
    install -m 755 opa /usr/local/bin/opa && \
    # Install regal (rego formatter)
    curl -L -o regal "https://github.com/StyraInc/regal/releases/latest/download/regal_Linux_x86_64" && \
    install -m 755 regal /usr/local/bin/regal && \
    # Instal oras
    ORAS_VERSION=$(curl -s https://api.github.com/repos/oras-project/oras/tags | jq -r '.[0].name' | cut -c 2-) && \
    curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" && \
    mkdir -p oras-install/ && \
    tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install/ && \
    install oras-install/oras /usr/local/bin/oras && \
    rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install/ && \
    # Install uv
    curl -LsSf https://astral.sh/uv/install.sh | sh \
    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local && \
    # Install coder
    curl -fsSL https://coder.com/install.sh | sh && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Switch out of root context
USER vscode
WORKDIR /home/vscode

# Configuration
ENV PATH=${PATH}:/usr/local/go/bin:/home/vscode/go/bin:/home/vscode/.pulumi/bin
ENV DOCKER_BUILDKIT=1 \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64/
COPY --chown=vscode:vscode dotfiles/ /home/vscode/

# ZSH Experience
RUN sudo chsh -s /bin/zsh vscode && \
    /bin/zsh && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k && \
    GITSTATUS_CACHE_DIR=/home/vscode/powerlevel10k/gitstatus/usrbin ~/powerlevel10k/gitstatus/install -f -s "linux" -m "x86_64" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git /home/vscode/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions /home/vscode/.oh-my-zsh/custom/plugins/zsh-completions && \
    # Install All Tools
    sudo apt update && \
    sudo apt -y install \
    vim \
    dnsutils \
    code \
    nodejs \
    python3.11 \
    python3.11-venv \
    openjdk-17-jre \
    kubectl \
    helm \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    packer \
    tmux && \
    sudo apt clean && sudo rm -rf /var/lib/apt/lists/* && \
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/tags | jq -r '.[0].name' | cut -c 2-) && \
    git clone --depth=1 --branch v${NVM_VERSION} https://github.com/nvm-sh/nvm.git /home/vscode/.nvm && \
    go install chainguard.dev/apko@latest && \
    go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest && \
    go install github.com/google/go-containerregistry/cmd/crane@latest && \
    curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | sudo bash && \
    curl -fsSL https://get.pulumi.com | sh && \
    # Install VSCode Extensions
    code --extensions-dir /home/vscode/.vscode-server/extensions \
    --install-extension "ms-azuretools.vscode-docker" \
    --install-extension "streetsidesoftware.code-spell-checker" \
    --install-extension "redhat.vscode-yaml" \
    --install-extension "ms-vsliveshare.vsliveshare" \
    --install-extension "donjayamanne.githistory" \
    --install-extension "bradlc.vscode-tailwindcss" \
    --install-extension "gruntfuggly.todo-tree" \
    --install-extension "eamodio.gitlens" \
    --install-extension "usernamehw.errorlens" \
    --install-extension "tamasfe.even-better-toml" \
    --install-extension "sonarsource.sonarlint-vscode" \
    --install-extension "yzhang.markdown-all-in-one" \
    --install-extension "ms-vscode.vscode-typescript-next" \
    --install-extension "dbaeumer.vscode-eslint" \
    --install-extension "charliermarsh.ruff" \
    --install-extension "ms-python.black-formatter" \
    --install-extension "ms-python.python" \
    --install-extension "ms-python.vscode-pylance" \
    --install-extension "ms-python.mypy-type-checker" \
    --install-extension "ms-kubernetes-tools.vscode-kubernetes-tools" \
    --install-extension "mindaro.mindaro" \
    --install-extension "mindaro-dev.file-downloader" \
    --install-extension "vscodevim.vim" \
    --install-extension "tsandall.opa" \
    --install-extension "github.copilot" \
    --install-extension "github.copilot-chat" && \
    code-server --install-extension "ms-azuretools.vscode-docker" \
    --install-extension "streetsidesoftware.code-spell-checker" \
    --install-extension "redhat.vscode-yaml" \
    --install-extension "donjayamanne.githistory" \
    --install-extension "bradlc.vscode-tailwindcss" \
    --install-extension "gruntfuggly.todo-tree" \
    --install-extension "eamodio.gitlens" \
    --install-extension "usernamehw.errorlens" \
    --install-extension "tamasfe.even-better-toml" \
    --install-extension "sonarsource.sonarlint-vscode" \
    --install-extension "yzhang.markdown-all-in-one" \
    --install-extension "ms-vscode.vscode-typescript-next" \
    --install-extension "dbaeumer.vscode-eslint" \
    --install-extension "charliermarsh.ruff" \
    --install-extension "ms-python.black-formatter" \
    --install-extension "ms-python.python" \
    --install-extension "ms-python.mypy-type-checker" \
    --install-extension "ms-kubernetes-tools.vscode-kubernetes-tools" \
    --install-extension "vscodevim.vim" \
    --install-extension "tsandall.opa" \
    --install-extension "github.copilot" \
    --install-extension "github.copilot-chat" && \
    # Default Dark Theme In Browser
    mkdir -p /home/vscode/.local/share/code-server/User && touch /home/vscode/.local/share/code-server/User/settings.json && \
    echo -n '{"workbench.colorTheme": "Default Dark+"}' > /home/vscode/.local/share/code-server/User/settings.json && \
    # Install Vim-Plug, Vundle, and plugins
    curl -fsSLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim && \
    git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim && \
    vim -e -u /home/vscode/.vimrc +'PlugInstall --sync' +qa && \
    vim -e -u /home/vscode/.vimrc +'PluginInstall --sync' +qa

ENTRYPOINT ["/bin/zsh"]
