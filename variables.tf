variable "db_password" {
  description = "Password del usuario de aplicacion FreshBox"
  type        = string
  sensitive   = true
}

variable "replication_password" {
  description = "Password del usuario de replicacion MariaDB"
  type        = string
  sensitive   = true
}
