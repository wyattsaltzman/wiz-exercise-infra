# -----------------------------------------------------------------------
# MongoDB VM Security Group
# Intentional weaknesses (required by exercise):
#   - SSH (22) open to the public internet
#   - EC2 has overly permissive IAM role
# -----------------------------------------------------------------------
resource "aws_security_group" "mongodb" {
  name        = "wiz-exercise-mongodb-sg"
  description = "Security group for MongoDB VM"
  vpc_id      = aws_vpc.main.id

  # INTENTIONAL WEAKNESS: SSH open to the internet
  ingress {
    description = "SSH from internet (intentional weakness)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB access restricted to EKS private subnets only
  ingress {
    description = "MongoDB from EKS private subnets"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wiz-exercise-mongodb-sg"
  }
}

# -----------------------------------------------------------------------
# EKS Cluster Security Group (additional rules)
# -----------------------------------------------------------------------
resource "aws_security_group" "eks_additional" {
  name        = "wiz-exercise-eks-additional-sg"
  description = "Additional security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wiz-exercise-eks-additional-sg"
  }
}
