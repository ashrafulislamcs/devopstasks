resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-${var.environment}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = "${var.cluster_name}-${var.environment}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    # Public endpoint left on for this assessment so kubectl works without a bastion/VPN.
    # In production this would be false, reachable only via VPN/Direct Connect + a bastion.
    endpoint_public_access  = true
  }

  # Send control plane logs to CloudWatch for auditing/troubleshooting
  enabled_cluster_log_types = ["api", "audit", "authenticator", "scheduler", "controllerManager"]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = { Environment = var.environment }
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-${var.environment}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Worker nodes live only in private subnets - no public IPs assigned
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${var.environment}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_count
    min_size     = var.node_min_count
    max_size     = var.node_max_count
  }

  # Roll nodes one at a time to avoid downtime during upgrades/resizes
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  tags = { Environment = var.environment }
}

# Security group used by RDS to allow access only from EKS worker nodes
resource "aws_security_group" "node_extra" {
  name   = "${var.cluster_name}-${var.environment}-node-extra-sg"
  vpc_id = var.vpc_id

  tags = { Environment = var.environment }
}
