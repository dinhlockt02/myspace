#!/bin/bash
set -euo pipefail

exec > /var/log/runner-startup.log 2>&1

export RUNNER_NAME="github-runner-$(hostname | cut -d'-' -f2)-$(date +%s)"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

GITHUB_TOKEN=$(aws ssm get-parameter \
  --name "${github_token_ssm}" \
  --with-decryption \
  --region "$REGION" \
  --query "Parameter.Value" --output text)

REGISTRATION_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${github_owner}/${github_repo}/actions/runners/registration-token" \
  | jq -r '.token')

LABELS=$(IFS=,; echo "${runner_labels}")

cd /opt/actions-runner
sudo -u ubuntu ./config.sh \
  --url "https://github.com/${github_owner}/${github_repo}" \
  --token "$REGISTRATION_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$LABELS" \
  --unattended \
  --ephemeral \
  --replace

systemctl start actions-runner

while systemctl is-active --quiet actions-runner; do
  sleep 10
done

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
