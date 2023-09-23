terraform {
  required_version = ">= 1.5.7, <2.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.15.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}
