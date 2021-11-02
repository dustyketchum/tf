module "us-west-2-acm-cert" {
  domain_name = "highestpavedroadsinthealps.com"
  fqdn        = "us-west-2.highestpavedroadsinthealps.com"
  source      = "../../modules/aws-acm-certificate"
}

module "eks-iam-roles" {
  name   = "usw2"
  source = "../../modules/eks-iam-roles"
}

#The number of subnets can't be determined prior to the first terraform apply, resulting in an error.
#The article suggests targeted apply to work around this problem.
#https://discuss.hashicorp.com/t/for-each-value-depends-on-resource-attributes-that-cannot-be-determined-until-apply/6061/2
module "eks-prod-01" {
  cluster_depends_on = module.eks-iam-roles.cluster_attachments
  name               = "usw2-prod-01"
  node_role_arn      = module.eks-iam-roles.node_role_arn
  role_arn           = module.eks-iam-roles.role_arn
  source             = "../../modules/eks-cluster"
  vpc_id             = module.vpc-prod.vpc_id
  workers_depend_on  = module.eks-iam-roles.worker_attachments
}

module "vpc-prod" {
  cidr_block = "10.128.0.0/16"
  name       = "usw2-prod"
  source     = "../../modules/aws-vpc"
}

provider "aws" {
  region = "us-west-2"
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster"]
  }
}

terraform {
  required_version = ">= 0.14.0"
}
