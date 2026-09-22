terraform {
  backend "s3" {
    bucket = "comminfra.myspace.dinhloc.dev"
    key    = "commifra/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
