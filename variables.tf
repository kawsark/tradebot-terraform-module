variable "cloudflare_domain" {
	 default = "therealk.com"
}

variable "azure_vm_sku" {
	 default = "Standard_DS1_v2"
}

variable "azure_vm_qty" {
	 default = 2
}

variable "location" {
	 default = "eastus"
}

variable "environment" {
	 default = "Production"
}

variable "application" {
	 default = "Tradebot"
}

variable "vnet_address_space" {
	 default =   "10.0.0.0/16"
}

variable "subnet_address_prefix" {
	 default = "10.0.2.0/24"
}

variable "domain_name_label" {
	 default = "tradebotui"
}

variable "domain_name_label_server" {
	 default = "tradebot"
}

variable "domain_name_value_server" {
	 default = "d1qx4ml8m41w1g.cloudfront.net"
}

variable "vault_secret_path" {
	 default = "secret/tradebot/prod"
}

variable "vault_common_secret_path" {
	 default = "secret/tradebot/common"
}
