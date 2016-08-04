/**
 * The service module creates an ecs service, task definition
 * elb and a route53 record under the local service zone (see the dns module).
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

variable "protocol" {
  description = "The ELB protocol, HTTP or TCP"
  default     = "HTTP"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "zone_id" {
  description = "The zone ID to create the record in"
}

variable "deployment_maximum_percent" {
  description = "The zone ID to create the record in"
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The zone ID to create the record in"
  default = 100
}

/**
 * Resources.
 */

module "ecs_service" {
  source = "../ecs/service"
  environment = "${var.environment}"
  name = "${var.name}"
  subnet_ids = "${var.subnet_ids}"
  security_groups = "${var.security_groups}"
  port = "${var.port}"
  cluster = "${var.cluster}"
  dns_name = "${var.dns_name}"
  log_bucket = "${var.log_bucket}"
  healthcheck = "${var.healthcheck}"
  container_port = "${var.container_port}"
  desired_count = "${var.desired_count}"
  protocol = "${var.protocol}"
  iam_role = "${var.iam_role}"
  zone_id = "${var.zone_id}"
  deployment_maximum_percent = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  task_name = "${module.task.name}"
  task_arn  = "${module.task.arn}"
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

  ports = <<EOF
  [
    {
      "containerPort": ${var.container_port},
      "hostPort": ${var.port}
    }
  ]
EOF
}

// The name of the ELB
output "name" {
  value = "${module.ecs_service.elb_name}"
}

// The DNS name of the ELB
output "dns" {
  value = "${module.ecs_service.elb.dns}"
}

// The id of the ELB
output "elb" {
  value = "${module.ecs_service.elb_id}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${module.ecs_service.elb_zone_id}"
}

// FQDN built using the zone domain and name
output "fqdn" {
  value = "${module.ecs_service.elb_fqdn}"
}
