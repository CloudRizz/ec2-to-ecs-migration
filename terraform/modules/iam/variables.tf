# Prefix used to create consistent IAM role names.
variable "name_prefix" {
  description = "Prefix used for IAM resource names"
  type        = string
}

# Common tags applied across project resources.
variable "tags" {
  description = "Common tags applied to IAM resources"
  type        = map(string)
  default     = {}
}

