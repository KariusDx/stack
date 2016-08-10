variable "name" {
}

variable "suffix" { default = "" }

variable "environment" {
}

variable "account_id" {
}

variable "stack_name" {
  description = "stack name to use as the value for the Terraform tag"
  default     = ""
}


resource "template_file" "policy" {
  template = "${file("${path.module}/policy.json")}"

  vars = {
    bucket     = "${var.name}-${var.environment}-logs${var.suffix}"
    account_id = "${var.account_id}"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.name}-${var.environment}-logs${var.suffix}"

  tags {
    Name        = "${var.name}-${var.environment}-logs${var.suffix}"
    Environment = "${var.environment}"
    Terraform   = "${var.stack_name}"
  }

  policy = "${template_file.policy.rendered}"
}

output "id" {
  value = "${aws_s3_bucket.logs.id}"
}
