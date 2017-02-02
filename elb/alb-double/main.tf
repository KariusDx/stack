/**
 * The ELB module creates an ALB, security group
 * a route53 record and a service healthcheck.
 * It is used by the service module.
 */

variable "name" {
  description = "ALB name, e.g cdn"
}

variable "vpc_id" {
    type = "string"
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
  description = "Comma separated list of security group IDs for the internal ALB"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "healthcheck_timeout" {
  default = 5
}

variable "healthcheck_interval" {
  default = 30
}

variable "log_bucket" {
  description = "S3 bucket name to write ALB logs into"
}

variable "external_dns_name" {
  description = "The subdomain under which the ALB is exposed externally, defaults to the task name"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ALB is exposed internally, defaults to the task name"
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

variable "idle_timeout" {
  default = 30
}

/**
 * Resources for External ALB
 */

resource "aws_alb" "external" {
  name = "${var.name}-${var.environment}"

  internal                  = false
  subnets                   = ["${split(",", var.subnet_ids)}"]
  security_groups           = ["${split(",",var.security_groups)}"]

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

resource "aws_alb_target_group" "service" {
  name     = "${var.name}-${var.environment}-external-target"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${vpc_id}"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = "${var.healthcheck_timeout}"
    port                = "${var.port}"
    protocol            = "HTTP"
    path                = "${var.healthcheck}"
    interval            = "${var.healthcheck_interval}"
  }
}

resource "aws_alb_listener" "external" {
  load_balancer_arn = "${aws_alb.external.id}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "${var.ssl_certificate_id}"

  default_action {
    target_group_arn = "${aws_alb_target_group.service.id}"
    type             = "forward"
  }
}

resource "aws_route53_record" "external" {
  zone_id = "${var.external_zone_id}"
  name    = "${var.external_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_alb.external.zone_id}"
    name                   = "${aws_alb.external.dns_name}"
    evaluate_target_health = false
  }
}

/**
 * Resources for Internal ALB
 */

 resource "aws_alb" "internal" {
  name = "${var.name}-${var.environment}-internal"

  internal                  = true
  subnets                   = ["${split(",", var.internal_subnet_ids)}"]
  security_groups           = ["${split(",",var.internal_security_groups)}"]

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-${var.environment}-internal"
    Service     = "${var.name}-internal"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_alb_target_group" "internal-service" {
  name     = "${var.name}-${var.environment}-internal-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${vpc_id}"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = "${var.healthcheck_timeout}"
    port                = "${var.port}"
    protocol            = "HTTP"
    path                = "${var.healthcheck}"
    interval            = "${var.healthcheck_interval}"
  }
}

resource "aws_alb_listener" "internal" {
  load_balancer_arn = "${aws_alb.internal.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.internal-service.id}"
    type             = "forward"
  }
}

resource "aws_route53_record" "internal" {
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_alb.internal.zone_id}"
    name                   = "${aws_alb.internal.dns_name}"
    evaluate_target_health = false
  }
}
/**
 * Outputs.
 */

// The ALB name.
output "external_name" {
  value = "${aws_alb.external.name}"
}

output "internal_name" {
  value = "${aws_alb.internal.name}"
}

// The external ALB ID.
output "external_id" {
  value = "${aws_alb.external.id}"
}

// The external target ID
output "external_target_id" {
    value = "${aws_alb_target_group.service.id}"
}

// The internal ALB ID.
output "internal_id" {
  value = "${aws_alb.internal.id}"
}

// The internal target ID
output "internal_target_id" {
    value = "${aws_alb_target_group.internal-service.id}"
}

// The ALB dns_name.
output "external_dns" {
  value = "${aws_alb.external.dns_name}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${aws_route53_record.external.fqdn}"
}

// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${aws_route53_record.internal.fqdn}"
}

output "internal_dns" {
  value = "${aws_alb.internal.dns_name}"
}

// The zone id of the ALB
output "external_zone_id" {
  value = "${aws_alb.external.zone_id}"
}
