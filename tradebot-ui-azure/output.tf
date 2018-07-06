#WebUI outputs
output "lb_fqdn" {
  value = "${data.azurerm_public_ip.tradebotlbip.fqdn}"
}

output "ui_fqdn" {
  value = "${format("http://%s/",cloudflare_record.tradebotdns.hostname)}"
}

output "server_fqdn" {
  value = "${format("https://%s/",cloudflare_record.tradebotdns_server.hostname)}"
}
