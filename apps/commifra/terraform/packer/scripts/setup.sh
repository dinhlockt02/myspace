#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  curl \
  git \
  jq \
  unzip \
  docker.io \
  ca-certificates \
  gnupg

systemctl enable docker
usermod -aG docker ubuntu

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pnpm

curl -fsSL "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_arm64.zip" -o /tmp/terraform.zip
unzip /tmp/terraform.zip -d /usr/local/bin/
rm /tmp/terraform.zip

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

mkdir -p /opt/actions-runner
cd /opt/actions-runner
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz" -o runner.tar.gz
tar xzf runner.tar.gz
rm runner.tar.gz
chown -R ubuntu:ubuntu /opt/actions-runner

cat > /etc/systemd/system/actions-runner.service <<EOF
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=never

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
