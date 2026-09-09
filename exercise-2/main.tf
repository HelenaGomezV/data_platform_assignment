module "svc_airbyte" {
  source = "./modules/service_user"

  service_name      = "SVC_AIRBYTE"
  role_name         = "ROLE_INGESTION"
  default_warehouse = snowflake_warehouse.ingestion.name
}

resource "snowflake_warehouse" "ingestion" {
  name                = "WH_INGESTION"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
}
resource "snowflake_grant_privileges_to_account_role" "ingestion_warehouse_usage" {
  privileges        = ["USAGE"]
  account_role_name = module.svc_airbyte.role_name

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.ingestion.name
  }
}
