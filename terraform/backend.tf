terraform {
  backend "s3" {
    bucket         = "yaron-terraform-bucket"
    key            = "complete-workflow/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
