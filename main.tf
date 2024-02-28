provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

resource "aws_vpc" "my_vpc" {
  # checkov:skip=CKV2_AWS_12: ADD REASON
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "baja-cluster-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  # checkov:skip=CKV_AWS_130: ADD REASON
  count = length(var.azs)
  
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index * 2)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private_subnet" {
  count = length(var.azs)
  
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index * 2 + 1)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false
  
  tags = {
    Name = "private-subnet-${count.index}"
  }
}

resource "aws_eks_cluster" "my_cluster" {
  name    = "baja-cluster"
  role_arn = aws_iam_role.cluster.arn
  version = "1.29"  # Kubernetes version
  
  vpc_config {
    subnet_ids = aws_subnet.private_subnet[*].id
    endpoint_private_access = true 
  }
}

resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "ng-1"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private_subnet[*].id
  instance_types  = ["t2.micro"]  # Set instance type to t3.large
  capacity_type   = "SPOT"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

resource "aws_iam_role" "cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "node" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
