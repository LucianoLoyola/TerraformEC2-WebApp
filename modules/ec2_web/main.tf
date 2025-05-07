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


#Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["137112412989"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

#EC2
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  availability_zone           = local.preferred_az
  subnet_id                   = data.aws_subnet.preferred.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = var.associate_public_ip
  user_data = var.user_data_content != "" ? var.user_data_content : <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras enable nginx1
              sudo yum install -y nginx
              sudo systemctl enable nginx
              sudo systemctl start nginx
              echo "<h1>Hola desde Terraform con NGINX</h1>" > /usr/share/nginx/html/index.html
              EOF

  tags = {
    Name = "${var.name_prefix}-instance"
  }

}

output "public_ip" {
  value = aws_instance.web_server.public_ip
}