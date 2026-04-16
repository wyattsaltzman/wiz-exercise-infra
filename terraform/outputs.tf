output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "mongodb_public_ip" {
  description = "Public IP of the MongoDB EC2 instance (for SSH access)"
  value       = aws_instance.mongodb.public_ip
}

output "mongodb_private_ip" {
  description = "Private IP of the MongoDB EC2 instance (used by EKS app)"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_backup_bucket" {
  description = "S3 bucket name for MongoDB backups"
  value       = aws_s3_bucket.mongodb_backup.bucket
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL for the todo application"
  value       = aws_ecr_repository.app.repository_url
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "ssh_to_mongodb" {
  description = "Command to SSH into the MongoDB VM"
  value       = "ssh -i keys/mongodb ubuntu@${aws_instance.mongodb.public_ip}"
}
