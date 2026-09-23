#!/bin/bash
set -euo pipefail

# write into log
exec > /var/log/runner-startup.log 2>&1
# Power off when the script ends, no matter how it ends
trap 'shutdown -h now' EXIT

export RUNNER_NAME="github-runner-$(hostname | cut -d'-' -f2)-$(date +%s)"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

GITHUB_TOKEN=$(aws ssm get-parameter \
  --name "${github_token_ssm}" \
  --with-decryption \
  --region "$REGION" \
  --query "Parameter.Value" --output text)

LABELS=$(IFS=,; echo "${runner_labels}")

# Ask GitHub for a single-use runner config
JIT=$(curl -sSf -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${github_owner}/${github_repo}/actions/runners/generate-jitconfig" \
  -d "$(jq -n --arg n "$RUNNER_NAME" --arg l "$LABELS" \
        '{name: $n, runner_group_id: 1, labels: ($l | split(","))}')" \
  | jq -r .encoded_jit_config)

# Move to runner folder
cd /opt/actions-runner

# Start runner with timeout
sudo -u ubuntu timeout 1h ./run.sh --jitconfig "$JIT"