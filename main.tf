#Define providers
provider "vault" {
  # Vault provider configured via environment variables
}

provider "azurerm" {
  # Azurerm provider configured via environment variables
}

provider "aws" {
 # AWS provider configured via default shared credentials file
 region = "${var.aws_region}" 
}

# Configure the Cloudflare provider
provider "cloudflare" {
  email = "${data.vault_generic_secret.tradebot_common_secret.data["cloudflare_email"]}"
  token = "${data.vault_generic_secret.tradebot_common_secret.data["cloudflare_api_key"]}"
}

#### Provisions Tradebot WebUI into Azure ####

# Create the resource group
resource "azurerm_resource_group" "tradebotresourcegroup" {
  name     = "tradebotresourcegroup"
  location = "${var.location}"

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
  }
}

# Create a VNET
resource "azurerm_virtual_network" "tradebotvnet" {
  name                = "tradebotvnet"
  address_space       = ["${var.vnet_address_space}"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
  }
}

# Create a Subnet
resource "azurerm_subnet" "tradebotsubnet1" {
  name                 = "tradebotsubnet1"
  resource_group_name  = "${azurerm_resource_group.tradebotresourcegroup.name}"
  virtual_network_name = "${azurerm_virtual_network.tradebotvnet.name}"
  address_prefix       = "${var.subnet_address_prefix}"
}

#Create a network security group
resource "azurerm_network_security_group" "tradebotpublicipnsg" {
  name                = "tradebotpublicipnsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
    description = "NSG with for tradebot Web UI application"
  }
}


#Network security rule resources
resource "azurerm_network_security_rule" "ssh-rule" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  network_security_group_name = "${azurerm_network_security_group.tradebotpublicipnsg.name}"
}

#Network security rule resources
resource "azurerm_network_security_rule" "HTTP-Tomcat" {
  name                        = "HTTP-Tomcat"
  priority                    = 2000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  network_security_group_name = "${azurerm_network_security_group.tradebotpublicipnsg.name}"
}

#Create some random text
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.tradebotresourcegroup.name}"
  }

  byte_length = 8
}

#Create a storage account
resource "azurerm_storage_account" "tradebotstorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.tradebotresourcegroup.name}"
  location                 = "${var.location}"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
  }
}


data "azurerm_public_ip" "tradebotlbip" {
  name = "${azurerm_public_ip.tradebotlbip.name}"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
}

resource "azurerm_public_ip" "tradebotlbip" {
  name                         = "tradebotlbip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.tradebotresourcegroup.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.domain_name_label}"
 }

resource "azurerm_lb" "tradebotlb" {
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  name                = "tradebotlb"
  location            = "${var.location}"

  frontend_ip_configuration {
      name                 = "LoadBalancerFrontEnd"
      public_ip_address_id = "${azurerm_public_ip.tradebotlbip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  loadbalancer_id     = "${azurerm_lb.tradebotlb.id}"
  name                = "BackendPool1"
}


resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.tradebotresourcegroup.name}"
    loadbalancer_id                = "${azurerm_lb.tradebotlb.id}"
    name                           = "LBRule"
    protocol                       = "tcp"
    frontend_port                  = 80
    backend_port                   = 8080
    frontend_ip_configuration_name = "LoadBalancerFrontEnd"
    enable_floating_ip             = false
    backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
    idle_timeout_in_minutes        = 5
    probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
    depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_lb_probe" "lb_probe" {
    resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.tradebotlb.id}"
    name                = "tcpProbe"
    protocol            = "tcp"
    port                = 8080
    interval_in_seconds = 5
    number_of_probes    = 2
}


data "vault_generic_secret" "tradebot_secret" {
  path = "${var.vault_secret_path}"
}

data "vault_generic_secret" "tradebot_common_secret" {
  path = "${var.vault_common_secret_path}"
}


#Create Virtual Machine Scale Sets
resource "azurerm_virtual_machine_scale_set" "tradebotwebuivmss" {
  name                = "tradebotwebuivmss"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "${var.azure_vm_sku}"
    tier     = "Standard"
    capacity = "${var.azure_vm_qty}"
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "tradebotwebuivm"
    admin_username       = "azureuser"
    admin_password       = "${data.vault_generic_secret.tradebot_secret.data["admin_password"]}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
       key_data = "${data.vault_generic_secret.tradebot_secret.data["id_rsa_pub"]}"
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

  ip_configuration {
    name                          = "tradebotipconfiguration"
    subnet_id                     = "${azurerm_subnet.tradebotsubnet1.id}"
    load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    #load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.lbnatpool.*.id, count.index)}"]
    
  public_ip_address_configuration {
    name                          = "publicipconfiguration"
    idle_timeout		  = 4
    domain_name_label		  = "${format("tradebotwebuivm%d", count.index)}"
  }


  }

  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.tradebotstorageaccount.primary_blob_endpoint}"
  }

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
  }
}

#### Provisions CloudFlare DNS records ####

# Add the UI record to domain
resource "cloudflare_record" "tradebotdns" {
  domain = "${var.cloudflare_domain}"
  name   = "${var.domain_name_label}"
  value  = "${data.azurerm_public_ip.tradebotlbip.fqdn}"
  type   = "CNAME"
  ttl    = 1 
  depends_on = ["azurerm_lb.tradebotlb","azurerm_virtual_machine_scale_set.tradebotwebuivmss"]
}

# Add the server record to domain
resource "cloudflare_record" "tradebotdns_server" {
  domain = "${var.cloudflare_domain}"
  name   = "${var.domain_name_label_server}"
  value  = "${var.domain_name_value_server}"
  type   = "CNAME"
  ttl    = 1
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
  availability_zone       = "${var.az_1}"

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
  availability_zone       = "${var.az_2}"

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
  availability_zone       = "${var.az_1}"

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
  availability_zone       = "${var.az_2}"

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
  name        = "tradebot-sg"
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
  name = "ec2-assume-role"
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
  name = "ec2-assume-role"
  role = "${aws_iam_role.ec2-assume-role.name}"
}

#IAM effective policy
resource "aws_iam_role_policy" "tradebot-custom-access-role-policy" {
  name = "tradebot-custom-access-role-policy"
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
            "Resource": "arn:aws:kms:us-east-1:387808993772:alias/aws/sqs"
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
  kms_master_key_id         = "b4f8d75c-fcf5-4dda-8de3-2302c5b13e7b"
  kms_data_key_reuse_period_seconds = 300

  # tags:
  tags {
    App  = "${var.App}"
    Env  = "${var.environment}"
  }

}

#Launch configuration
resource "aws_launch_configuration" "tradebotserver_lc" {
  name_prefix   = "tradebotserver-"
  image_id      = "${var.AMI}"
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

}

#Auto Scaling group
resource "aws_autoscaling_group" "tradebotserver_asg" {
  name                 = "tradebotserver_asg"
  launch_configuration = "${aws_launch_configuration.tradebotserver_lc.name}"
  min_size	       = "${var.asg_size_map["min"]}"
  max_size	       = "${var.asg_size_map["max"]}"
  desired_capacity     = "${var.asg_size_map["desired"]}"
  health_check_type    = "EC2"

  vpc_zone_identifier       = ["${aws_subnet.tradebot-private-1.id}", "${aws_subnet.tradebot-private-2.id}"]

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
