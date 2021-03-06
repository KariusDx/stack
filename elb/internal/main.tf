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

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "port" {
  description = "Instance port"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs"
}

variable "dns_name" {
  description = "Route53 record name"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "protocol" {
  description = "Protocol to use, HTTP or TCP"
}

variable "zone_id" {
  description = "Route53 zone ID to use for dns_name"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

variable "idle_timeout" {
  default = 30
}

variable "healthcheck_timeout" {
  default = 5
}

variable "healthcheck_interval" {
  default = 30
}

/**
 * Resources.
 */

resource "aws_elb" "main" {
  name = "${replace("${var.name}-${var.environment}", "/(.{0,32})(.*)/", "$1")}"

  internal                  = true
  cross_zone_load_balancing = true
  subnets                   = ["${split(",", var.subnet_ids)}"]
  security_groups           = ["${split(",",var.security_groups)}"]

  idle_timeout                = "${var.idle_timeout}"
  connection_draining         = true
  connection_draining_timeout = 15

  listener {
    lb_port           = 80
    lb_protocol       = "${var.protocol}"
    instance_port     = "${var.port}"
    instance_protocol = "${var.protocol}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "${var.healthcheck_timeout}"
    target              = "${var.protocol}:${var.port}${var.healthcheck}"
    interval            = "${var.healthcheck_interval}"
  }

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-${var.environment}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.dns_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.main.dns_name}"
    zone_id                = "${aws_elb.main.zone_id}"
    evaluate_target_health = false
  }
}

/**
 * Outputs.
 */

// The ELB name.
output "name" {
  value = "${aws_elb.main.name}"
}

// The ELB ID.
output "id" {
  value = "${aws_elb.main.id}"
}

// The ELB dns_name.
output "dns" {
  value = "${aws_elb.main.dns_name}"
}

// FQDN built using the zone domain and name
output "fqdn" {
  value = "${aws_route53_record.main.fqdn}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${aws_elb.main.zone_id}"
}
