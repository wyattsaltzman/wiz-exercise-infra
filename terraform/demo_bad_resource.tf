# DEMO ONLY — intentionally insecure S3 bucket to trigger Checkov security gate
# This demonstrates the CI/CD pipeline blocking a misconfiguration before it reaches AWS
# DO NOT MERGE
resource "aws_s3_bucket" "demo_insecure" {
  bucket = "wiz-demo-insecure-bucket-do-not-merge"
}
