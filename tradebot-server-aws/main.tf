#Define providers
provider "vault" {
  # Vault provider configured via environment variables
}

provider "aws" {
 # AWS provider configured in Vault
 access_key = "${data.vault_generic_secret.tradebot_common_secret.data["aws_access_key"]}"
 secret_key = "${data.vault_generic_secret.tradebot_common_secret.data["aws_secret_key"]}"
 region = "${var.aws_region}"
}

### Defines vault secret paths
data "vault_generic_secret" "tradebot_secret" {
  path = "${var.vault_secret_path}"
}

data "vault_generic_secret" "tradebot_common_secret" {
  path = "${var.vault_common_secret_path}"
}

#### Provisions Tradebot server in AWS #####

# Internet VPC
resource "aws_vpc" "tradebot_vpc" {
  cidr_block           = "${var.vpc_cidr_block}"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags {
    Name = "tradebot_vpc"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

# Subnets
resource "aws_subnet" "tradebot-public-1" {
  vpc_id                  = "${aws_vpc.tradebot_vpc.id}"
  cidr_block              = "${var.public_subnet_1_block}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${format("%sa",var.aws_region)}"

  tags {
    Name = "tradebot-public-1"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

resource "aws_subnet" "tradebot-public-2" {
  vpc_id                  = "${aws_vpc.tradebot_vpc.id}"
  cidr_block              = "${var.public_subnet_2_block}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${format("%sb",var.aws_region)}"

  tags {
    Name = "tradebot-public-2"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

resource "aws_subnet" "tradebot-private-1" {
  vpc_id                  = "${aws_vpc.tradebot_vpc.id}"
  cidr_block              = "${var.private_subnet_1_block}"
  map_public_ip_on_launch = "false"
  availability_zone       = "${format("%sa",var.aws_region)}"

  tags {
    Name = "tradebot-private-1"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

resource "aws_subnet" "tradebot-private-2" {
  vpc_id                  = "${aws_vpc.tradebot_vpc.id}"
  cidr_block              = "${var.private_subnet_2_block}"
  map_public_ip_on_launch = "false"
  availability_zone       = "${format("%sb",var.aws_region)}"

  tags {
    Name = "tradebot-private-2"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

# Internet GW
resource "aws_internet_gateway" "tradebot-gw" {
  vpc_id = "${aws_vpc.tradebot_vpc.id}"

  tags {
    Name = "tradebot-gw"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

#Public route table with IGW
resource "aws_route_table" "tradebot-public" {
  vpc_id = "${aws_vpc.tradebot_vpc.id}"

tags {
    Name = "tradebot-public-1"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

#Public route
resource "aws_route" "tradebot-public-route" {
  route_table_id = "${aws_route_table.tradebot-public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.tradebot-gw.id}"
}

# route associations public
resource "aws_route_table_association" "tradebot-public-1-a" {
  subnet_id      = "${aws_subnet.tradebot-public-1.id}"
  route_table_id = "${aws_route_table.tradebot-public.id}"
}

resource "aws_route_table_association" "tradebot-public-2-a" {
  subnet_id      = "${aws_subnet.tradebot-public-2.id}"
  route_table_id = "${aws_route_table.tradebot-public.id}"
}

resource "aws_security_group" "tradebot-sg" {
  vpc_id      = "${aws_vpc.tradebot_vpc.id}"
  description = "security group that allows ssh and all egress traffic"

  tags {
    Name = "tradebot-sg"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

resource "aws_security_group_rule" "egress_allow_all" {
  type            = "egress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  cidr_blocks     = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.tradebot-sg.id}"
}

resource "aws_security_group_rule" "ingress_allow_ssh" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.tradebot-sg.id}"
}


# nat gw
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.tradebot-public-1.id}"
  depends_on    = ["aws_internet_gateway.tradebot-gw"]
}

#Private route table with NAT
resource "aws_route_table" "tradebot-private" {
  vpc_id = "${aws_vpc.tradebot_vpc.id}"

  tags {
    Name = "tradebot-private-1"
    App  = "${var.App}"
    Env  = "${var.environment}"
  }
}

#Private route
resource "aws_route" "tradebot-private-route" {
  route_table_id = "${aws_route_table.tradebot-private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.nat-gw.id}"
}


# route associations private
resource "aws_route_table_association" "tradebot-private-1-a" {
  subnet_id      = "${aws_subnet.tradebot-private-1.id}"
  route_table_id = "${aws_route_table.tradebot-private.id}"
}

resource "aws_route_table_association" "tradebot-private-1-b" {
  subnet_id      = "${aws_subnet.tradebot-private-2.id}"
  route_table_id = "${aws_route_table.tradebot-private.id}"
}


#IAM Roles:
resource "aws_iam_role" "ec2-assume-role" {
  path = "/system/"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

#Assume role policy
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
          type = "Service"
	  identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#Instance profile
resource "aws_iam_instance_profile" "ec2-assume-role-instanceprofile" {
  role = "${aws_iam_role.ec2-assume-role.name}"
}

#IAM effective policy
resource "aws_iam_role_policy" "tradebot-custom-access-role-policy" {
  role = "${aws_iam_role.ec2-assume-role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "0EC2",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Sid": "1S3",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::tradebot-in-122517",
                "arn:aws:s3:::tradebot-out-122517",
                "arn:aws:s3:::tradebot-in-122517/*",
                "arn:aws:s3:::tradebot-out-122517/*"
            ]
        },
        {
            "Sid": "2SQS",
            "Effect": "Allow",
            "Action": "sqs:*",
            "Resource": "*"
        },
        {
            "Sid": "3KMS",
            "Effect": "Allow",
            "Action": "kms:*",
            "Resource": "${lookup(var.sqs_kms, var.aws_region)}"
        }
    ]
}
EOF
}

#SQS queue
resource "aws_sqs_queue" "tradebot_queue" {
  name                      = "${var.tradebot-in-queue}"
  delay_seconds             = 0
  max_message_size          = 1024
  message_retention_seconds = 3600
  receive_wait_time_seconds = 20
  kms_master_key_id         = "${lookup(var.sqs_kms_key_id, var.aws_region)}"
  kms_data_key_reuse_period_seconds = 300

  # tags:
  tags {
    App  = "${var.App}"
    Env  = "${var.environment}"
  }

}

#User data
data "template_file" "user_data" {
  template = "${file(var.user_data_file_path)}"
}

#Launch configuration
resource "aws_launch_configuration" "tradebotserver_lc" {
  name_prefix   = "tradebotserver-"
  image_id      = "${lookup(var.AMI, var.aws_region)}"
  instance_type = "${var.instance_size}"

  # public SSH key
  key_name = "${aws_key_pair.tradebotkeypair.key_name}"

  # role
  iam_instance_profile = "${aws_iam_instance_profile.ec2-assume-role-instanceprofile.name}"

  # security group
  security_groups = ["${aws_security_group.tradebot-sg.id}"]

  lifecycle {
      create_before_destroy = true
  }

  # Tells Terraform that this EC2 instance must be created only after the
  # SQS queue has been created.
  depends_on = ["aws_sqs_queue.tradebot_queue"]

  user_data = "${data.template_file.user_data.rendered}"
}

#Auto Scaling group
resource "aws_autoscaling_group" "tradebotserver_asg" {
  launch_configuration = "${aws_launch_configuration.tradebotserver_lc.name}"
  min_size	       = "${var.asg_size_map["min"]}"
  max_size	       = "${var.asg_size_map["max"]}"
  desired_capacity     = "${var.asg_size_map["desired"]}"
  health_check_type    = "EC2"

  vpc_zone_identifier       = ["${aws_subnet.tradebot-public-1.id}", "${aws_subnet.tradebot-public-2.id}"]

 tags = [
    {
      key                 = "App"
      value               = "${var.App}"
      propagate_at_launch = true
    },
    {
      key                 = "Env"
      value               = "${var.environment}"
      propagate_at_launch = true
    },
    {
      key                 = "tradebot_sqs_name"
      value               = "${var.tradebot-in-queue}"
      propagate_at_launch = true
    }
  ]


  lifecycle {
      create_before_destroy = true
  }

}

resource "aws_key_pair" "tradebotkeypair" {
  key_name   = "tradebotkeypair"
  public_key = "${data.vault_generic_secret.tradebot_secret.data["id_rsa_pub"]}"
}
