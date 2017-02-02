/**
 * Autoscaling creates an autoscaling group with the following features:
 *
 *  - associated security group
 *  - Instance tags for filtering
 *  - EBS volume for docker resources
 *  - cloudwatch alarms
 *
 *
 * Usage:
 *
 *      module "cluster" {
 *        source               = "github.com/segmentio/stack/ecs-cluster"
 *        environment          = "prod"
 *        name                 = "cluster"
 *        vpc_id               = "vpc-id"
 *        image_id             = "ami-id"
 *        subnet_ids           = "1,2"
 *        key_name             = "ssh-key"
 *        security_groups      = "1,2"
 *        iam_instance_profile = "id"
 *        region               = "us-west-2"
 *        availability_zones   = "a,b"
 *        instance_type        = "t2.small"
 *      }
 *
 */

variable "name" {
  description = "The service name"
}

variable "cluster_name" {
  description = "The cluster name"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "image_id" {
  description = "AMI Image ID"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
}

variable "key_name" {
  description = "SSH key name to use"
}

variable "security_groups" {
  description = "Comma separated list of security groups"
}

variable "iam_instance_profile" {
  description = "Instance profile ARN to use in the launch configuration"
}

variable "region" {
  description = "AWS Region"
}

variable "availability_zones" {
  description = "Comma separated list of AZs"
}

variable "instance_type" {
  description = "The instance type to use, e.g t2.small"
}

variable "instance_ebs_optimized" {
  description = "When set to true the instance will be launched with EBS optimized turned on"
  default     = true
}

variable "min_size" {
  description = "Minimum instance count"
  default     = 3
}

variable "max_size" {
  description = "Maxmimum instance count"
  default     = 100
}

variable "desired_capacity" {
  description = "Desired instance count"
  default     = 3
}

variable "associate_public_ip_address" {
  description = "Should created instances be publicly accessible (if the SG allows)"
  default = false
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  default     = 25
}

variable "docker_volume_size" {
  description = "Attached EBS volume size in GB"
  default     = 25
}

variable "docker_auth_type" {
  description = "The docker auth type, see https://godoc.org/github.com/aws/amazon-ecs-agent/agent/engine/dockerauth for the possible values"
  default     = ""
}

variable "docker_auth_data" {
  description = "A JSON object providing the docker auth data, see https://godoc.org/github.com/aws/amazon-ecs-agent/agent/engine/dockerauth for the supported formats"
  default     = ""
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}

variable "load_balancers" {
  description = "load balancer names to add to the ASG"
  type    = "list"
  default = []
}

variable "target_group_arns" {
  description = "load balancer target group names to add to the ASG"
  type    = "list"
  default = []
}

resource "aws_security_group" "cluster_member" {
  name        = "${var.name}-${var.environment}-ecs-cluster-member"
  vpc_id      = "${var.vpc_id}"
  description = "Tags cluster membership in the ${var.name} ${var.environment} ECS cluster"

  tags {
    Name        = "ECS cluster ${var.name}-${var.environment} membership"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "cluster_access" {
  name        = "${var.name}-${var.environment}-ecs-cluster-access"
  vpc_id      = "${var.vpc_id}"
  description = "Allows traffic from and to the EC2 instances of the ${var.name} ${var.environment} ECS cluster"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = ["${split(",", var.security_groups)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "ECS cluster ${var.name}-${var.environment} access"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "template_file" "cloud_config" {
  template = "${file("${path.module}/files/cloud-config.yml.tpl")}"

  vars {
    environment      = "${var.environment}"
    name             = "${var.name}-${var.environment}"
    region           = "${var.region}"
    docker_auth_type = "${var.docker_auth_type}"
    docker_auth_data = "${var.docker_auth_data}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "main" {
  name_prefix = "${format("%s-%s-", var.name, var.environment)}"

  image_id                    = "${var.image_id}"
  instance_type               = "${var.instance_type}"
  ebs_optimized               = "${var.instance_ebs_optimized}"
  iam_instance_profile        = "${var.iam_instance_profile}"
  key_name                    = "${var.key_name}"
  security_groups             = ["${aws_security_group.cluster_access.id}","${aws_security_group.cluster_member.id}"]
  user_data                   = "${template_file.cloud_config.rendered}"
  associate_public_ip_address = "${var.associate_public_ip_address}"

  # root
  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.root_volume_size}"
  }

  # docker
  ebs_block_device {
    device_name = "/dev/xvdcz"
    volume_type = "gp2"
    volume_size = "${var.docker_volume_size}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name = "${var.name}-${var.environment}"
  load_balancers = ["${var.load_balancers}"]
  target_group_arns    = ["${var.target_group_arns}"]
  availability_zones   = ["${split(",", var.availability_zones)}"]
  vpc_zone_identifier  = ["${split(",", var.subnet_ids)}"]
  launch_configuration = "${aws_launch_configuration.main.id}"
  min_size             = "${var.min_size}"
  max_size             = "${var.max_size}"
  desired_capacity     = "${var.desired_capacity}"
  termination_policies = ["OldestLaunchConfiguration", "Default"]

  tag {
    key                 = "Name"
    value               = "${var.name} ${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.name} ${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.name}-${var.environment}-scaleup"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.name}-${var.environment}-scaledown"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-${var.environment}-cpureservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions {
    ClusterName = "${var.cluster_name}"
  }

  alarm_description = "Scale up if the cpu reservation is above 90% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up.arn}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.name}-${var.environment}-memoryreservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions {
    ClusterName = "${var.cluster_name}"
  }

  alarm_description = "Scale up if the memory reservation is above 90% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up.arn}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.cpu_high"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.name}-${var.environment}-cpureservation-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10"

  dimensions {
    ClusterName = "${var.cluster_name}"
  }

  alarm_description = "Scale down if the cpu reservation is below 10% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down.arn}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.memory_high"]
}

output "autoscaling_group_name" {
  value = "${aws_autoscaling_group.main.name}"
}

// The cluster security group ID.
output "security_group_id" {
  value = "${aws_security_group.cluster_member.id}"
}