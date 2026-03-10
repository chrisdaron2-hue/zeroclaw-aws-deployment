##############################
# variables.tf
##############################

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "telegram_token" {
  type      = string
  sensitive = true
}

variable "whatsapp_token" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "ecs_cpu" {
  type    = string
  default = "512"
}

variable "ecs_memory" {
  type    = string
  default = "1024"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  default = ["subnet-0277fef90e3c0ff60", "subnet-0e7f924325b195483"]
}

variable "existing_sg_id" {
  type    = string
  default = ""
}
