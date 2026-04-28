resource "aws_s3_bucket" "midi" {
  bucket        = local.resource_names.s3_bucket
  force_destroy = var.environment != "prod"

  tags = { Name = local.resource_names.s3_bucket }
}

resource "aws_s3_bucket_versioning" "midi" {
  bucket = aws_s3_bucket.midi.id
  versioning_configuration {
    status = var.environment == "prod" ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "midi" {
  bucket = aws_s3_bucket.midi.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "midi" {
  bucket                  = aws_s3_bucket.midi.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
