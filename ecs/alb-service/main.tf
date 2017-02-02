variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs used by the external ELB"
}

variable "internal_subnet_ids" {
  description = "Comma separated list of subnet IDs used by the internal ELB"
}

variable "vpc_id" {
    type = "string"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs for the external ELB"
}

variable "internal_security_groups" {
  description = "Comma separated list of security group IDs for the internal ELB"
}

variable "port" {
  description = "The container host port"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "log_bucket" {
  description = "The S3 bucket ID to use for the ELB"
}

variable "ssl_certificate_id" {
  description = "SSL Certificate ID to use"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
  default     = ""
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
  default     = ""
}

variable "external_zone_id" {
  description = "The zone ID to create the record in"
}

variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

/**
 * Options.
 */

variable "healthcheck" {
  description = "Path to a healthcheck endpoint"
  default     = "/"
}

variable "healthcheck_interval" {
  default = 30
}

variable "healthcheck_timeout" {
  default = 5
}

variable "container_port" {
  description = "The container port"
  default     = 3000
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}
variable "deployment_maximum_percent" {
  description = "The maximum capacity increase during deployment"
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The minimum capacity during deployment"
  default = 100
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

variable "task_name" {
  description = "ecs task name"
}

variable "task_definition" {
  description = "ecs task definition"
}

variable "elb_idle_timeout" {
  default = 30
}

resource "aws_ecs_service" "main" {
  name            = "${var.task_name}"
  cluster         = "${var.cluster}"
  task_definition = "${var.task_definition}"
  desired_count   = "${var.desired_count}"
  iam_role        = "${var.iam_role}"

  load_balancer {
    target_group_arn ="${module.elb.external_target_id}"
    container_name = "${var.task_name}"
    container_port = "${var.container_port}"
  }

  lifecycle {
    create_before_destroy = true
  }

  deployment_maximum_percent = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
}


module "elb" {
  source = "../../elb/alb-double"

  name               = "${var.task_name}"
  port               = "${var.port}"
  environment        = "${var.environment}"
  subnet_ids         = "${var.subnet_ids}"
  internal_subnet_ids = "${var.internal_subnet_ids}"
  healthcheck        = "${var.healthcheck}"
  healthcheck_interval = "${var.healthcheck_interval}"
  healthcheck_timeout = "${var.healthcheck_timeout}"
  log_bucket         = "${var.log_bucket}"
  security_groups    = "${var.security_groups}"
  internal_security_groups  = "${var.internal_security_groups}"
  vpc_id             = "${var.vpc_id}"
  external_dns_name  = "${coalesce(var.external_dns_name, var.task_name)}"
  internal_dns_name  = "${coalesce(var.internal_dns_name, var.task_name)}"
  external_zone_id   = "${var.external_zone_id}"
  internal_zone_id   = "${var.internal_zone_id}"
  ssl_certificate_id = "${var.ssl_certificate_id}"
  stack_name         = "${var.stack_name}"
  idle_timeout       = "${var.elb_idle_timeout}"
}

output "elb_external_name" {
  value = "${module.elb.external_name}"
}

output "elb_internal_name" {
  value = "${module.elb.internal_name}"
}

// The DNS name of the ELB
output "elb_external_dns" {
  value = "${module.elb.external_dns}"
}

// The DNS name of the ELB
output "elb_internal_dns" {
  value = "${module.elb.internal_dns}"
}

// The id of the ELB
output "elb_external_id" {
  value = "${module.elb.external_id}"
}

// The id of the ALB target
output "elb_external_target_id" {
  value = "${module.elb.external_target_id}"
}

// The id of the internal ALB target
output "elb_internal_target_id" {
  value = "${module.elb.internal_target_id}"
}

// The zone id of the ELB
output "elb_external_zone_id" {
  value = "${module.elb.external_zone_id}"
}

// FQDN built using the zone domain and name (external)
output "elb_external_fqdn" {
  value = "${module.elb.external_fqdn}"
}

// FQDN built using the zone domain and name (internal)
output "elb_internal_fqdn" {
  value = "${module.elb.internal_fqdn}"
}