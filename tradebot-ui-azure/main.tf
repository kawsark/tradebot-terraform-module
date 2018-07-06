#Define providers
provider "vault" {
  # Vault provider configured via environment variables
}

provider "azurerm" {
  # Azurerm provider configured via environment variables
}

# Configure the Cloudflare provider
provider "cloudflare" {
  email = "${data.vault_generic_secret.tradebot_common_secret.data["cloudflare_email"]}"
  token = "${data.vault_generic_secret.tradebot_common_secret.data["cloudflare_api_key"]}"
}

#### Provisions Tradebot WebUI into Azure ####

# Create the resource group
resource "azurerm_resource_group" "tradebotresourcegroup" {
  name     = "${format("tradebotRG-%s", var.environment)}"
  location = "${var.location}"

  tags {
    environment = "${var.environment}"
    application = "${var.application}"
  }
}

# Create a VNET
resource "azurerm_virtual_network" "tradebotvnet" {
  name                = "${format("tradebotvnet-%s", var.environment)}"
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
  name                 = "${format("tradebotsubnet1-%s", var.environment)}"
  resource_group_name  = "${azurerm_resource_group.tradebotresourcegroup.name}"
  virtual_network_name = "${azurerm_virtual_network.tradebotvnet.name}"
  address_prefix       = "${var.subnet_address_prefix}"
}

#Create a network security group
resource "azurerm_network_security_group" "tradebotpublicipnsg" {
  name                = "${format("tradebotpublicipnsg-%s", var.environment)}"
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
  name                         = "${format("tradebotlbip-%s", var.environment)}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.tradebotresourcegroup.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.domain_name_label}"
 }

resource "azurerm_lb" "tradebotlb" {
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  name                = "${format("tradebotlb-%s", var.environment)}"
  location            = "${var.location}"

  frontend_ip_configuration {
      name                 = "LoadBalancerFrontEnd"
      public_ip_address_id = "${azurerm_public_ip.tradebotlbip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${azurerm_resource_group.tradebotresourcegroup.name}"
  loadbalancer_id     = "${azurerm_lb.tradebotlb.id}"
  name                = "${format("BackendPool1-%s", var.environment)}"
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
  name                = "${format("tradebotwebuivmss-%s", var.environment)}"
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
