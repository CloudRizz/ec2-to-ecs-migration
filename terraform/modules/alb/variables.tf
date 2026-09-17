# Naming variable
variable "name_prefix" {
  description = "Prefix used when naming ALB resources"
  type        = string
}

# VPC ID of where ALB is located
variable "vpc_id" {
  description = "ID of the VPC where the ALB resource will be created"
  type        = string
}

# Public subnet where ALB deployed
variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

# Listener port - port 80
variable "listener_port" {
  description = "Port on which the ALB listener accepts traffic"
  type        = number
  default     = 80
}

# Application port - Gunicorn listens on port 5000 inside the app container
variable "target_port" {
  description = "Port used by app container"
  type        = number
  default     = 5000
}

# Health Check Path - App exposes /health, ALB can use same endpoint to determine health. 
variable "health_check_path" {
  description = "Application endpoint use by the ALB target group health check"
  type        = string
  default     = "/health"
}

# Resource Tags
variable "tags" {
  description = "Tags to apply to ALb resources"
  type        = map(string)
  default     = {}
}

