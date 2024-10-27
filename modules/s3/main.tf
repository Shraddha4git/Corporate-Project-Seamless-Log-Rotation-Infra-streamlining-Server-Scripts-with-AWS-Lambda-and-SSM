resource "aws_s3_bucket" "app_bucket" {
  bucket = "tf-log-app-deployment-bucket-${random_string.suffix.result}"
  force_destroy = true
  
  tags = {
    Name        = "App Deployment Bucket"
    Environment = "Dev"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
   upper   = false
}

resource "aws_s3_object" "ssh_bastion_key" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key = "tf-10-24-test-key-pair.pem"
  source = "keys/tf-10-24-test-key-pair.pem"
  # content = file("keys/tf-infra-test-09-24.pem")
  acl = "private"
}




