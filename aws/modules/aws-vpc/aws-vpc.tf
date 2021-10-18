data "aws_availability_zones" "available" {}

resource "aws_eip" "nat" {
  count = length(data.aws_availability_zones.available.names)
  vpc   = true
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

#https://www.reddit.com/r/Terraform/comments/bboitl/can_not_reference_aws_eipid_the_eip_allocation_id/ekk9xlt/?context=8&depth=9
resource "aws_nat_gateway" "nat_gateway" {
  count = length(data.aws_availability_zones.available.names)
  depends_on    = [
    aws_internet_gateway.internet_gateway
  ]
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = aws_subnet.public.*.id[count.index]
}

resource "aws_route_table" "private" {
  count = length(data.aws_availability_zones.available.names)
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
  tags = {
    Name = "private"
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "public" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "public"
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "private" {
  count          = length(data.aws_availability_zones.available.names)
  route_table_id = aws_route_table.private.*.id[count.index]
  subnet_id      = aws_subnet.private.*.id[count.index]
}

#https://tarmak.readthedocs.io/en/latest/existing-vpc.html
resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.public.id
}

#The subnets must be tagged appropriately for the ALB to use them correctly
#https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/walkthrough/echoserver/
#the other cluster specific tag is created in the module that creates the cluster
resource "aws_subnet" "private" {
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.cidr_block, var.mask_bits, length(data.aws_availability_zones.available.names) + count.index)
  count                   = length(data.aws_availability_zones.available.names)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-PrivateSubnet"
    "kubernetes.io/role/internal-elb" = 1
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.cidr_block, var.mask_bits, count.index)
  count                   = length(data.aws_availability_zones.available.names)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-PublicSubnet"
    "kubernetes.io/role/elb" = 1
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.name
  }
}
