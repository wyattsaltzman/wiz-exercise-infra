# Data sources used across modules
# aws_caller_identity is defined in iam.tf

locals {
  common_tags = {
    Project     = "wiz-exercise"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
