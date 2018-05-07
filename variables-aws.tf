variable "tradebot-in-queue" {
  default = "tradebot-in-prod-queue-YP0MHaB"
}

variable "asg_size_map"{
  type = "map"
  default = {
    min = 1,
    desired = 2,
    max = 2
  }
}

variable "instance_size"{
  default = "t2.micro"
}

variable "AMI" {
  default = "ami-76a21d09"
}

variable "App" {
  default = "Tradebot-server"
}

variable "Env" {
  default = "Production"
}

variable "az_1" {
  default = "us-east-1a"
}

variable "az_2" {
  default = "us-east-1b"
}

variable "vpc_cidr_block" {
  default = "192.168.0.0/16"
}

variable "public_subnet_1_block" {
  default = "192.168.0.0/21"
}

variable "public_subnet_2_block" {
  default = "192.168.8.0/21"
}

variable "private_subnet_1_block" {
  default = "192.168.16.0/21"
}

variable "private_subnet_2_block" {
  default = "192.168.24.0/21"
}

