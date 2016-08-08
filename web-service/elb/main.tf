/**
 * The ELB module creates an ELB, security group
 * a route53 record and a service healthcheck.
 * It is used by the service module.
 */

variable "name" {
  description = "ELB name, e.g cdn"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
}

variable "internal_subnet_ids" {
  description = "Comma separated list of internal subnet IDs"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "port" {
  description = "Instance port"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs"
}

variable "internal_security_groups" {
  description = "Comma separated list of security group IDs for the internal ELB"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
}

variable "external_zone_id" {
  description = "The zone ID to create the record in"
}

variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

variable "ssl_certificate_id" {
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

/**
 * Resources.
 */

resource "aws_elb" "external" {
  name = "${var.name}"

  internal                  = false
  cross_zone_load_balancing = true
  subnets                   = ["${split(",", var.subnet_ids)}"]
  security_groups           = ["${split(",",var.security_groups)}"]

  idle_timeout                = 30
  connection_draining         = true
  connection_draining_timeout = 15

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = "${var.port}"
    instance_protocol  = "http"
    ssl_certificate_id = "${var.ssl_certificate_id}"
  }

  # The internal ELB will do a health check
  #health_check {
  #  healthy_threshold   = 2
  #  unhealthy_threshold = 2
  #  timeout             = 5
  #  target              = "HTTP:${var.port}${var.healthcheck}"
  #  interval            = 30
  #}

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_route53_record" "external" {
  zone_id = "${var.external_zone_id}"
  name    = "${var.external_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_elb.external.zone_id}"
    name                   = "${aws_elb.external.dns_name}"
    evaluate_target_health = false
  }
}

module "internal_elb" {
  source = "../../elb"

  name               = "${var.name}-internal"
  port               = "${var.port}"
  environment        = "${var.environment}"
  subnet_ids         = "${var.internal_subnet_ids}"
  healthcheck        = "${var.healthcheck}"
  log_bucket         = "${var.log_bucket}"
  security_groups    = "${var.internal_security_groups}"

  dns_name           = "${coalesce(var.internal_dns_name, var.name)}"
  zone_id            = "${var.internal_zone_id}"
  stack_name         = "${var.stack_name}"
}

/**
 * Outputs.
 */

// The ELB name.
output "external_name" {
  value = "${aws_elb.external.name}"
}

// The external ELB ID.
output "external_id" {
  value = "${aws_elb.external.id}"
}

// The internal ELB ID.
output "internal_id" {
  value = "${module.internal_elb.id}"
}

// The ELB dns_name.
output "external_dns" {
  value = "${aws_elb.external.dns_name}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${aws_route53_record.external.fqdn}"
}

// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${module.internal_elb.fqdn}"
}

// The zone id of the ELB
output "external_zone_id" {
  value = "${aws_elb.external.zone_id}"
}
