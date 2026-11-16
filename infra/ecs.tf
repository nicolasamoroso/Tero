module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  name = "${var.project}-${var.environment}"
}

data "aws_ecr_repository" "service" {
  for_each = local.services

  name = "${var.project}/${each.value.repository}"
}

locals {
  db_endpoint = "${module.database.endpoint}:${module.database.port}"
  db_password = "${module.database.master_user_secret_arn}:password::"
  db_user     = module.database.username

  services = {
    ui = {
      repository = "ui"
      environment = {
        RETAIL_UI_ENDPOINTS_CATALOG  = "http://catalog:8080"
        RETAIL_UI_ENDPOINTS_CARTS    = "http://carts:8080"
        RETAIL_UI_ENDPOINTS_CHECKOUT = "http://checkout:8080"
        RETAIL_UI_ENDPOINTS_ORDERS   = "http://orders:8080"
      }
      secrets = {}
    }
    catalog = {
      repository = "catalog"
      environment = {
        GIN_MODE                            = "release"
        RETAIL_CATALOG_PERSISTENCE_PROVIDER = "postgres"
        RETAIL_CATALOG_PERSISTENCE_ENDPOINT = local.db_endpoint
        RETAIL_CATALOG_PERSISTENCE_DB_NAME  = "catalogdb"
        RETAIL_CATALOG_PERSISTENCE_USER     = local.db_user
      }
      secrets = {
        RETAIL_CATALOG_PERSISTENCE_PASSWORD = local.db_password
      }
    }
    carts = {
      repository = "cart"
      environment = {
        CART_PERSISTENCE_PROVIDER = "postgres"
        CART_POSTGRES_HOST        = module.database.endpoint
        CART_POSTGRES_PORT        = tostring(module.database.port)
        CART_POSTGRES_DB          = "cartdb"
        CART_POSTGRES_USER        = local.db_user
        PORT                      = "8080"
      }
      secrets = {
        CART_POSTGRES_PASSWORD = local.db_password
      }
    }
    orders = {
      repository = "orders"
      environment = {
        GIN_MODE                           = "release"
        RETAIL_ORDERS_PERSISTENCE_ENDPOINT = local.db_endpoint
        RETAIL_ORDERS_PERSISTENCE_NAME     = module.database.db_name
        RETAIL_ORDERS_PERSISTENCE_USERNAME = local.db_user
      }
      secrets = {
        RETAIL_ORDERS_PERSISTENCE_PASSWORD = local.db_password
      }
    }
    checkout = {
      repository = "checkout"
      environment = {
        RETAIL_CHECKOUT_PERSISTENCE_PROVIDER  = "redis"
        RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL = module.cache.url
        RETAIL_CHECKOUT_ENDPOINTS_ORDERS      = "http://orders:8080"
      }
      secrets = {}
    }
    admin = {
      repository = "admin"
      environment = {
        DB_HOST        = module.database.endpoint
        DB_PORT        = tostring(module.database.port)
        DB_USER        = local.db_user
        ADMIN_USERNAME = var.admin_username
      }
      secrets = {
        DB_PASSWORD      = local.db_password
        ADMIN_PASSWORD   = aws_secretsmanager_secret.admin_password.arn
        ADMIN_JWT_SECRET = aws_secretsmanager_secret.admin_jwt_secret.arn
      }
    }
  }
}

module "service" {
  source   = "./modules/ecs-service"
  for_each = local.services

  name                          = each.key
  prefix                        = "${var.project}-${var.environment}"
  cluster_arn                   = module.ecs_cluster.cluster_arn
  service_connect_namespace_arn = module.ecs_cluster.service_connect_namespace_arn
  repository_url                = data.aws_ecr_repository.service[each.key].repository_url
  image_tag                     = var.image_tag
  role_arn                      = data.aws_iam_role.lab.arn
  subnet_ids                    = module.network.public_subnet_ids
  security_group_ids            = [module.network.services_security_group_id]
  environment                   = each.value.environment
  secrets                       = each.value.secrets
}
