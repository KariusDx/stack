/**
 * The stack module combines sub modules to create a complete
 * stack with `vpc`, a default ecs cluster with auto scaling
 * and a bastion node that enables you to access all instances.
 *
 * Usage:
 *
 *    module "stack" {
 *      source      = "github.com/segmentio/stack"
 *      name        = "mystack"
 *      environment = "prod"
 *    }
 *
 */

variable "name" {
  description = "the name of your stack, e.g. \"segment\""
}

variable "log_bucket_suffix" {
  description = "append this to the log bucket nme"
  default = ""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod-west\""
}

variable "key_name" {
  description = "the name of the ssh key to use, e.g. \"internal-key\""
}

variable "domain_name" {
  description = "the internal DNS name to use with services"
  default     = "stack.local"
}

variable "domain_name_servers" {
  description = "the internal DNS servers, defaults to the internal route53 server of the VPC"
  default     = ""
}

variable "region" {
  description = "the AWS region in which resources are created, you must set the availability_zones variable as well if you define this value to something other than the default"
  default     = "us-west-2"
}

variable "cidr" {
  description = "the CIDR block to provision for the VPC, if set to something other than the default, both internal_subnets and external_subnets have to be defined as well"
  default     = "10.30.0.0/16"
}

variable "external_security_group" {
  description = "Use this security group for external VPC access instead of creating a new one."
  default     = ""
}


variable "internal_subnets" {
  description = "a comma-separated list of CIDRs for internal subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = "10.30.0.0/19,10.30.64.0/19,10.30.128.0/19"
}

variable "external_subnets" {
  description = "a comma-separated list of CIDRs for external subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = "10.30.32.0/20,10.30.96.0/20,10.30.160.0/20"
}

variable "availability_zones" {
  description = "a comma-separated list of availability zones, defaults to all AZ of the region, if set to something other than the defaults, both internal_subnets and external_subnets have to be defined as well"
  default     = "us-west-2a,us-west-2b,us-west-2c"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion"
  default = "t2.micro"
}

variable "bastion_private_ip" {
  description = "Private IP address to assign to the bastion host"
  default = ""
}

variable "bastion_ami_id" {
  description = "AMI id to use for the bastion host. Defaults to a standard Ubuntu AMI."
  default = ""
}

variable "bastion_iam_instance_profile" {
  description = "IAM profile the bastion uses"
  default = ""
}

module "defaults" {
  source = "./defaults"
  region = "${var.region}"
  cidr   = "${var.cidr}"
}

module "vpc" {
  source             = "./vpc"
  name               = "${var.name}"
  cidr               = "${var.cidr}"
  internal_subnets   = "${var.internal_subnets}"
  external_subnets   = "${var.external_subnets}"
  availability_zones = "${var.availability_zones}"
  environment        = "${var.environment}"
  stack_name         = "${var.name}"
}

module "security_groups" {
  source      = "./security-groups"
  name        = "${var.name}"
  vpc_id      = "${module.vpc.id}"
  environment = "${var.environment}"
  cidr        = "${var.cidr}"
  stack_name  = "${var.name}"
  can_internal_ssh_security_groups = ["${split(",", module.bastion.can-internal-ssh)}"]
}

module "bastion" {
  source          = "./bastion"
  region          = "${var.region}"
  instance_type   = "${var.bastion_instance_type}"
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${element(split(",",module.vpc.external_subnets), 0)}"
  key_name        = "${var.key_name}"
  environment     = "${var.environment}"
  stack_name      = "${var.name}"
  ami_id          = "${var.bastion_ami_id}"
  external_security_group = "${var.external_security_group}"
  cidr        = "${var.cidr}"
  private_ip      = "${var.bastion_private_ip}"
  iam_instance_profile = "${var.bastion_iam_instance_profile}"
}

module "dhcp" {
  source  = "./dhcp"
  name    = "${module.dns.name}"
  vpc_id  = "${module.vpc.id}"
  servers = "${coalesce(var.domain_name_servers, module.defaults.domain_name_servers)}"
}

module "dns" {
  source = "./dns"
  name   = "${var.domain_name}"
  vpc_id = "${module.vpc.id}"
}

module "s3_logs" {
  source      = "./s3-logs"
  name        = "${var.name}"
  suffix      = "${var.log_bucket_suffix}"
  environment = "${var.environment}"
  account_id  = "${module.defaults.s3_logs_account_id}"
  stack_name  = "${var.name}"
}

// The region in which the infra lives.
output "region" {
  value = "${var.region}"
}

// The bastion host IP.
output "bastion_ip" {
  value = "${module.bastion.external_ip}"
}

// The bastion host IP.
output "bastion_instance_id" {
  value = "${module.bastion.instance_id}"
}

// The bastion internal IP.
output "bastion_internal_ip" {
  value = "${module.bastion.internal_ip}"
}

// The internal route53 zone ID.
output "zone_id" {
  value = "${module.dns.zone_id}"
}

// Security group for internal ELBs.
output "internal_elb" {
  value = "${module.security_groups.internal_elb}"
}

output "can_internal_ssh" {
  value = "${module.bastion.can-internal-ssh}"
}

output "internal_ssh" {
  value = "${module.security_groups.internal_ssh}"
}

// Comma separated list of internal subnet IDs.
output "internal_subnets" {
  value = "${module.vpc.internal_subnets}"
}

// Comma separated list of external subnet IDs.
output "external_subnets" {
  value = "${module.vpc.external_subnets}"
}

// S3 bucket ID for ELB logs.
output "log_bucket_id" {
  value = "${module.s3_logs.id}"
}

// The internal domain name, e.g "stack.local".
output "domain_name" {
  value = "${module.dns.name}"
}

// The environment of the stack, e.g "prod".
output "environment" {
  value = "${var.environment}"
}

// The stack name
output "name" {
  value = "${var.name}"
}

// The VPC availability zones.
output "availability_zones" {
  value = "${module.vpc.availability_zones}"
}

// The VPC security group ID.
output "vpc_security_group" {
  value = "${module.vpc.security_group}"
}

// The VPC ID.
output "vpc_id" {
  value = "${module.vpc.id}"
}

output "vpc_internal_route_table_ids" {
  value = "${module.vpc.internal_route_table_ids}"
}

output "vpc_external_route_table_ids" {
  value = "${module.vpc.external_route_table_ids}"
}

output "external_security_group" {
  value = "${var.external_security_group}"
}

output "ecs_ami" {
  value = "${module.defaults.ecs_ami}"
}
