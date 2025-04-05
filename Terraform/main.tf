provider "aws" {
  region = "us-east-1"  
}

data "aws_vpc" "ci-cd_vpc" {
  tags = {
    Name = "CI/CD-vpc"
  }
}

output "vpc_id" {
  value = data.aws_vpc.ci-cd_vpc.id
}

data "aws_subnet" "private1" {
  tags = {
    Name = "CI/CD-subnet-private1-us-east-1a"
  }
}

output "subnet_id_private1" {
  value = data.aws_subnet.private1.id
}

data "aws_subnet" "private2" {
  tags = {
    Name = "CI/CD-subnet-private2-us-east-1b"
  }
}

output "subnet_id_private2" {
  value = data.aws_subnet.private2.id
}

resource "aws_iam_policy" "eks_policy" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policy_test_repo"
  description = "IAM policy for EKS EFS CSI driver"
  policy      = file("iam-policy.json")
}

resource "aws_iam_role" "eks_role" {
  name               = "AmazonEKS_EFS_CSI_Driver_Role_test_repo"
  assume_role_policy = file("trust-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  policy_arn = aws_iam_policy.eks_policy.arn
  role       = aws_iam_role.eks_role.name
}

resource "aws_security_group" "eks-cluster" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id = data.aws_vpc.ci-cd_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "eks-cluster-sg"
    }
}

resource "aws_iam_role" "eks-role" {
  name = "eks-role-jenkins-new-repo"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks-role.arn
  vpc_config {
    subnet_ids = [data.aws_subnet.private1.id, data.aws_subnet.private2.id]
    security_group_ids = [aws_security_group.eks-cluster.id]
  }
} 

resource "aws_iam_role" "eks-node-role" {
  name = "eks-node-role-jenkins-new-repo"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "efs_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_eks_node_group" "eks-node-group" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks-node-role.arn
  subnet_ids      = [data.aws_subnet.private1.id, data.aws_subnet.private2.id]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"
}

resource "aws_iam_policy" "efs_access_policy" {
  name        = "EFSAccessPolicy-repo"
  description = "IAM policy to allow EKS nodes to access EFS"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs_access_policy_attachment" {
  policy_arn = aws_iam_policy.efs_access_policy.arn
  role       = aws_iam_role.eks-node-role.name
}

