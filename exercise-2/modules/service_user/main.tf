resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_secretsmanager_secret" "this" {
  name                    = "snowflake/prod/user/svc/key/${var.service_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({
    public_key  = tls_private_key.this.public_key_pem
    private_key = tls_private_key.this.private_key_pem_pkcs8
  })
}

resource "snowflake_service_user" "this" {
  name         = var.service_name
  default_role = var.role_name
}

resource "snowflake_grant_account_role" "this" {
  role_name = var.role_name
  user_name = snowflake_service_user.this.name
}