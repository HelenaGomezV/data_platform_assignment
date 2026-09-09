module "svc_airbyte" {
  source = "./modules/service_user"

  service_name = "SVC_AIRBYTE"
  role_name    = "ROLE_INGESTION"
}
