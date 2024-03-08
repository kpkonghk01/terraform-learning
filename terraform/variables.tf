variable "shared_config_files" {
  type = list(any)
}

variable "shared_credentials_files" {
  type = list(any)
}

variable "profile" {
  type = string
}

variable "postgresql_username" {
  type = string
}

variable "postgresql_password" {
  type = string
}
