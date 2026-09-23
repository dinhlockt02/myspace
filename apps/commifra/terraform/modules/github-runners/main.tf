data "aws_ami" "runner" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["github-runner-amd64-*"]
  }

  filter {
    name   = "tag:Name"
    values = ["github-runner-amd64"]
  }

  filter {
    name   = "tag:App"
    values = ["commifra"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "runner" {
  name_prefix = "commifra-github-runner-"
  description = "Security group for GitHub Actions runner instances"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "lambda" {
  name_prefix = "commifra-github-runner-lambda-"
  description = "Security group for GitHub runner Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "runner" {
  name_prefix = "commifra-github-runner-"
  image_id    = data.aws_ami.runner.id

  instance_type = var.instance_types[0]

  iam_instance_profile {
    name = aws_iam_instance_profile.runner.name
  }

  vpc_security_group_ids = [aws_security_group.runner.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.block_device_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
      spot_instance_type             = "one-time"
    }
  }

  user_data = base64encode(local.runner_startup_script)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name   = "commifra-github-runner"
      Module = "github-runners"
    })
  }

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })

  lifecycle {
    create_before_destroy = true
  }

  update_default_version = true
  instance_initiated_shutdown_behavior = "terminate"
}

resource "aws_autoscaling_group" "runner" {
  name_prefix         = "commifra-github-runner-"
  min_size            = var.min_count
  max_size            = var.max_count
  desired_capacity    = var.min_count
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.runner.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Module = "github-runners" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
