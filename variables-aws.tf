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
  default = "ami-89109df"
}

variable "App" {
  default = "Tradebot-server"
}

variable "aws_region" {
  default = "us-east-1"
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

variable "sqs_kms" {
  default = "arn:aws:kms:us-east-1:387808993772:alias/aws/sqs"
}

variable "sqs_kms_key_id" {
  default = "b4f8d75c-fcf5-4dda-8de3-2302c5b13e7b"
}
