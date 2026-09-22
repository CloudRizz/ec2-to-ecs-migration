output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "public_subnets" {
  description = "Public subnet resources keyed by subnet name"
  value       = aws_subnet.public
}

output "private_subnets" {
  description = "Private subnet resources keyed by subnet name"
  value       = aws_subnet.private
}

# Exposes the VPC CIDR for least-privilege security group rules.
output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}