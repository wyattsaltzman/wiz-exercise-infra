module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Control plane is publicly accessible so kubectl works from CI and locally
  cluster_endpoint_public_access = true

  # Additional security group for custom rules
  cluster_additional_security_group_ids = [aws_security_group.eks_additional.id]

  # Enable IRSA (IAM Roles for Service Accounts) via OIDC
  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = [var.eks_node_instance_type]
      min_size       = 1
      max_size       = 4
      desired_size   = var.eks_desired_nodes

      labels = {
        role = "worker"
      }
    }
  }

  # Allow cluster creator admin access
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = var.cluster_name
  }
}

# -----------------------------------------------------------------------
# nginx Ingress Controller (creates AWS NLB — the CSP load balancer)
# -----------------------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.9.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------
# wiz-app namespace and MongoDB secret (managed by Terraform)
# -----------------------------------------------------------------------
resource "kubernetes_namespace" "wiz_app" {
  metadata {
    name = "wiz-app"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.wiz_app.metadata[0].name
  }

  data = {
    MONGO_URI = "mongodb://wiz:${var.mongodb_password}@${aws_instance.mongodb.private_ip}:27017/tododb"
  }

  depends_on = [kubernetes_namespace.wiz_app]
}
