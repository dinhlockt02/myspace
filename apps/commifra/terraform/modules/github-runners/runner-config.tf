locals {
  common_tags = {
    Project = "myspace"
    App     = "commifra"
  }

  runner_startup_script = templatefile("${path.module}/scripts/startup.sh.tpl", {
    github_token_ssm = var.github_token_ssm
    github_owner     = var.github_owner
    github_repo      = var.github_repo
    runner_labels    = join(",", var.runner_labels)
  })
}
