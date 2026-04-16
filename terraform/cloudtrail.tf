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
# -----------------------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name = "wiz-exercise-guardduty"
  }
}

# -----------------------------------------------------------------------
# AWS Config — Preventative/detective control
# -----------------------------------------------------------------------
resource "aws_iam_role" "config" {
  name = "wiz-exercise-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "wiz-exercise-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "wiz-exercise-config-channel"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Managed Config rule: detect public S3 buckets (shows the backup bucket as non-compliant)
resource "aws_config_config_rule" "s3_bucket_public_read" {
  name = "wiz-exercise-s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
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

  depends_on = [aws_config_configuration_recorder_status.main]
}
