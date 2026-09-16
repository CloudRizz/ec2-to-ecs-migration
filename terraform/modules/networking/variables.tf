variable "name_prefix" {
  description = "Prefix used for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet definitions"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "Private subnet definitions"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}
