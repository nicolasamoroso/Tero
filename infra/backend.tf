terraform {
  backend "s3" {
    bucket       = "tero-tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
