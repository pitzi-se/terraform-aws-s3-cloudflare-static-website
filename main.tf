/* ======= Steps ======= */

/* 1. Create bucket for storing static website files */
resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "access_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "acl_ownership" {
  depends_on = [aws_s3_bucket_public_access_block.access_block]
  bucket     = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "acl" {
  depends_on = [aws_s3_bucket_public_access_block.access_block]
  bucket     = aws_s3_bucket.bucket.id
  acl        = "public-read"
}

resource "aws_s3_bucket_policy" "permissions" {
  depends_on = [aws_s3_bucket_public_access_block.access_block]
  bucket     = aws_s3_bucket.bucket.id
  policy     = data.aws_iam_policy_document.permissions.json
}

data "aws_iam_policy_document" "permissions" {
  version = "2012-10-17"
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }
  statement {
    sid    = "OwnerManageBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = toset(var.bucket_owners)
    }
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "bucket_website" {
  depends_on = [aws_s3_bucket_public_access_block.access_block]
  bucket     = aws_s3_bucket.bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

/* 2. Provision ACM certificate to verify domains */
provider "aws" {
  alias  = "useast1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.useast1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

locals {
  aws_acm_cert_validation = tolist(aws_acm_certificate.cert.domain_validation_options)
}

/* 3. Provision ACM validation record via cloudflare */
resource "cloudflare_record" "acm" {
  depends_on = [aws_acm_certificate.cert]

  zone_id = var.cloudflare_zone_id
  name    = local.aws_acm_cert_validation.0.resource_record_name
  value   = local.aws_acm_cert_validation.0.resource_record_value
  type    = local.aws_acm_cert_validation.0.resource_record_type
}

/* 3. ACM Validation after adding DNS record */
resource "aws_acm_certificate_validation" "cert" {
  depends_on      = [aws_acm_certificate.cert, cloudflare_record.acm]
  provider        = aws.useast1
  certificate_arn = aws_acm_certificate.cert.arn
}

/* 4. Provision cloudfront distribution infront of S3 bucket */
resource "aws_cloudfront_distribution" "dist" {
  depends_on = [aws_s3_bucket.bucket, aws_acm_certificate_validation.cert, aws_s3_bucket_website_configuration.bucket_website, aws_s3_bucket_acl.acl]

  origin {
    domain_name = aws_s3_bucket.bucket.bucket_domain_name
    origin_id   = "S3-${var.bucket_name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.index_document

  aliases = [var.domain_name]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = var.tags
}

/* 5. Add CNAME record to Cloudflare DNS which points to the newly created cloudfront distribution */
resource "cloudflare_record" "cname" {
  depends_on = [aws_cloudfront_distribution.dist]

  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  value   = aws_cloudfront_distribution.dist.domain_name
  type    = "CNAME"
}

resource "cloudflare_record" "subdomains" {
  depends_on = [aws_cloudfront_distribution.dist]
  for_each   = toset(var.subdomains)

  zone_id = var.cloudflare_zone_id
  name    = each.value
  value   = var.domain_name
  type    = "CNAME"
}
