# tradebot-terraform-module
Terraform modules to provision Tradebot Web UI in Azure, Tradebot DNS in CloudFlare, and Tradebot Server in AWS.
- Tradebot Server module path: [tradebot-server-aws](tradebot-server-aws). Note: AWS servers are provisioned in public subnet in dev/ branch.
- Tradebot UI and DNS module path: [tradebot-ui-azure](tradebot-ui-azure)

## Prerequisites
- Vault server with SSH public key and Windows server password set at the path of following terraform variable value: `vault_secret_path`.
```
admin_password
id_rsa_pub
```
- Vault server with the the following provider credentials set at the path of following terraform variable value: `vault_common_secret_path`.
```
aws_access_key
aws_secret_key
azurerm_client_id
azurerm_client_secret
azurerm_subscription_id
azurerm_tenant_id
cloudflare_api_key
cloudflare_email
```
- Environment variables for Vault server: `VAULT_ADDR`, `VAULT_TOKEN` and `VAULT_CACERT` (in case SSL is enabled).
