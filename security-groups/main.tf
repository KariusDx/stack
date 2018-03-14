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

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

variable "can_internal_ssh_security_groups" {
  type = "list"
}


resource "aws_security_group" "internal_elb" {
  name        = "${replace(format("%s-%s-internal-elb", var.name, var.environment), "/(.{0,32})(.*)/", "$1")}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows internal ELB traffic"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-%s internal elb", var.name, var.environment)}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_security_group_rule" "internal_elb_http" {
    type = "ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
    security_group_id = "${aws_security_group.internal_elb.id}"
}

resource "aws_security_group_rule" "internal_elb_egress" {
    type = "egress"
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    security_group_id = "${aws_security_group.internal_elb.id}"
}

resource "aws_security_group" "internal_ssh" {
  name        = "${format("%s-%s-internal-ssh", var.name, var.environment)}"
  description = "Allows ssh from bastion to a member of this group"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${var.can_internal_ssh_security_groups}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-%s bastion ssh", var.name, var.environment)}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

// Internal SSH allows ssh connections from the bastion host.
output "internal_ssh" {
  value = "${aws_security_group.internal_ssh.id}"
}

// Internal ELB allows internal traffic.
output "internal_elb" {
  value = "${aws_security_group.internal_elb.id}"
}
