variable "environment" {
	 default = "Production"
}

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
  type = "map"
  default = {
    us-east-1 = "ami-1164ea6e",
    us-east-2 = "ami-c3ecd1a6"
  }
}

variable "App" {
  default = "Tradebot-server"
}

variable "aws_region" {
  default = "us-east-1"
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
  type = "map"
  default = {
    us-east-1 = "arn:aws:kms:us-east-1:387808993772:alias/aws/sqs",
    us-east-2 = "arn:aws:kms:us-east-2:387808993772:alias/aws/sqs"
  }
}

variable "sqs_kms_key_id" {
  type = "map"
  default = {
    us-east-1 = "b4f8d75c-fcf5-4dda-8de3-2302c5b13e7b",
    us-east-2 = "5f1e9ca1-d7af-49ad-b377-de7313c10221"
  }
}

variable "vault_secret_path" {
	 default = "secret/tradebot/prod"
}

variable "vault_common_secret_path" {
	 default = "secret/tradebot/common"
}
