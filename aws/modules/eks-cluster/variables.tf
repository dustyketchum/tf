variable cluster_depends_on {
  type = list
}

variable desired_size {
  default = "1"
  type    = string
}

variable instance_types {
  default = ["t3.small"]
  type    = list
}

variable min_size {
  default = "1"
  type    = string
}

variable name {
  type = string
}

variable node_role_arn {
  type = string
}

variable role_arn {
  type = string
}

variable vpc_id {
  type = string
}

variable workers_depend_on {
  type = list
}
