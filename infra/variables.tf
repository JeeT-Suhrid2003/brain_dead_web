variable "aws_region" {
  description = "AWS region in which to create the resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short lowercase name used to tag and name project resources."
  type        = string
  default     = "records-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project_name))
    error_message = "project_name must be 2-20 lowercase letters, numbers, or hyphens, starting with a letter."
  }
}

variable "db_name" {
  description = "Name of the PostgreSQL database."
  type        = string
  default     = "records"
}

variable "db_user" {
  description = "Master username for the PostgreSQL database."
  type        = string
  default     = "records_admin"
}

variable "db_password" {
  description = "Strong PostgreSQL master password; Terraform state contains this value."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.db_password) >= 16 &&
      can(regex("^[!-~]+$", var.db_password)) &&
      !strcontains(var.db_password, "/") &&
      !strcontains(var.db_password, "@") &&
      !strcontains(var.db_password, "\"") &&
      !strcontains(var.db_password, "'")
    )
    error_message = "db_password must be at least 16 printable ASCII characters and must not contain slash, at sign, single quote, or double quote."
  }
}

variable "allowed_app_cidr" {
  description = "Optional trusted client CIDR allowed to call the API on port 5000; empty disables inbound API access."
  type        = string
  default     = ""

  validation {
    condition     = var.allowed_app_cidr == "" || can(cidrhost(var.allowed_app_cidr, 0))
    error_message = "allowed_app_cidr must be empty or a valid CIDR block."
  }
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the API host."
  type        = string
  default     = "t3.nano"

  validation {
    condition     = contains(["t3.nano", "t4g.nano"], var.ec2_instance_type)
    error_message = "ec2_instance_type must be t3.nano or t4g.nano."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.micro", "db.t4g.micro"], var.db_instance_class)
    error_message = "db_instance_class must be db.t3.micro or db.t4g.micro."
  }
}
