variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "my keys"
}

variable "aws_account_id" {
  description = "AWS Account ID to login to ECR"
  type        = string
}
