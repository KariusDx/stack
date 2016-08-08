/**
 * The service module creates an ecs service,
 * elb and a route53 record under the local service zone (see the dns module).
 *
 * Usage:
 *
 *      module "my_ecs_service" {
 *        source    = "github.com/segmentio/stack/ecs-service"
 *        name      = "my-service"
 *        cluster   = "default"
 *      }
 *
 */

/**
 * Required Variables.
 */

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs that will be passed to the ELB module"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs that will be passed to the ELB module"
}

variable "port" {
  description = "The container host port"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "dns_name" {
  description = "The DNS name to use, e.g nginx"
}

variable "zone_id" {
  description = "Route53 zone ID to use for dns_name"
}


variable "log_bucket" {
  description = "The S3 bucket ID to use for the ELB"
}

/**
 * Options.
 */

variable "healthcheck" {
  description = "Path to a healthcheck endpoint"
  default     = "/"
}

variable "container_port" {
  description = "The container port"
  default     = 3000
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "protocol" {
  description = "The ELB protocol, HTTP or TCP"
  default     = "HTTP"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "deployment_maximum_percent" {
  description = "The zone ID to create the record in"
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The zone ID to create the record in"
  default = 100
}

variable "task_name" {
  description = "ecs task name"
}

variable "task_arn" {
  description = "ecs task arn"
}

/**
 * Resources.
 */

resource "aws_ecs_service" "main" {
  name            = "${var.task_name}"
  cluster         = "${var.cluster}"
  task_definition = "${var.task_arn}"
  desired_count   = "${var.desired_count}"
  iam_role        = "${var.iam_role}"

  load_balancer {
    elb_name       = "${module.elb.id}"
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
  source = "../../elb/internal"

  name            = "${var.task_name}"
  port            = "${var.port}"
  environment     = "${var.environment}"
  subnet_ids      = "${var.subnet_ids}"
  security_groups = "${var.security_groups}"
  dns_name        = "${coalesce(var.dns_name, var.task_name)}"
  healthcheck     = "${var.healthcheck}"
  protocol        = "${var.protocol}"
  zone_id         = "${var.zone_id}"
  log_bucket      = "${var.log_bucket}"
}

/**
 * Outputs.
 */

// The name of the ELB
output "elb_name" {
  value = "${module.elb.name}"
}

// The DNS name of the ELB
output "elb_dns" {
  value = "${module.elb.dns}"
}

// The id of the ELB
output "elb_id" {
  value = "${module.elb.id}"
}

// The zone id of the ELB
output "elb_zone_id" {
  value = "${module.elb.zone_id}"
}

// FQDN built using the zone domain and name
output "elb_fqdn" {
  value = "${module.elb.fqdn}"
}
