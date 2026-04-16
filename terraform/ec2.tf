# Ubuntu 20.04 LTS (Focal) — intentionally outdated (released April 2020, 4+ years old)
data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "mongodb" {
  key_name   = "wiz-exercise-mongodb-key"
  public_key = file("${path.module}/../keys/mongodb.pub")
}

resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.ubuntu_20_04.id
  instance_type          = var.mongodb_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb_ec2.name
  key_name               = aws_key_pair.mongodb.key_name

  # INTENTIONAL WEAKNESS: outdated OS (Ubuntu 20.04) and outdated MongoDB (4.4)
  user_data = templatefile("${path.module}/../scripts/mongodb-userdata.sh", {
    s3_bucket_name         = aws_s3_bucket.mongodb_backup.bucket
    mongodb_password       = var.mongodb_password
    mongodb_admin_password = var.mongodb_admin_password
  })

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name    = "wiz-exercise-mongodb"
    Purpose = "MongoDB database server (intentionally misconfigured for Wiz exercise)"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
