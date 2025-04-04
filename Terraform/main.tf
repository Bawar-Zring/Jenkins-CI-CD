# getting vpc id and show output vpc name CI/CD-vpc
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