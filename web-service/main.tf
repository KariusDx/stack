/**
 * The web-service is similar to the `service` module, but the
 * it provides a __public__ ELB instead.
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source    = "github.com/segmentio/stack/service"
 *        name      = "auth-service"
 *        image     = "auth-service"
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

variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "version" {
  description = "The docker image version"
  default     = "latest"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs used by the external ELB"
}

variable "internal_subnet_ids" {
  description = "Comma separated list of subnet IDs used by the internal ELB"
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

variable "container_port" {
  description = "The container port"
  default     = 3000
}

variable "command" {
  description = "The raw json of the task command"
  default     = "[]"
}

variable "env_vars" {
  description = "The raw json of the task env vars"
  default     = "[]"
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "memory" {
  description = "The number of MiB of memory to reserve for the container"
  default     = 512
}

variable "cpu" {
  description = "The number of cpu units to reserve for the container"
  default     = 512
}

variable "logDriver" {
  description = "The ECS logDriver"
  default     = "journald"
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


module "ecs_web_service" {
  source = "../ecs/web-service"
  environment = "${var.environment}"
  subnet_ids = "${var.subnet_ids}"
  internal_subnet_ids = "${var.internal_subnet_ids}"
  security_groups = "${var.security_groups}"
  internal_security_groups = "${var.internal_security_groups}"
  port = "${var.port}"
  cluster = "${var.cluster}"
  log_bucket = "${var.log_bucket}"
  ssl_certificate_id = "${var.ssl_certificate_id}"
  iam_role = "${var.iam_role}"
  external_dns_name = "${var.external_dns_name}"
  internal_dns_name = "${var.internal_dns_name}"
  external_zone_id = "${var.external_zone_id}"
  internal_zone_id = "${var.internal_zone_id}"
  healthcheck = "${var.healthcheck}"
  container_port = "${var.container_port}"
  desired_count = "${var.desired_count}"
  deployment_maximum_percent = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  stack_name = "${var.stack_name}"
  task_name = "${module.task.name}"
  task_arn  = "${module.task.arn}"
  security_groups = "${var.security_groups}"
}

module "task" {
  source = "../task"

  name          = "${coalesce(var.name, replace(var.image, "/", "-"))}"
  image         = "${var.image}"
  image_version = "${var.version}"
  command       = "${var.command}"
  env_vars      = "${var.env_vars}"
  memory        = "${var.memory}"
  cpu           = "${var.cpu}"
  logDriver     = "${var.logDriver}"

  ports = <<EOF
  [
    {
      "containerPort": ${var.container_port},
      "hostPort": ${var.port}
    }
  ]
EOF
}

/**
 * Outputs.
 */

// The name of the ELB
output "elb_external_name" {
  value = "${module.ecs_web_service.elb_external_name}"
}

// The DNS name of the ELB
output "external_dns" {
  value = "${module.ecs_web_service.elb_external_dns}"
}

// The id of the ELB
output "elb_external" {
  value = "${module.ecs_web_service.elb_external_id}"
}

// The zone id of the ELB
output "external_zone_id" {
  value = "${module.ecs_web_service.elb_external_zone_id}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${module.ecs_web_service.elb_external_fqdn}"
}

// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${module.ecs_web_service.elb_internal_fqdn}"
}
