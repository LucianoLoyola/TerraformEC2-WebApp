provider "aws" {
  region = var.region
}
#Uso la VPC Default
data "aws_vpc" "default" {
  default = true
}
#Subnets de la default VPC
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
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
}

#EC2
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet_ids.default.ids[0]#Primer subnet de la lista
  vpc_security_group_ids      = [aws_security_group.web_sg.id]#SG Custom
  associate_public_ip_address = var.associate_public_ip#Auto asignar IP pública
  #Script para instanar NGINX
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