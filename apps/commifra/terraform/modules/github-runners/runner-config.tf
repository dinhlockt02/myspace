locals {
  common_tags = {
    Project = "myspace"
    App     = "commifra"
  }

  runner_startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    exec > /var/log/runner-startup.log 2>&1

    export RUNNER_NAME="github-runner-$$(hostname | cut -d'-' -f2)-$$(date +%s)"

    REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    INSTANCE_ID=$$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    GITHUB_TOKEN=$$(aws ssm get-parameter \
      --name "${var.github_token_ssm}" \
      --with-decryption \
      --region "$$REGION" \
      --query "Parameter.Value" --output text)

    REGISTRATION_TOKEN=$$(curl -s -X POST \
      -H "Authorization: token $$GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/${var.github_owner}/${var.github_repo}/actions/runners/registration-token" \
      | jq -r '.token')

    LABELS=$$(IFS=,; echo "${join(",", var.runner_labels)}")

    cd /opt/actions-runner
    sudo -u ubuntu ./config.sh \
      --url "https://github.com/${var.github_owner}/${var.github_repo}" \
      --token "$$REGISTRATION_TOKEN" \
      --name "$$RUNNER_NAME" \
      --labels "$$LABELS" \
      --unattended \
      --ephemeral \
      --replace

    systemctl start actions-runner

    while systemctl is-active --quiet actions-runner; do
      sleep 10
    done

    aws ec2 terminate-instances --instance-ids "$$INSTANCE_ID" --region "$$REGION"
  EOT
}
