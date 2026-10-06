variable "aws_profile" {
  description = "Профіль AWS CLI (з гайду: admin бере роль cli-admin-role)"
  type        = string
  default     = "admin"
}

variable "region" {
  description = "Регіон AWS"
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "Префікс для тегу Name усіх ресурсів"
  type        = string
  default     = "goit-vpc"
}

variable "vpc_cidr" {
  description = "CIDR-діапазон VPC (після створення змінити не можна)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR публічних підмереж, по одній на AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR приватних підмереж, по одній на AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Створити NAT Gateway для приватних підмереж (платно: ~$0.05/год + EIP)"
  type        = bool
  default     = false
}

variable "my_ip_cidr" {
  description = "Ваш публічний IP у форматі x.x.x.x/32 — лише з нього дозволено SSH"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "my_ip_cidr має бути CIDR, наприклад 203.0.113.10/32."
  }
}
