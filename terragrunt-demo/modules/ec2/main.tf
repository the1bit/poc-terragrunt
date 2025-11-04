terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "instance_name" {
  description = "EC2 instance name"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "attach_data_disk" {
  description = "Whether to attach a data disk"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "Optional S3 bucket ARN for permissions"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "this" {
  count         = var.instance_count
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  tags          = merge(var.tags, { Name = "${var.instance_name}-${count.index}" })
}

resource "aws_ebs_volume" "data" {
  count             = var.attach_data_disk ? var.instance_count : 0
  availability_zone = aws_instance.this[count.index].availability_zone
  size              = 10
  tags              = merge(var.tags, { Name = "${var.instance_name}-data-${count.index}" })
}

resource "aws_volume_attachment" "data_attach" {
  count       = var.attach_data_disk ? var.instance_count : 0
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.data[count.index].id
  instance_id = aws_instance.this[count.index].id
}

resource "aws_iam_role" "ec2_role" {
  count = var.s3_bucket_arn != "" ? 1 : 0
  name  = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_rw" {
  count = var.s3_bucket_arn != "" ? 1 : 0
  name  = "${var.instance_name}-s3-rw"
  role  = aws_iam_role.ec2_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

output "instance_ids" {
  value = [for i in aws_instance.this : i.id]
}
