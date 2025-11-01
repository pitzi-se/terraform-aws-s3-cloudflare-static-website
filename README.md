# Static Website (S3, CloudFront & Cloudflare)
This terraform module provisions the appropriate AWS & CloudFlare resources allowing you to deploy a secure static website using S3 (static file storage), CloudFront (CDN) & CloudFlare (DNS Management).

This module implements security best practices including:
- Private S3 bucket with CloudFront Origin Access Control (OAC)
- HTTPS-only access with modern TLS 1.2+
- Restricted HTTP methods (GET/HEAD/OPTIONS only)
- Custom error page handling

This module should be used in conjunction with your preferred continuous integration service (CircleCI, GitHub Actions etc). You can use this module to provision the required resources and should rely on your CI process to build and sync to S3.

## What it does
**Step 1**: Create a private S3 bucket used to store static website files.

**Step 2**: Provision an ACM certificate to verify your domain.

**Step 3**: Provision ACM validation record via Cloudflare. This is so that ACM can validate you own the domain you specified.

**Step 4**: Test ACM Validation after adding DNS validation record.

**Step 5**: Create CloudFront Origin Access Control (OAC) for secure S3 access.

**Step 6**: Provision CloudFront distribution to serve your files out of the S3 bucket with HTTPS enforcement and security headers.

**Step 7**: Add CNAME record to Cloudflare DNS which points to the newly created CloudFront distribution.

## Example Usage
```terraform
terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.12"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Or your preferred region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token  # Use variables for secrets
}

module "static-web-hosting" {
  source = "github.com/pitzi-se/terraform-aws-s3-cloudflare-static-website?ref=v1.0.0"

  region             = "us-east-1"
  bucket_name        = "example-website-bucket"
  index_document     = "index.html"
  error_document     = "error.html"
  domain_name        = "example.com"
  cloudflare_zone_id = var.cloudflare_zone_id
  subdomains         = ["www"]
  bucket_owners      = ["arn:aws:iam::123456789012:role/my-ci-role"]
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}
```

## Arguments
| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| **bucket_name** | `string` | Yes | This corresponds to a unique bucket name in which you want to store your site contents. It is normally convention to use the domain name as the bucket name (eg. example.com). |
| **domain_name** | `string` | Yes | This is the domain name you want to use to point your website. (eg. example.com, www.example.com etc) |
| **cloudflare_zone_id** | `string` | Yes | The DNS zone ID in which to add the record. You can get this from the domain view in the cloudflare dashboard. |
| **region** | `string` | Yes | The AWS region to create the S3 bucket in. |
| **bucket_owners** | `list(string)` | Yes | The ARNs of the principals that should be bucket owners (e.g., CI/CD roles or IAM users). |
| **index_document** | `string` | No | This corresponds to the default index document. (Defaults to index.html) |
| **error_document** | `string` | No | This corresponds to the default error document. (Defaults to error.html) |
| **subdomains** | `list(string)` | No | A list of subdomains to point to the same S3 website (e.g., ["www"]). |
| **tags** | `map(string)` | No | Tags you would like to apply across AWS resources. |



## Example Plan
```zsh
$ terraform plan    
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_acm_certificate.cert will be created
  + resource "aws_acm_certificate" "cert" {
      + arn                       = (known after apply)
      + domain_name               = "example.xyz"
      + domain_validation_options = (known after apply)
      + id                        = (known after apply)
      + subject_alternative_names = (known after apply)
      + validation_emails         = (known after apply)
      + validation_method         = "DNS"
    }

  # aws_acm_certificate_validation.cert will be created
  + resource "aws_acm_certificate_validation" "cert" {
      + certificate_arn = (known after apply)
      + id              = (known after apply)
    }

  # aws_cloudfront_distribution.dist will be created
  + resource "aws_cloudfront_distribution" "dist" {
      + active_trusted_signers         = (known after apply)
      + aliases                        = [
          + "example.xyz",
        ]
      + arn                            = (known after apply)
      + caller_reference               = (known after apply)
      + default_root_object            = "index.html"
      + domain_name                    = (known after apply)
      + enabled                        = true
      + etag                           = (known after apply)
      + hosted_zone_id                 = (known after apply)
      + http_version                   = "http2"
      + id                             = (known after apply)
      + in_progress_validation_batches = (known after apply)
      + is_ipv6_enabled                = true
      + last_modified_time             = (known after apply)
      + price_class                    = "PriceClass_All"
      + retain_on_delete               = false
      + status                         = (known after apply)
      + wait_for_deployment            = true

      + default_cache_behavior {
          + allowed_methods        = [
              + "DELETE",
              + "GET",
              + "HEAD",
              + "OPTIONS",
              + "PATCH",
              + "POST",
              + "PUT",
            ]
          + cached_methods         = [
              + "GET",
              + "HEAD",
            ]
          + compress               = false
          + default_ttl            = 3600
          + max_ttl                = 86400
          + min_ttl                = 0
          + target_origin_id       = "S3-example-website-bucket"
          + viewer_protocol_policy = "allow-all"

          + forwarded_values {
              + query_string = false

              + cookies {
                  + forward = "none"
                }
            }
        }

      + origin {
          + domain_name = (known after apply)
          + origin_id   = "S3-example-website-bucket"
        }

      + restrictions {
          + geo_restriction {
              + restriction_type = "none"
            }
        }

      + viewer_certificate {
          + acm_certificate_arn      = (known after apply)
          + minimum_protocol_version = "TLSv1"
          + ssl_support_method       = "sni-only"
        }
    }

  # aws_s3_bucket.bucket will be created
  + resource "aws_s3_bucket" "bucket" {
      + acceleration_status         = (known after apply)
      + acl                         = "public-read"
      + arn                         = (known after apply)
      + bucket                      = "example-website-bucket"
      + bucket_domain_name          = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = false
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + policy                      = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "s3:GetObject"
                      + Effect    = "Allow"
                      + Principal = "*"
                      + Resource  = "arn:aws:s3:::example-website-bucket/*"
                      + Sid       = "PublicReadGetObject"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + versioning {
          + enabled    = (known after apply)
          + mfa_delete = (known after apply)
        }

      + website {
          + error_document = "error.html"
          + index_document = "index.html"
        }
    }

  # cloudflare_record.acm will be created
  + resource "cloudflare_record" "acm" {
      + created_on  = (known after apply)
      + hostname    = (known after apply)
      + id          = (known after apply)
      + metadata    = (known after apply)
      + modified_on = (known after apply)
      + name        = (known after apply)
      + proxiable   = (known after apply)
      + proxied     = false
      + ttl         = (known after apply)
      + type        = (known after apply)
      + value       = (known after apply)
      + zone_id     = "4ab79b65343sdf44dca2943d2345d9dbf0d"
    }

  # cloudflare_record.cname will be created
  + resource "cloudflare_record" "cname" {
      + created_on  = (known after apply)
      + hostname    = (known after apply)
      + id          = (known after apply)
      + metadata    = (known after apply)
      + modified_on = (known after apply)
      + name        = "example.xyz"
      + proxiable   = (known after apply)
      + proxied     = false
      + ttl         = (known after apply)
      + type        = "CNAME"
      + value       = (known after apply)
      + zone_id     = "4ab79b65343sdf44dca2943d2345d9dbf0d"
    }

Plan: 6 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```
