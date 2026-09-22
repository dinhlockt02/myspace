packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "runner_version" {
  type    = string
  default = "2.322.0"
}

data "amazon-ami" "ubuntu_amd64" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.region
}

source "amazon-ebs" "runner" {
  ami_name      = "github-runner-amd64-${var.runner_version}-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.region
  source_ami    = data.amazon-ami.ubuntu_amd64.id
  ssh_username  = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project       = "myspace"
    App           = "commifra"
    Module        = "github-runners"
    Name          = "github-runner-amd64"
    RunnerVersion = var.runner_version
    ManagedBy     = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.runner"]

  provisioner "shell" {
    script          = "${path.root}/scripts/setup.sh"
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
    environment_vars = [
      "RUNNER_VERSION=${var.runner_version}"
    ]
  }
}
