terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- Networking ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "red-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "private-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnet outbound access
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups (Best Practice: Standalone Rules) ---

resource "aws_security_group" "common" {
  name        = "common-rules"
  description = "Internal traffic and common rules"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "internal_all" {
  security_group_id = aws_security_group.common.id
  referenced_security_group_id = aws_security_group.common.id
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_out" {
  security_group_id = aws_security_group.common.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "ssh" {
  name   = "ssh-access"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.ssh.id
  cidr_ipv4         = "0.0.0.0/0" # Temporary for debugging
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Allow EC2 Instance Connect for ap-south-1
resource "aws_vpc_security_group_ingress_rule" "allow_ec2_connect" {
  security_group_id = aws_security_group.ssh.id
  cidr_ipv4         = "13.233.177.0/29"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_security_group" "gateway" {
  name   = "gateway-http"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.gateway.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  ip_protocol       = "tcp"
  to_port           = 8000
}

# --- Instances ---

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "caller" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.ssh.id,
    aws_security_group.gateway.id
  ]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile(
    "${path.module}/../scripts/deploy-caller.sh",
    {
      inference_ip = "10.0.2.10"
      repo_url     = var.repo_url
    }
  )

  tags = { Name = "caller-gateway" }
}

resource "aws_instance" "inference" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private.id
  private_ip    = "10.0.2.10"

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.ssh.id
  ]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile(
    "${path.module}/../scripts/deploy-inference.sh",
    {
      caller_ip = aws_instance.caller.private_ip
      repo_url  = var.repo_url
    }
  )

  tags = { Name = "inference-worker" }
}

output "gateway_public_ip" {
  value = aws_instance.caller.public_ip
}
