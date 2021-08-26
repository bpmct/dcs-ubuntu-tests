FROM ubuntu:18.04

ENV VERSION=v3.11.1

RUN apt-get update \
 && apt-get install -y \
    curl \
    dumb-init \
    zsh \
    htop \
    locales \
    man \
    wget \
    nano \
    git \
    procps \
    openssh-client \
    sudo \
    vim.tiny \
    lsb-release \
  && rm -rf /var/lib/apt/lists/*

# https://wiki.debian.org/Locale#Manually
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8

RUN adduser --gecos '' --disabled-password coder && \
  echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

# install code-server
RUN curl -fsSL https://code-server.dev/install.sh | VERSION=$VERSION sh

# download the original entrypoint
RUN wget https://raw.githubusercontent.com/cdr/code-server/$VERSION/ci/release-image/entrypoint.sh --directory-prefix=/usr/bin

# now the deploy-code-server stuff (potentially some overlap)

USER 1000
ENV USER=coder
WORKDIR /home/coder

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip -y
RUN curl https://rclone.org/install.sh | sudo bash
RUN sudo apt-get install software-properties-common -y

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions for code-server
RUN sudo chown -R coder:coder /home/coder/.local

# You can add custom software and dependencies for your environment below
# -----------
# Install NodeJS
RUN sudo curl -fsSL https://deb.nodesource.com/setup_15.x | sudo bash -
RUN sudo apt-get install -y nodejs
RUN sudo wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
RUN sudo dpkg -i ./cloudflared-linux-amd64.deb
# SSH (commented out, you need a -y, and Docker doesn't support systemd by default so you would need to replace line 74 with "RUN openssh-server&" or something
#RUN sudo apt install openssh-server
#RUN sudo service ssh start

#Packages
RUN sudo apt-get install apt-utils -y
RUN sudo apt-get install wget -y
RUN sudo apt-get install speedtest-cli -y
RUN sudo apt-get install neofetch -y

# Install a VS Code extension:
# Note: we use a different marketplace than VS Code. See https://github.com/cdr/code-server/blob/main/docs/FAQ.md#differences-compared-to-vs-code
RUN code-server --install-extension esbenp.prettier-vscode
RUN code-server --install-extension Equinusocio.vsc-material-theme
RUN code-server --install-extension PKief.material-icon-theme

# Install apt packages:
# RUN sudo apt-get install -y ubuntu-make

# Copy files: 
# COPY deploy-container/myTool /home/coder/myTool

# -----------

# Port
ENV PORT=8080
ENV RCLONE_DATA=TRUE
ENV RCLONE_SOURCE=/home/coder/project/downloads
ENV RCLONE_DESTINATION=code-server-files
ENV RCLONE_VSCODE_TASKS=true

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh
ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]
