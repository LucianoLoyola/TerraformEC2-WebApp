provider "aws" {
  region = var.region
}
#Uso la VPC Default
data "aws_vpc" "default" {
  default = true
}
#Subnets de la default VPC
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


#Latest Oracle Linux 9 AMI
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

#Security Group para permitir tráfico en puerto 80 (HTTP)
resource "aws_security_group" "web_sg" {
  name = "${var.name_prefix}-sg"
  description = "Allow HTTP inbound"
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

# key_pair.tf

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/my-ec2-key.pem"
  file_permission = "0400"
}


#EC2
resource "aws_instance" "web_server" {
    ami                         = data.aws_ami.oracle_linux.id
    instance_type               = var.instance_type
    availability_zone           = local.preferred_az
    subnet_id                   = data.aws_subnet.preferred.id
    vpc_security_group_ids      = [aws_security_group.web_sg.id]
    associate_public_ip_address = var.associate_public_ip
    key_name                    = aws_key_pair.generated_key.key_name
    user_data = <<-EOF
        #!/bin/bash
        set -e

        tee /etc/yum.repos.d/mongodb-org.repo <<EOM
      [mongodb-org]
      name=MongoDB Repository
      baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/x86_64/
      gpgcheck=1
      enabled=1
      gpgkey=https://pgp.mongodb.com/server-8.0.asc
      EOM

        tee /etc/yum.repos.d/pritunl.repo <<EOM
      [pritunl]
      name=Pritunl Repository
      baseurl=https://repo.pritunl.com/stable/yum/oraclelinux/9/
      gpgcheck=1
      enabled=1
      gpgkey=https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc
      EOM

        dnf -y update
        dnf -y remove iptables-services
        systemctl stop firewalld.service || true
        systemctl disable firewalld.service || true

        dnf -y install pritunl pritunl-openvpn wireguard-tools mongodb-org
        systemctl enable mongod pritunl
        systemctl start mongod pritunl
      EOF

  tags = {
    Name = "${var.name_prefix}-instance"
  }

}
