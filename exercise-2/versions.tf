terraform {
  required_version = ">= 1.13.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    snowflake = {
      source = "Snowflakedb/snowflake"
    }

    tls = {
      source = "hashicorp/tls"
    }
  }
}