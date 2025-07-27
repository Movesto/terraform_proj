// -----------------------------------------------------------------------------
// ROOT MODULE - main.tf
// This file is the entry point. It calls all the child modules and "wires"
// them together by passing outputs from one module into the inputs of another.
// -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Call the vpc module, passing in the necessary variables.
module "vpc" {
  source = "./modules/vpc"

  aws_region     = var.aws_region
  vpc_cidr_block = var.vpc_cidr_block
  project_name   = var.project_name
}

# Call the security_groups module. It depends on the vpc module,
# so we pass the vpc_id output from the vpc module as an input here.
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id = module.vpc.vpc_id
}

# Call the load_balancer module, passing in outputs from the vpc and security_groups modules.
module "load_balancer" {
  source = "./modules/load_balancer"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

# Call the asg (Auto Scaling Group) module, passing in outputs from all other modules.
module "asg" {
  source = "/modules/asg"

  public_subnet_ids = module.vpc.public_subnet_ids
  ec2_sg_id         = module.security_groups.ec2_sg_id
  target_group_arn  = module.load_balancer.target_group_arn
}





