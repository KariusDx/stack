/**
 * Creates basic security groups to be used by instances and ELBs.
 */

variable "name" {
  description = "The name of the security groups serves as a prefix, e.g stack"
}

variable "vpc_id" {
  description = "The VPC ID"
}

variable "environment" {
  description = "The environment, used for tagging, e.g prod"
}

variable "cidr" {
  description = "The cidr block to use for internal security groups"
}

variable "external_security_group" {
  description = "Use this security group for ssh and http external access. Set this or external_ssh_security_group and external_http_security_group"
  default     = ""
}

variable "external_ssh_security_group" {
  description = "Use this security group for external ssh access."
  default     = ""
}

variable "external_http_security_group" {
  description = "Use this security group for external http access."
  default     = ""
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}


resource "aws_security_group" "internal_elb" {
  name        = "${format("%s-%s-internal-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows internal ELB traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s internal elb", var.name)}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_security_group" "internal_ssh" {
  name        = "${format("%s-%s-internal-ssh", var.name, var.environment)}"
  description = "Allows ssh from bastion"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${coalesce(var.external_ssh_security_group, var.external_security_group)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s internal ssh", var.name)}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

// External SSH allows ssh connections on port 22 from the world.
output "external_ssh" {
  value = "${coalesce(var.external_ssh_security_group, var.external_security_group)}"
}

// Internal SSH allows ssh connections from the external ssh security group.
output "internal_ssh" {
  value = "${aws_security_group.internal_ssh.id}"
}

// Internal ELB allows internal traffic.
output "internal_elb" {
  value = "${aws_security_group.internal_elb.id}"
}

// External ELB allows traffic from the world.
output "external_elb" {
  value = "${coalesce(var.external_http_security_group, var.external_security_group)}"
}
