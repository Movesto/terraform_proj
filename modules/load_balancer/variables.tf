variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB."
  type        = lst(string)
}

variable "alb_sg_id" {
  description = "The security group ID for the ALB."
  type        = string
}
