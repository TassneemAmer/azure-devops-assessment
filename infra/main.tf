locals {
  name_base = "${var.project_name}-${var.environment}"
  tags = merge(var.tags, {
    environment = var.environment
    project     = var.project_name
  })
}

resource "random_string" "suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_base}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.42.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.42.0.0/27"]

  delegation {
    name = "container-apps"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "postgresql" {
  name                 = "snet-postgresql"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.42.1.0/28"]
  service_endpoint {
    service = "Microsoft.Storage"
  }

  delegation {
    name = "postgresql-flexible-server"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "${local.name_base}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                 = "dnslink-${local.name_base}"
  private_dns_zone_id  = azurerm_private_dns_zone.postgresql.id
  virtual_network_id   = azurerm_virtual_network.main.id
  registration_enabled = false
  tags                 = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_base}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_base}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs_destination           = "log-analytics"
  tags                       = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${local.name_base}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  zone                          = "3"
  delegated_subnet_id           = azurerm_subnet.postgresql.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false
  administrator_login           = var.db_admin_login
  administrator_password        = var.db_admin_password
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  tags                          = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "assessmentdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_container_registry" "main" {
  name                          = "${replace(var.project_name, "-", "")}${replace(var.environment, "-", "")}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_container_app" "api" {
  name                         = "app-${local.name_base}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type = "SystemAssigned"
  }

  secret {
    name  = "postgres-app-password"
    value = var.db_app_password
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "system"
  }

  ingress {
    external_enabled           = true
    target_port                = 3000
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = "3000"
      }

      env {
        name  = "PGHOST"
        value = azurerm_postgresql_flexible_server.main.fqdn
      }

      env {
        name  = "PGPORT"
        value = "5432"
      }

      env {
        name  = "PGDATABASE"
        value = azurerm_postgresql_flexible_server_database.app.name
      }

      env {
        name  = "PGUSER"
        value = "assessmentapp"
      }

      env {
        name        = "PGPASSWORD"
        secret_name = "postgres-app-password"
      }
    }
  }

  # GitHub Actions owns app image updates; Terraform manages the port and settings.
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}

resource "azurerm_container_app_job" "postgres_role_bootstrap" {
  name                         = "job-${local.name_base}-db-bootstrap"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  replica_timeout_in_seconds   = 300
  replica_retry_limit          = 1
  tags                         = local.tags

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  secret {
    name  = "postgres-admin-password"
    value = var.db_admin_password
  }

  secret {
    name  = "postgres-app-password"
    value = var.db_app_password
  }

  template {
    container {
      name    = "postgres-role-bootstrap"
      image   = "postgres:16-alpine"
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["/bin/sh", "-c"]
      args = [<<-EOT
        set -eu
        export PGPASSWORD="$POSTGRES_ADMIN_PASSWORD"
        psql --quiet --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" --dbname="$PGDATABASE" --set=ON_ERROR_STOP=1 <<'SQL'
        \getenv app_password APP_DB_PASSWORD
        \o /dev/null
        SELECT format('CREATE ROLE assessmentapp LOGIN PASSWORD %L', :'app_password')
        WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'assessmentapp')
        \gexec
        SELECT format('ALTER ROLE assessmentapp WITH LOGIN PASSWORD %L', :'app_password')
        \gexec
        \o
        GRANT CONNECT ON DATABASE assessmentdb TO assessmentapp;
        GRANT USAGE ON SCHEMA public TO assessmentapp;
        CREATE TABLE IF NOT EXISTS public.assessment_items (
          id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          name VARCHAR(120) NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        SELECT 'GRANT SELECT, INSERT ON TABLE public.assessment_items TO assessmentapp'
        WHERE to_regclass('public.assessment_items') IS NOT NULL
        \gexec
        SELECT format('GRANT USAGE, SELECT ON SEQUENCE %s TO assessmentapp', pg_get_serial_sequence('public.assessment_items', 'id'))
        WHERE pg_get_serial_sequence('public.assessment_items', 'id') IS NOT NULL
        \gexec
        SQL
        EOT
      ]

      env {
        name  = "PGHOST"
        value = azurerm_postgresql_flexible_server.main.fqdn
      }

      env {
        name  = "PGPORT"
        value = "5432"
      }

      env {
        name  = "PGDATABASE"
        value = azurerm_postgresql_flexible_server_database.app.name
      }

      env {
        name  = "PGUSER"
        value = var.db_admin_login
      }

      env {
        name        = "POSTGRES_ADMIN_PASSWORD"
        secret_name = "postgres-admin-password"
      }

      env {
        name        = "APP_DB_PASSWORD"
        secret_name = "postgres-app-password"
      }
    }
  }
}

resource "azurerm_role_assignment" "container_app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_deployer_container_app_contributor" {
  scope                = azurerm_container_app.api.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = var.github_deployer_service_principal_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_deployer_environment_reader" {
  scope                = azurerm_container_app_environment.main.id
  role_definition_name = "Reader"
  principal_id         = var.github_deployer_service_principal_object_id
  principal_type       = "ServicePrincipal"
}
