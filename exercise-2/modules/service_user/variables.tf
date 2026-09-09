variable "service_name" {
  description = "Name of the Snowflake service user"
  type        = string
}

variable "role_name" {
  description = "Snowflake role granted to the service user"
  type        = string
}

variable "default_warehouse" {
  description = "Default warehouse for the Snowflake service user"
  type        = string
  default     = null
}
