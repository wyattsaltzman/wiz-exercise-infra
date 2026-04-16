# -----------------------------------------------------------------------
# MongoDB Backup Bucket
# INTENTIONAL WEAKNESS: Public read + public listing (required by exercise)
# -----------------------------------------------------------------------
resource "aws_s3_bucket" "mongodb_backup" {
  bucket        = "wiz-exercise-mongodb-backup-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "wiz-exercise-mongodb-backup"
    Purpose = "MongoDB daily backups (intentionally public)"
  }
}

# INTENTIONAL WEAKNESS: Disable the public access block to allow public ACL
resource "aws_s3_bucket_public_access_block" "mongodb_backup" {
  bucket = aws_s3_bucket.mongodb_backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# INTENTIONAL WEAKNESS: Public read + list policy
resource "aws_s3_bucket_policy" "mongodb_backup_public" {
  bucket = aws_s3_bucket.mongodb_backup.id

  depends_on = [aws_s3_bucket_public_access_block.mongodb_backup]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAndList"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.mongodb_backup.arn,
          "${aws_s3_bucket.mongodb_backup.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "mongodb_backup" {
  bucket = aws_s3_bucket.mongodb_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------
# CloudTrail Logs Bucket (private)
# -----------------------------------------------------------------------
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "wiz-exercise-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "wiz-exercise-cloudtrail-logs"
    Purpose = "CloudTrail audit logs"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------
# ECR Repository for the todo application
# -----------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "wiz-todo-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "wiz-todo-app"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
