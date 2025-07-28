variable "public_subnet_ids" {
  description = "List of public subnet IDs for the instances."
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "The security group ID for the EC2 instances."
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the target group to attach instances to."
  type        = string
}