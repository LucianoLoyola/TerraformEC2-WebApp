provider "aws" {
  region = var.region
}

# VPC Default
data "aws_vpc" "default" {
  default = true
}

# Subnets de la VPC Default
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  preferred_az_suffixes = ["a", "b", "c"]

  preferred_az = [for az in data.aws_availability_zones.available.names :
    az if can(regex("${var.region}[abc]", az))
  ][0]
}

data "aws_subnet" "preferred" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [local.preferred_az]
  }
}

# Latest Oracle Linux 9 AMI
data "aws_ami" "oracle_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["OL9*-x86_64-HVM-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["131827586825"]
}

# Security Group para tráfico HTTP, HTTPS y SSH
resource "aws_security_group" "web_sg" {
  name        = "${var.name_prefix}-sg"
  description = "Allow HTTP and HTTPS inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS for Pritunl"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear clave SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content     = tls_private_key.ssh_key.private_key_pem
  filename    = "${path.module}/my-ec2-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami                         = "ami-00b5c37e7194270f7"
  instance_type               = var.instance_type
  availability_zone           = local.preferred_az
  subnet_id                   = data.aws_subnet.preferred.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = var.associate_public_ip
  key_name                    = aws_key_pair.generated_key.key_name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${var.name_prefix}-instance"
  }
}
