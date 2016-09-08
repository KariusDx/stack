/**
 * The bastion host acts as the "jump point" for the rest of the infrastructure.
 * Since most of our instances aren't exposed to the external internet, the bastion acts as the gatekeeper for any direct SSH access.
 * The bastion is provisioned using the key name that you pass to the stack (and hopefully have stored somewhere).
 * If you ever need to access an instance directly, you can do it by "jumping through" the bastion.
 *
 *    $ terraform output # print the bastion ip
 *    $ ssh -i <path/to/key> ubuntu@<bastion-ip> ssh ubuntu@<internal-ip>
 *
 * Usage:
 *
 *    module "bastion" {
 *      source            = "github.com/segmentio/stack/bastion"
 *      region            = "us-west-2"
 *      vpc_id            = "vpc-12"
 *      key_name          = "ssh-key"
 *      subnet_id         = "pub-1"
 *      environment       = "prod"
 *      external_security_group = "sg-1"
 *    }
 *
 */

variable "environment" {
  description = "The environment, used for tagging, e.g prod"
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Instance type, see a list at: https://aws.amazon.com/ec2/instance-types/"
}

variable "region" {
  description = "AWS Region, e.g us-west-2"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "key_name" {
  description = "The SSH key pair, key name"
}

variable "subnet_id" {
  description = "A external subnet id"
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag and in the security group name"
  default     = ""
}

variable "ami_id" {
  description = "ami id to use for the bastion host"
}

variable "external_security_group" {
  description = "Use this security group for external ssh access."
}

variable "cidr" {
  description = "The cidr block to use for internal security groups"
}

/*
module "ami" {
  source        = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  region        = "${var.region}"
  distribution  = "trusty"
  instance_type = "${var.instance_type}"
}
*/

resource "aws_security_group" "can-internal-ssh" {
  name        = "${format("%s-%s-can-internal-ssh", var.stack_name, var.environment)}"
  description = "Membership allows for ssh to other machines"
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s %s can internal ssh", var.stack_name, var.environment)}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_instance" "bastion" {
  ami                    = "${var.ami_id}"
  source_dest_check      = false
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${var.external_security_group}","${aws_security_group.can-internal-ssh.id}"]
  monitoring             = true
  user_data              = "${file(format("%s/user_data.sh", path.module))}"

  tags {
    Name        = "bastion ${var.environment}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }
}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
}

// Bastion external IP address.
output "external_ip" {
  value = "${aws_eip.bastion.public_ip}"
}

output "internal_ip" {
  value = "${aws_eip.bastion.private_ip}"
}

output "instance_id" {
  value = "${aws_instance.bastion.id}"
}

output "can-internal-ssh" {
  value = "${aws_security_group.can-internal-ssh.id}"
}
