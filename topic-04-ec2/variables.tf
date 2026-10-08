variable "aws_profile" {
  description = "Профіль AWS CLI (з гайду: admin бере роль cli-admin-role)"
  type        = string
  default     = "admin"
}

variable "region" {
  description = "Регіон AWS (той самий, що й у темі 3)"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_name" {
  description = "Значення змінної name з теми 3 — за ним шукаємо VPC, підмережі та SG"
  type        = string
  default     = "goit-vpc"
}

variable "name" {
  description = "Префікс імен ресурсів цієї теми"
  type        = string
  default     = "goit-web"
}

variable "instance_type" {
  description = "Тип EC2-інстансу"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Мінімальна кількість інстансів в Auto Scaling групі"
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Бажана кількість інстансів на старті"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Максимальна кількість інстансів"
  type        = number
  default     = 4
}

variable "cpu_target" {
  description = "Цільове середнє завантаження CPU групи, %"
  type        = number
  default     = 50
}
