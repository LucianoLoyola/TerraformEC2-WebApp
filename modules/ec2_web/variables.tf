variable "region" {
    type = string
    default= "us-east-1"
}

#EC2
variable "instance_type"    {
    type = string
    default= "t3.micro"
}

variable "user_data_content" {
  type        = string
  default     = ""
  description = "user_data para inicialización de la instancia"
}

#Relacion entre recursos
variable "name_prefix" {
  type        = string
  default     = "web"
  description = "Prefijo para nombrar los recursos (EC2, ASG)"
}

#VPC
variable "associate_public_ip" {
  type        = bool
  default     = true
  description = "Auto assign IP pública a la instancia"
}

