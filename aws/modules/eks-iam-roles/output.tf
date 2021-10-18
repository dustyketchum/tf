output cluster_attachments {
  value = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController
  ]
}

output node_role_arn {
  value = aws_iam_role.workers.arn
}

output role_arn {
  value = aws_iam_role.cluster.arn
}

output worker_attachments {
  value = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
