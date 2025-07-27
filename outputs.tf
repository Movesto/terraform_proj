output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = module.load_balancer.alb_dns_name
}