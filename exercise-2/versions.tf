terraform {
  required_version = ">= 1.13.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.63.0"
    }

    snowflake = {
      source  = "Snowflakedb/snowflake"
      version = "2.20.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.4.0"

    }
  }
}