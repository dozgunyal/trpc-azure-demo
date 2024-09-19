# Configure the Microsoft Azure Provider
provider "azurerm" {
  resource_provider_registrations = "none" # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}

  client_id                   = var.azure_client_id
  client_certificate_path     = var.azure_client_certificate_path
  client_certificate_password = var.azure_client_certificate_password
  tenant_id                   = var.azure_tenant_id
  subscription_id             = var.azure_subscription_id
}

resource "azurerm_resource_group" "tanso_demo" {
  name     = "tanso-demo-resources"
  location = "West Europe"
}


resource "azurerm_virtual_network" "tanso_demo" {
  name                = "tanso-demo-vn"
  location            = azurerm_resource_group.tanso_demo.location
  resource_group_name = azurerm_resource_group.tanso_demo.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "tanso_demo" {
  name                 = "tanso-demo-sn"
  resource_group_name  = azurerm_resource_group.tanso_demo.name
  virtual_network_name = azurerm_virtual_network.tanso_demo.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "tanso_demo_app" {
  name                 = "tanso_demo_app"
  resource_group_name  = azurerm_resource_group.tanso_demo.name
  virtual_network_name = azurerm_virtual_network.tanso_demo.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_private_dns_zone" "tanso_demo" {
  name                = "tanso-demo.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.tanso_demo.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "tanso_demo" {
  name                  = "tanso-demo.com"
  private_dns_zone_name = azurerm_private_dns_zone.tanso_demo.name
  virtual_network_id    = azurerm_virtual_network.tanso_demo.id
  resource_group_name   = azurerm_resource_group.tanso_demo.name
  depends_on            = [azurerm_subnet.tanso_demo]
}

resource "azurerm_postgresql_flexible_server" "tanso_demo" {
  name                          = "tanso-demo-psqlflexibleserver"
  resource_group_name           = azurerm_resource_group.tanso_demo.name
  location                      = azurerm_resource_group.tanso_demo.location
  version                       = "12"
  delegated_subnet_id           = azurerm_subnet.tanso_demo.id
  private_dns_zone_id           = azurerm_private_dns_zone.tanso_demo.id
  public_network_access_enabled = false
  administrator_login           = "psqladmin"
  administrator_password        = var.azure_postgresql_admin_password
  zone                          = "1"

  storage_mb   = 32768
  storage_tier = "P30"

  sku_name   = "GP_Standard_D4s_v3"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.tanso_demo]
}

resource "azurerm_postgresql_flexible_server_database" "tanso_demo" {
  name      = "tanso-demo-db"
  server_id = azurerm_postgresql_flexible_server.tanso_demo.id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_service_plan" "tanso_demo" {
  name                = "webapp-plan-tanso-demo"
  location            = azurerm_resource_group.tanso_demo.location
  resource_group_name = azurerm_resource_group.tanso_demo.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "tanso_demo" {
  name                  = "webapp-tanso-demo"
  location              = azurerm_resource_group.tanso_demo.location
  resource_group_name   = azurerm_resource_group.tanso_demo.name
  service_plan_id       = azurerm_service_plan.tanso_demo.id
  https_only            = true
  site_config { 
    minimum_tls_version = "1.2"
    application_stack {
      node_version = "18-lts"
    }
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "tanso_demo" {
  app_service_id = azurerm_linux_web_app.tanso_demo.id
  subnet_id      = azurerm_subnet.tanso_demo_app.id
}

resource "azurerm_app_service_source_control" "hello_world" {
  app_id             = azurerm_linux_web_app.tanso_demo.id
  repo_url           = "https://github.com/Azure-Samples/nodejs-docs-hello-world"
  branch             = "main"
  use_manual_integration = true
  use_mercurial      = false
}

variable "azure_client_id" {
  type = string
}
variable "azure_client_certificate_path" {
  type = string
}
variable "azure_client_certificate_password" {
  type = string
}
variable "azure_tenant_id" {
  type = string
}
variable "azure_subscription_id" {
  type = string
}
variable "azure_postgresql_admin_password" {
  type = string
}