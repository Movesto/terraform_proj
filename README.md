Terraform AWS Auto-Scaling Web Server Architecture

This project uses Terraform to deploy a highly available, resilient, and auto-scaling web server architecture on Amazon Web Services (AWS). The infrastructure is defined as code using a modular approach, making it reusable, maintainable, and easy to manage.

This project is a practical demonstration of core DevOps principles, including Infrastructure as Code (IaC), high availability, and scalability.
Architecture Overview

The configuration deploys a classic two-tier architecture consisting of the following components:

    VPC: A dedicated Virtual Private Cloud (VPC) to provide a logically isolated network environment.

    Public Subnets: Two public subnets spread across different Availability Zones for high availability.

    Internet Gateway & Routing: An Internet Gateway and public route tables to allow internet access to the public subnets.

    Application Load Balancer (ALB): An ALB serves as the single entry point for all traffic, distributing requests across the web servers.

    Auto Scaling Group (ASG): An ASG manages the fleet of EC2 instances, automatically scaling the number of servers up or down based on load and replacing any unhealthy instances.

    Launch Template: A template that defines the configuration for the EC2 instances, including the AMI and a user_data script to bootstrap an Nginx web server.

    Security Groups: A set of firewall rules that secure the environment by only allowing HTTP traffic to the load balancer and then from the load balancer to the web servers.

Architecture Diagram

[ Internet ]
     |
     v
[ Internet Gateway ]
     |
     v
[ Application Load Balancer (ALB) ] -- (In Public Subnets across AZ-A & AZ-B)
     |
     v
[ Auto Scaling Group (ASG) ]
     |
     |--> [ EC2 Instance (Nginx) ] -- (In Public Subnet AZ-A)
     |
     |--> [ EC2 Instance (Nginx) ] -- (In Public Subnet AZ-B)

Core Technologies Used

    Terraform: For defining and managing the infrastructure as code.

    AWS: As the cloud provider for all infrastructure resources (VPC, EC2, S3, ALB, ASG).

    Nginx: As the web server running on the EC2 instances.

Project Structure

This project is organized into a modular structure to promote reusability and separation of concerns:

    main.tf: The root module, which is the entry point for the configuration. It calls the child modules and connects them by passing outputs from one module into the inputs of another.

    variables.tf: Defines the input variables for the root module.

    outputs.tf: Defines the outputs for the root module (e.g., the load balancer's URL).

    modules/: This directory contains the reusable child modules:

        vpc/: Manages all networking resources (VPC, subnets, gateways, route tables).

        security_groups/: Manages the security groups for the ALB and EC2 instances.

        load_balancer/: Manages the Application Load Balancer, its target group, and listener.

        asg/: Manages the Launch Template and the Auto Scaling Group for the web servers.

How to Use
Prerequisites

    An AWS account.

    AWS CLI installed and configured with your credentials.

    Terraform installed (version 1.0.0 or later).

Deployment Steps

    Clone the Repository:

    git clone <your-repo-url>
    cd <your-repo-directory>

    Initialize Terraform:
    Download the necessary provider plugins.

    terraform init

    Plan the Deployment:
    Review the execution plan to see what resources will be created.

    terraform plan

    Apply the Configuration:
    Build the infrastructure. You will be prompted to confirm the action.

    terraform apply

    Once the apply is complete, the public URL of the load balancer will be displayed as an output.

Testing the Infrastructure

    Check the Website: Copy the load_balancer_dns_name output from the terraform apply command and paste it into your web browser. You should see the message "Hello from a Modular Terraform ASG!"

    Test High Availability:

        Navigate to the EC2 console in your AWS account.

        Find the two running instances tagged as "asg-instance".

        Manually terminate one of the instances.

        Observe as the Auto Scaling Group automatically launches a new instance to replace the terminated one. Throughout this process, your website should remain accessible with zero downtime.

Cleanup

To destroy all the resources created by this project and avoid incurring further costs, run the following command:

terraform destroy

