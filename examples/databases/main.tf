module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      sql = {
        address_prefixes       = ["10.18.3.0/24"]
        network_security_group = {}
        route_table = {
          bgp_route_propagation_enabled = true
        }
        delegations = {
          managedinstance = {
            name = "Microsoft.Sql/managedInstances"
            actions = [
              "Microsoft.Network/virtualNetworks/subnets/join/action",
              "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
              "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
            ]
          }
        }
      }
    }
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"


  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    secrets = {
      random_string = {
        sql = {
          length  = 24
          special = true
        }
      }
    }
  }
}

module "storage" {
  source  = "codectl/sa/azure"
  version = "~> 1.0"

  storage = {
    name                = module.naming.storage_account.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "sqlmi" {
  source  = "codectl/sqlmi/azure"
  version = "~> 1.0"

  mssql_managed_instance = {
    name                = module.naming.mssql_server.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    sku_name           = "GP_Gen5"
    storage_size_in_gb = 32
    vcores             = 4

    subnet_id                    = module.network.subnets.sql.id
    administrator_login          = "adminLogin"
    administrator_login_password = module.kv.secrets.sql.value

    databases = {
      production_db = {
        name                      = "production_database"
        short_term_retention_days = 14
        long_term_retention_policy = {
          weekly_retention  = "P4W"
          monthly_retention = "P12M"
          yearly_retention  = "P5Y"
          week_of_year      = 1
        }
      },
      development_db = {
        name                      = "development_database"
        short_term_retention_days = 7
      }
    }
  }
}
