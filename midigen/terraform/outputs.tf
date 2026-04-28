output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "alb_dns" {
  value = aws_lb.main.dns_name
}

output "s3_bucket" {
  value = aws_s3_bucket.midi.bucket
}