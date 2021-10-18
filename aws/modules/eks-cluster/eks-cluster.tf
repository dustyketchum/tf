data "aws_subnet_ids" "subnet_ids" {
  vpc_id = var.vpc_id
}

#https://stackoverflow.com/questions/57495581/terraform-eks-tagging
resource "aws_ec2_tag" "subnet_tag" {
  for_each    = data.aws_subnet_ids.subnet_ids.ids
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.name}"
  value       = "1"
}

resource "aws_eks_cluster" "cluster" {
  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [var.cluster_depends_on]
  name     = var.name
  role_arn = var.role_arn
  vpc_config {
    subnet_ids = data.aws_subnet_ids.subnet_ids.ids
  }
}

resource "aws_eks_node_group" "workers" {
  cluster_name = aws_eks_cluster.cluster.name
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [var.workers_depend_on]
  instance_types  = var.instance_types
  node_group_name = var.name
  node_role_arn   = var.node_role_arn
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.desired_size
    min_size     = var.min_size
  }
  subnet_ids = data.aws_subnet_ids.subnet_ids.ids
}
