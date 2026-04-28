terraform {
  backend "s3" {
    bucket         = "midigen-tf-state"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
