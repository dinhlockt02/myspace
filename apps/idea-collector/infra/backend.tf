terraform {
  backend "s3" {
    bucket = "comminfra.myspace.dinhloc.dev"
    key    = "commifra/idea-collector.tfstate"
    region = "ap-southeast-1"
  }
}
