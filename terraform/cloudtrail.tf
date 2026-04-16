# -----------------------------------------------------------------------
# CloudTrail — Control plane audit logging (required by exercise)
# -----------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "wiz-exercise-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]

  tags = {
    Name = "wiz-exercise-cloudtrail"
  }
}

# CloudWatch log group for CloudTrail events
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/wiz-exercise"
  retention_in_days = 30
}

# -----------------------------------------------------------------------
# GuardDuty — Detective control (required by exercise)
# CloudLabs pre-enables GuardDuty, so we reference the existing detector
# with a data source rather than creating a new one.
# -----------------------------------------------------------------------
data "aws_guardduty_detector" "main" {}

# -----------------------------------------------------------------------
# AWS Config — Preventative/detective control
# CloudLabs pre-creates the configuration recorder, so we only manage
# the Config rules here and attach them to the existing recorder.
# -----------------------------------------------------------------------

# Managed Config rule: detect public S3 buckets (flags the backup bucket)
resource "aws_config_config_rule" "s3_bucket_public_read" {
  name = "wiz-exercise-s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

# Managed Config rule: detect unrestricted SSH
resource "aws_config_config_rule" "restricted_ssh" {
  name = "wiz-exercise-restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
  }

  input_parameters = jsonencode({
    blockedPort1 = "22"
  })
}
