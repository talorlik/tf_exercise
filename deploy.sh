#!/bin/bash

# Check is Docker is installed
if ! command -v docker &> /dev/null; then
    apt-get update
    if ! command -v curl &> /dev/null; then
        apt-get install curl -y
    fi
    apt-get install ca-certificates -y
    # Add Docker's official GPG key:
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    groupadd docker
    usermod -aG docker $USER
    newgrp docker
    systemctl enable docker.service
    systemctl enable containerd.service
    # Write Docker daemon configuration
    tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

    # Restart Docker to apply the new configuration
    systemctl restart docker
fi

if ! systemctl is-active --quiet docker; then
    systemctl start docker
fi
