/**
 * Create an ECS cluster
 * Maybe this module shouldn't exist anymore
 * Previously cluster was coupled to creating an autoscaling group
 * But that caused cycles in my terraform.
 */
variable "name" {
  description = "The cluster name, e.g cdn"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-${var.environment}"

  lifecycle {
    create_before_destroy = true
  }
}

// The cluster name, e.g cdn-prod
output "name" {
  value = "${aws_ecs_cluster.main.name}"
}
